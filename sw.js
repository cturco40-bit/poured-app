var CACHE_VERSION = 'poured-v28';

self.addEventListener('install', function(e) {
  self.skipWaiting();
});

self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.map(function(k) { return caches.delete(k); }));
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
    e.respondWith(
      fetch(req).catch(function() {
        return caches.match(req);
      })
    );
  }
});
