import crypto from "node:crypto";
import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

import express from "express";
import { betterAuth } from "better-auth";
import { toNodeHandler } from "better-auth/node";
import { z } from "zod";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const requiredEnv = (name) => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
};

const appName = "KDE in Web Browser";
const port = Number(process.env.GATEWAY_APP_PORT || 3000);
const hostUser = requiredEnv("HOST_USER");
const cookieSecret = requiredEnv("GATEWAY_COOKIE_SECRET");
const betterAuthSecret = process.env.BETTER_AUTH_SECRET || cookieSecret;
const publicBaseURL = process.env.GATEWAY_PUBLIC_BASE_URL || `https://127.0.0.1:${process.env.GATEWAY_PORT || 18080}`;
const pamSocket = process.env.PAM_HELPER_SOCKET || "/run/kde-webtop-pam/helper.sock";
const sessionCookieName = process.env.GATEWAY_SESSION_COOKIE || "kde_webtop_session";
const sessionMaxAgeSeconds = Number(process.env.GATEWAY_SESSION_MAX_AGE_SECONDS || 28800);
const cooldownWindowSeconds = Number(process.env.GATEWAY_COOLDOWN_WINDOW_SECONDS || 300);
const cooldownMaxFailures = Number(process.env.GATEWAY_COOLDOWN_MAX_FAILURES || 5);
const cooldownLockSeconds = Number(process.env.GATEWAY_COOLDOWN_LOCK_SECONDS || 300);

const loginSchema = z.object({
  username: z.string().min(1).max(128),
  password: z.string().min(1).max(4096),
  next: z.string().optional().default("/"),
});

const failureBuckets = new Map();

const auth = betterAuth({
  appName,
  secret: betterAuthSecret,
  baseURL: `${publicBaseURL}/api/auth`,
  trustedOrigins: [publicBaseURL],
  emailAndPassword: {
    enabled: false,
  },
  advanced: {
    cookiePrefix: "kde-webtop",
    ipAddress: {
      ipAddressHeaders: ["x-forwarded-for", "x-real-ip"],
      trustedProxies: ["127.0.0.1", "::1"],
    },
  },
});

const app = express();
const distDir = path.join(__dirname, "..", "dist");

app.all("/api/auth/*splat", toNodeHandler(auth));

app.use(express.urlencoded({ extended: false }));
app.use(express.json());
app.use("/auth-static", express.static(distDir, { index: false }));

app.get("/healthz", (_req, res) => {
  res.json({ ok: true });
});

app.get("/auth/login", (req, res) => {
  const builtLogin = path.join(distDir, "login.html");
  if (fs.existsSync(builtLogin)) {
    return res.sendFile(builtLogin);
  }
  return res.sendFile(path.join(__dirname, "..", "public", "login.html"));
});

app.get("/auth/config.js", (_req, res) => {
  res.type("application/javascript");
  res.send(`window.__KDE_WEBTOP_AUTH__ = ${JSON.stringify({ hostUser })};`);
});

app.post("/auth/login", async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ ok: false, error: "invalid_request" });
  }

  const { username, password, next } = parsed.data;
  if (username !== hostUser) {
    recordFailure(req.ip);
    return res.status(401).json({ ok: false, error: "invalid_credentials" });
  }

  const cooldown = currentCooldown(req.ip);
  if (cooldown.locked) {
    return res.status(429).json({
      ok: false,
      error: "cooldown",
      retryAfterSeconds: cooldown.retryAfterSeconds,
    });
  }

  const pamResult = await verifyPam(username, password);
  if (!pamResult.ok) {
    recordFailure(req.ip);
    return res.status(pamResult.unavailable ? 503 : 401).json({
      ok: false,
      error: pamResult.unavailable ? "pam_unavailable" : "invalid_credentials",
    });
  }

  clearFailures(req.ip);
  setSessionCookie(res, username);
  return res.json({ ok: true, next: safeNext(next) });
});

app.post("/auth/logout", (req, res) => {
  clearSessionCookie(res);
  res.json({ ok: true });
});

app.get("/auth/me", (req, res) => {
  const session = readSession(req);
  if (!session) {
    return res.status(401).json({ ok: false });
  }
  return res.json({ ok: true, user: session.user, expiresAt: session.expiresAt });
});

