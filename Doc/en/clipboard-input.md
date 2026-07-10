# Clipboard and Input

The project tries to make browser-based desktop use feel close to a local
desktop, especially for text copy/paste with WeChat and QQ.

## Layers

- Browser clipboard permissions let the web page read and write clipboard
  content when the browser allows it.
- Selkies clipboard settings move clipboard content between the browser client
  and the remote desktop session.
- The Wayland/Xwayland text clipboard bridge keeps native Wayland apps and
  Xwayland apps such as WeChat/QQ in sync.

## Expected Workflow

- Copy text on Windows/macOS/Linux, paste into KDE, WeChat, or QQ in the
  browser desktop.
- Copy text in KDE, WeChat, or QQ, paste back into the local browser-side
  operating system.
- Use the same remote app state and input method setup from multiple client
  machines.

## Limits

Binary clipboard and images depend on Selkies and browser support. Text is the
primary supported path. If clipboard behavior fails, first check browser site
permissions and the Selkies clipboard panel.

Input methods are configured inside the persistent KDE desktop. That means you
can tune IME settings once in the remote desktop instead of rebuilding them on
every client machine.
