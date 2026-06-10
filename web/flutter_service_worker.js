// Self-destructing service worker.
//
// Earlier local builds were produced without --pwa-strategy=none, so browsers
// that opened them keep serving the stale cached app shell (old login badge,
// old buttons) even after rebuilds. Release builds now use
// --pwa-strategy=none, and this file replaces the previously registered
// worker on its next update check: it deletes every cache, unregisters
// itself, and reloads open tabs so the freshly served build wins.
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((key) => caches.delete(key)));
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const client of clients) {
      client.navigate(client.url);
    }
  })());
});
