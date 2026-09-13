# 986 WinUtil Bootstrap Endpoint

Cloudflare Worker for the short bootstrap command:

```powershell
irm https://986-winutil.abeyytechxy.com | iex
```

The Worker serves the current `bootstrap.ps1` from the repository `main` branch as plain text.

## Safety properties

- Exact custom domain: `986-winutil.abeyytechxy.com`
- Only `GET /` and `HEAD /` are accepted.
- Non-root paths return `404`.
- Other methods return `405`.
- Upstream failures return `502` rather than forwarding an HTML error response.
- Response is `text/plain; charset=utf-8` with `X-Content-Type-Options: nosniff`.
- `Cache-Control: no-store` keeps the endpoint aligned with the latest `main/bootstrap.ps1`.
- `workers_dev` is disabled; the production custom domain is the intended entry point.

## Upstream

`https://raw.githubusercontent.com/AbeyyN/986-Windows-Utility/main/bootstrap.ps1`
