const UPSTREAM = 'https://raw.githubusercontent.com/AbeyyN/986-Windows-Utility/main/bootstrap.ps1';

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname !== '/') {
      return new Response('Not Found\n', {
        status: 404,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-store',
          'X-Content-Type-Options': 'nosniff',
        },
      });
    }

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed\n', {
        status: 405,
        headers: {
          'Allow': 'GET, HEAD',
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-store',
          'X-Content-Type-Options': 'nosniff',
        },
      });
    }

    const upstream = await fetch(UPSTREAM, {
      headers: {
        'Accept': 'text/plain',
        'User-Agent': '986-Windows-Utility-Bootstrap/1.0',
      },
      redirect: 'follow',
      cf: {
        cacheTtl: 0,
        cacheEverything: false,
      },
    });

    if (!upstream.ok) {
      return new Response(`Bootstrap upstream unavailable (${upstream.status})\n`, {
        status: 502,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-store',
          'X-Content-Type-Options': 'nosniff',
        },
      });
    }

    const script = await upstream.text();
    if (!script.includes('986 Windows Utility') && !script.includes('986-Windows-Utility')) {
      return new Response('Bootstrap upstream validation failed\n', {
        status: 502,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-store',
          'X-Content-Type-Options': 'nosniff',
        },
      });
    }

    const headers = {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'no-store, max-age=0',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
      'X-986-Source': 'github-main-bootstrap',
    };

    return new Response(request.method === 'HEAD' ? null : script, {
      status: 200,
      headers,
    });
  },
};
