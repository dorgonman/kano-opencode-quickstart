# Learnings - Portability & Cross-Browser Behavior

- OpenCode sessions are scoped by the `directory` field, which explains why they "disappear" when switching workspaces or sandboxes.
- Browser `localStorage` is strictly origin-scoped, making cross-domain sync (e.g., localhost vs Tailscale) a manual process.
- The OpenCode SPA router redirects unknown paths, preventing static HTML tools from being served directly on the same port without modification to the server.
- Server-side storage includes `project`, `session`, `message`, `part`, and `migration` directories.
