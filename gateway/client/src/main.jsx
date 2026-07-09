import React, { useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  Alert,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
  Input,
  Spinner,
} from "@heroui/react";
import "@better-auth-ui/heroui/styles";
import "./styles.css";

const errorLabels = {
  invalid_request: "Invalid login request.",
  invalid_credentials: "Username or password is incorrect.",
  pam_unavailable: "Host authentication is temporarily unavailable.",
  cooldown: "Too many failed attempts. Please wait before trying again.",
};

function App() {
  const params = useMemo(() => new URLSearchParams(window.location.search), []);
  const next = params.get("next") || "/";
  const defaultUser = window.__KDE_WEBTOP_AUTH__?.hostUser || "";
  const [username, setUsername] = useState(defaultUser);
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setPending(true);
    setError("");

    try {
      const response = await fetch("/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password, next }),
      });
      const body = await response.json().catch(() => ({}));

      if (!response.ok) {
        const label = errorLabels[body.error] || "Login failed.";
        const retry = body.retryAfterSeconds ? ` Retry after ${body.retryAfterSeconds}s.` : "";
        setError(`${label}${retry}`);
        setPassword("");
        return;
      }

      window.location.assign(body.next || "/");
    } catch {
      setError("Gateway is unreachable.");
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="auth-shell">
      <section className="auth-copy" aria-hidden="true">
        <div className="auth-mark">KDE</div>
        <h1>KDE in Web Browser</h1>
        <p>Host PAM authentication in front of a personal KDE Wayland desktop.</p>
      </section>

      <Card className="auth-card">
        <CardHeader>
          <CardTitle>Sign in</CardTitle>
          <CardDescription>Use your host Linux account.</CardDescription>
        </CardHeader>

        <CardContent>
          <form className="auth-form" onSubmit={handleSubmit}>
            <Input
              autoComplete="username"
              autoFocus
              isDisabled={pending}
              isRequired
              label="Host user"
              name="username"
              onChange={(event) => setUsername(event.target.value)}
              onValueChange={setUsername}
              placeholder="davidli"
              value={username}
            />

            <Input
              autoComplete="current-password"
              isDisabled={pending}
              isRequired
              label="Host password"
              name="password"
              onChange={(event) => setPassword(event.target.value)}
              onValueChange={setPassword}
              type="password"
              value={password}
            />

            {error ? (
              <Alert color="danger" title={error} />
            ) : null}

            <Button color="primary" isDisabled={pending} type="submit">
              {pending ? <Spinner color="current" size="sm" /> : null}
              Sign in
            </Button>
          </form>
        </CardContent>

        <CardFooter>
          <span className="auth-footnote">
            Powered by Better Auth boundary, HeroUI, and a host-side PAM helper.
          </span>
        </CardFooter>
      </Card>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);
