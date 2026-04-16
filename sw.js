// Poured — Service Worker (network-first with cache fallback)
var CACHE = 'poured-v16';
var ASSETS = ['./', './index.html'];

self.addEventListener('install', function(e) {
  e.waitUntil(
    caches.open(CACHE).then(function(cache) {
      return cache.addAll(ASSETS);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys
          .filter(function(k) { return k !== CACHE; })
          .map(function(k) { return caches.delete(k); })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', function(e) {
  if (e.request.method !== 'GET') return;
  if (!e.request.url.startsWith(self.location.origin)) return;

  // Network-first: try network, fall back to cache (offline support)
  e.respondWith(
    fetch(e.request).then(function(res) {
      if (res && res.status === 200 && res.type === 'basic') {
        var clone = res.clone();
        caches.open(CACHE).then(function(cache) {
          cache.put(e.request, clone);
        });
      }
      return res;
    }).catch(function() {
      return caches.match(e.request);
    })
  );
});

// Notify clients when a new version activates
self.addEventListener('message', function(e) {
  if (e.data === 'skipWaiting') self.skipWaiting();
});
