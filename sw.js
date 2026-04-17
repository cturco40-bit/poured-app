var CACHE_VERSION = 'poured-v37';

self.addEventListener('install', function(e) {
  e.waitUntil(
    caches.open(CACHE_VERSION).then(function(cache) {
      return cache.addAll(['./', './index.html']);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.filter(function(k) { return k !== CACHE_VERSION; }).map(function(k) { return caches.delete(k); }));
    }).then(function() {
      return self.clients.claim();
    }).then(function() {
      return self.clients.matchAll();
    }).then(function(clients) {
      clients.forEach(function(c) {
        c.postMessage({ type: 'SW_UPDATED', version: CACHE_VERSION });
      });
    })
  );
});

self.addEventListener('fetch', function(e) {
  var req = e.request;
  // Network-first for navigation (HTML) — always get fresh content
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req).then(function(res) {
        return caches.open(CACHE_VERSION).then(function(cache) {
          cache.put(req, res.clone());
          return res;
        });
      }).catch(function() {
        return caches.match(req);
      })
    );
  } else {
    // Network-first for all other assets too — no stale cache trap
    e.respondWith(
      fetch(req).then(function(res) {
        return caches.open(CACHE_VERSION).then(function(cache) {
          cache.put(req, res.clone());
          return res;
        });
      }).catch(function() {
        return caches.match(req);
      })
    );
  }
});
