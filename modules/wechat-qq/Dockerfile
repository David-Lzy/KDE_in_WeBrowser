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

RUN if [ "${INSTALL_WECHAT}" = "true" ]; then \
      case "${TARGETPLATFORM}" in \
        "linux/amd64") WECHAT_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb" ;; \
        "linux/arm64") WECHAT_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb" ;; \
        *) echo "Unsupported platform for WeChat: ${TARGETPLATFORM}" >&2; exit 1 ;; \
      esac && \
      curl -fsSL --retry 3 --retry-delay 10 --retry-all-errors -o /tmp/wechat.deb "${WECHAT_URL}" && \
      (dpkg -i /tmp/wechat.deb || (apt-get update && apt-get install -f -y && dpkg -i /tmp/wechat.deb)) && \
      rm -f /tmp/wechat.deb && \
      rm -rf /var/lib/apt/lists/*; \
    fi

RUN if [ "${INSTALL_QQ}" = "true" ]; then \
      case "${TARGETPLATFORM}" in \
        "linux/amd64") QQ_URL="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.27_260401_amd64_01.deb" ;; \
        "linux/arm64") QQ_URL="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.27_260401_arm64_01.deb" ;; \
        *) echo "Unsupported platform for QQ: ${TARGETPLATFORM}" >&2; exit 1 ;; \
      esac && \
      curl -fsSL --retry 3 --retry-delay 10 --retry-all-errors -o /tmp/qq.deb "${QQ_URL}" && \
      (dpkg -i /tmp/qq.deb || (apt-get update && apt-get install -f -y && dpkg -i /tmp/qq.deb)) && \
      rm -f /tmp/qq.deb && \
      rm -rf /var/lib/apt/lists/*; \
    fi

COPY modules/wechat-qq/root/ /

RUN chmod 755 /scripts/start.sh /scripts/refresh-menu.sh /scripts/window_switcher.py \
      /scripts/wechat/*.sh /scripts/qq/*.sh && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /config/.cache
