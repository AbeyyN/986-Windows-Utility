# 986 WinUtil Bootstrap Endpoint

Cloudflare Pages Advanced Mode endpoint for the short bootstrap command:

```powershell
irm https://986-winutil.abeyytechxy.com | iex
```

The Pages project is `986-winutil-bootstrap`. Its `_worker.js` fetches the current `bootstrap.ps1` from repository `main` and returns it as plain text.

## Safety properties

- Exact custom domain: `986-winutil.abeyytechxy.com`
- Cloudflare Pages project: `986-winutil-bootstrap`
- Advanced Mode entry point: `pages/_worker.js`
- Only `GET /` and `HEAD /` are accepted.
- Non-root paths return `404`.
- Other methods return `405`.
- Upstream failures return `502` rather than forwarding an HTML error response.
- Response is `text/plain; charset=utf-8` with `X-Content-Type-Options: nosniff`.
- `Cache-Control: no-store` keeps the endpoint aligned with the latest `main/bootstrap.ps1`.
- The public bootstrap itself installs the latest stable non-prerelease GitHub Release and verifies its SHA-256 checksum before launch.

## Upstream

`https://raw.githubusercontent.com/AbeyyN/986-Windows-Utility/main/bootstrap.ps1`

## Deployment

The Pages deploy token only needs Cloudflare Pages write access. The custom domain is attached through the Cloudflare Pages project-domain API.
