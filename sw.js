const CACHE = 'our-shopping-shell-v11';
const ROOT = new URL('./', self.location.href).href;
const SDK = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';
const ASSETS = [
  new URL('new-year-banner.jpg', ROOT).href,
  new URL('apple-touch-icon.png', ROOT).href,
  SDK
];

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await cache.addAll([ROOT, ...ASSETS].map(url => new Request(url, {cache: 'reload'})));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter(name => name.startsWith('our-shopping-shell-') && name !== CACHE)
      .map(name => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  if (request.mode === 'navigate' && request.url.startsWith(ROOT)) {
    const network = (async () => {
      try {
        const response = await fetch(request);
        if (!response.ok) return null;
        if (response.headers.get('Content-Type')?.includes('text/html')) {
          const cache = await caches.open(CACHE);
          await cache.put(ROOT, response.clone());
        }
        return response;
      } catch {
        return null;
      }
    })();
    event.waitUntil(network.then(() => {}));
    event.respondWith((async () => {
      let timer;
      const deadline = new Promise(resolve => { timer = setTimeout(() => resolve(null), 1600); });
      const fresh = await Promise.race([network, deadline]);
      clearTimeout(timer);
      return fresh || await caches.match(ROOT) || await network || Response.error();
    })());
    return;
  }
  if (ASSETS.includes(request.url)) {
    event.respondWith((async () => {
      const cached = await caches.match(request.url);
      if (cached) return cached;
      const response = await fetch(request);
      if (response.ok) {
        const cache = await caches.open(CACHE);
        await cache.put(request.url, response.clone());
      }
      return response;
    })());
  }
});