app.get("/api/authz", (req, res) => {
  const session = readSession(req);
  if (!session) {
    res.setHeader("X-Auth-Reason", "missing-session");
    return res.sendStatus(401);
  }
  res.setHeader("X-Authenticated-User", session.user);
  return res.sendStatus(204);
});

app.listen(port, () => {
  console.log(`gateway app listening on ${port}`);
});

function safeNext(next) {
  if (!next || !next.startsWith("/") || next.startsWith("//")) {
    return "/";
  }
  return next;
}

function currentCooldown(ip) {
  const now = Date.now();
  const bucket = failureBuckets.get(ip);
  if (!bucket) {
    return { locked: false, retryAfterSeconds: 0 };
  }
  if (bucket.lockedUntil && bucket.lockedUntil > now) {
    return {
      locked: true,
      retryAfterSeconds: Math.ceil((bucket.lockedUntil - now) / 1000),
    };
  }
  if (bucket.windowStart + cooldownWindowSeconds * 1000 < now) {
    failureBuckets.delete(ip);
  }
  return { locked: false, retryAfterSeconds: 0 };
}

function recordFailure(ip) {
  const now = Date.now();
  const bucket = failureBuckets.get(ip);
  if (!bucket || bucket.windowStart + cooldownWindowSeconds * 1000 < now) {
    failureBuckets.set(ip, { windowStart: now, count: 1, lockedUntil: 0 });
    return;
  }
  bucket.count += 1;
  if (bucket.count >= cooldownMaxFailures) {
    bucket.lockedUntil = now + cooldownLockSeconds * 1000;
  }
}

function clearFailures(ip) {
  failureBuckets.delete(ip);
}

async function verifyPam(username, password) {
  if (!fs.existsSync(pamSocket)) {
    return { ok: false, unavailable: true };
  }

  const payload = `${JSON.stringify({ username, password })}\n`;

  return new Promise((resolve) => {
    const client = net.createConnection(pamSocket);
    let response = "";
    const timer = setTimeout(() => {
      client.destroy();
      resolve({ ok: false, unavailable: true });
    }, 10000);

    client.on("connect", () => {
      client.end(payload);
    });
    client.on("data", (chunk) => {
      response += chunk.toString("utf8");
    });
    client.on("error", () => {
      clearTimeout(timer);
      resolve({ ok: false, unavailable: true });
    });
    client.on("close", () => {
      clearTimeout(timer);
      try {
        const parsed = JSON.parse(response);
        resolve({ ok: parsed.ok === true, unavailable: parsed.unavailable === true });
      } catch {
        resolve({ ok: false, unavailable: true });
      }
    });
  });
}

function setSessionCookie(res, user) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    user,
    iat: now,
    exp: now + sessionMaxAgeSeconds,
    nonce: crypto.randomBytes(16).toString("hex"),
  };
  const encoded = Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
  const sig = sign(encoded);
  res.cookie(sessionCookieName, `${encoded}.${sig}`, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.GATEWAY_SECURE_COOKIES !== "false",
    maxAge: sessionMaxAgeSeconds * 1000,
    path: "/",
  });
}

function clearSessionCookie(res) {
  res.clearCookie(sessionCookieName, { path: "/" });
}

function readSession(req) {
  const rawCookie = req.headers.cookie || "";
  const cookies = Object.fromEntries(
    rawCookie
      .split(";")
      .map((item) => item.trim())
      .filter(Boolean)
      .map((item) => {
        const index = item.indexOf("=");
        return [item.slice(0, index), decodeURIComponent(item.slice(index + 1))];
      })
  );
  const value = cookies[sessionCookieName];
  if (!value) {
    return null;
  }
  const [encoded, sig] = value.split(".");
  if (!encoded || !sig || !timingSafeEqual(sig, sign(encoded))) {
    return null;
  }
  try {
    const payload = JSON.parse(Buffer.from(encoded, "base64url").toString("utf8"));
    if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) {
      return null;
    }
    if (payload.user !== hostUser) {
      return null;
    }
    return { user: payload.user, expiresAt: payload.exp };
  } catch {
    return null;
  }
}

function sign(value) {
  return crypto.createHmac("sha256", cookieSecret).update(value).digest("base64url");
}

function timingSafeEqual(a, b) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  if (left.length !== right.length) {
    return false;
  }
  return crypto.timingSafeEqual(left, right);
}
