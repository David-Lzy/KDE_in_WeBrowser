ARG WECHAT_QQ_SOURCE_IMAGE=ghcr.io/nickrunning/wechat-selkies:latest
FROM ${WECHAT_QQ_SOURCE_IMAGE} AS wechat_qq_source

FROM lscr.io/linuxserver/webtop:ubuntu-kde

ARG TARGETPLATFORM
ARG INSTALL_WECHAT=true
ARG INSTALL_QQ=true
ARG INSTALL_PCMANFM=true

LABEL org.opencontainers.image.title="KDE Webtop WeChat/QQ Module"
LABEL org.opencontainers.image.description="Optional WeChat and QQ layer for KDE in Web Browser"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      desktop-file-utils \
      fonts-noto-cjk \
      inotify-tools \
      libatk-bridge2.0-0 \
      libatk1.0-0 \
      libatomic1 \
      libcairo2 \
      libcups2 \
      libdbus-1-3 \
      libfontconfig1 \
      libgbm1 \
      libgdk-pixbuf-2.0-0 \
      libgdk-pixbuf-xlib-2.0-0 \
      libglib2.0-0 \
      libgtk-3-0 \
      libnspr4 \
      libnss3 \
      libpango-1.0-0 \
      libpangocairo-1.0-0 \
      libx11-6 \
      libx11-xcb1 \
      libxcb-glx0 \
      libxcb-icccm4 \
      libxcb-image0 \
      libxcb-keysyms1 \
      libxcb-randr0 \
      libxcb-render-util0 \
      libxcb-render0 \
      libxcb-shape0 \
      libxcb-shm0 \
      libxcb-sync1 \
      libxcb-util1 \
      libxcb-xfixes0 \
      libxcb-xinerama0 \
      libxcb-xkb1 \
      libxcb1 \
      libxcomposite1 \
      libxdamage1 \
      libxext6 \
      libxfixes3 \
      libxi6 \
      libxkbcommon-x11-0 \
      libxrandr2 \
      libxrender1 \
      libxss1 \
      libxtst6 \
      python3-xlib \
      shared-mime-info \
      stalonetray \
      xdg-utils && \
    if [ "${INSTALL_PCMANFM}" = "true" ]; then \
      apt-get install -y --no-install-recommends pcmanfm; \
    fi && \
    rm -rf /var/lib/apt/lists/*

COPY --from=wechat_qq_source /opt/wechat /opt/wechat
COPY --from=wechat_qq_source /opt/QQ /opt/QQ
COPY --from=wechat_qq_source /usr/share/applications/wechat.desktop /usr/share/applications/wechat.desktop
COPY --from=wechat_qq_source /usr/share/applications/qq.desktop /usr/share/applications/qq.desktop
COPY --from=wechat_qq_source /usr/share/icons/hicolor/256x256/apps/wechat.png /usr/share/icons/hicolor/256x256/apps/wechat.png
COPY --from=wechat_qq_source /usr/share/icons/hicolor/512x512/apps/qq.png /usr/share/icons/hicolor/512x512/apps/qq.png

RUN ln -sf /opt/wechat/wechat /usr/bin/wechat && \
    ln -sf /opt/QQ/qq /usr/bin/qq && \
    if [ "${INSTALL_WECHAT}" != "true" ]; then \
      rm -rf /opt/wechat /usr/bin/wechat /usr/share/applications/wechat.desktop; \
    fi && \
    if [ "${INSTALL_QQ}" != "true" ]; then \
      rm -rf /opt/QQ /usr/bin/qq /usr/share/applications/qq.desktop; \
    fi

COPY modules/wechat-qq/root/ /

RUN chmod 755 /scripts /scripts/wechat /scripts/qq \
      /scripts/start.sh /scripts/refresh-menu.sh /scripts/window_switcher.py \
      /scripts/wechat/*.sh /scripts/qq/*.sh && \
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true && \
    update-desktop-database /usr/share/applications || true && \
    ldd /opt/wechat/wechat 2>/dev/null | grep -q "not found" && exit 1 || true && \
    ldd /opt/QQ/qq 2>/dev/null | grep -q "not found" && exit 1 || true && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /config/.cache
