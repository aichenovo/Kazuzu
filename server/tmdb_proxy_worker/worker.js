const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET,OPTIONS',
  'access-control-allow-headers': 'content-type',
  'access-control-max-age': '86400',
};

const allowedExactPaths = new Set([
  '/3/search/multi',
  '/3/trending/tv/week',
  '/3/discover/tv',
]);

const allowedPatterns = [
  /^\/3\/(tv|movie)\/\d+$/u,
  /^\/3\/(tv|movie)\/\d+\/reviews$/u,
  /^\/3\/(tv|movie)\/\d+\/credits$/u,
  /^\/3\/person\/\d+$/u,
];

function isAllowedPath(pathname) {
  if (allowedExactPaths.has(pathname)) return true;
  return allowedPatterns.some((re) => re.test(pathname));
}

function ttlSecondsForPath(pathname) {
  if (pathname === '/3/search/multi') return 1800;
  if (pathname.startsWith('/3/trending/')) return 1800;
  if (pathname.startsWith('/3/discover/')) return 1800;
  if (/^\/3\/(tv|movie)\/\d+$/u.test(pathname)) return 21600;
  if (/^\/3\/person\/\d+$/u.test(pathname)) return 21600;
  if (/^\/3\/(tv|movie)\/\d+\/credits$/u.test(pathname)) return 21600;
  if (/^\/3\/(tv|movie)\/\d+\/reviews$/u.test(pathname)) return 1800;
  return 600;
}

async function proxyTmdb(request, env, ctx) {
  if (!env.TMDB_READ_TOKEN || String(env.TMDB_READ_TOKEN).trim() === '') {
    return new Response('TMDB_READ_TOKEN is missing', { status: 500 });
  }

  const url = new URL(request.url);
  const pathname = url.pathname;
  if (!isAllowedPath(pathname)) {
    return new Response('Not found', { status: 404, headers: corsHeaders });
  }

  const ttl = ttlSecondsForPath(pathname);
  const cache = caches.default;
  const cacheKey = new Request(url.toString(), { method: 'GET' });
  const cached = await cache.match(cacheKey);
  if (cached) {
    const h = new Headers(cached.headers);
    Object.entries(corsHeaders).forEach(([k, v]) => h.set(k, v));
    return new Response(cached.body, { status: cached.status, headers: h });
  }

  const upstreamUrl = new URL(url.toString());
  upstreamUrl.protocol = 'https:';
  upstreamUrl.hostname = 'api.themoviedb.org';

  const upstreamHeaders = new Headers();
  upstreamHeaders.set('accept', 'application/json');
  upstreamHeaders.set('authorization', `Bearer ${env.TMDB_READ_TOKEN}`);

  const upstreamRes = await fetch(upstreamUrl.toString(), {
    method: 'GET',
    headers: upstreamHeaders,
  });

  const body = await upstreamRes.arrayBuffer();
  const resHeaders = new Headers();
  const contentType = upstreamRes.headers.get('content-type');
  if (contentType) resHeaders.set('content-type', contentType);
  resHeaders.set('cache-control', `public, max-age=${ttl}`);
  Object.entries(corsHeaders).forEach(([k, v]) => resHeaders.set(k, v));

  const res = new Response(body, { status: upstreamRes.status, headers: resHeaders });

  if (upstreamRes.ok) {
    ctx.waitUntil(cache.put(cacheKey, res.clone()));
  }

  return res;
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405, headers: corsHeaders });
    }
    return proxyTmdb(request, env, ctx);
  },
};

