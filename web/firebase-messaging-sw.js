// ==============================================================================
// Matrouh Internship — Firebase Cloud Messaging (FCM) Service Worker
// Project: Emtaz-Matrouh | Web App: Matrouh Internship
//
// NOTE ON SECURITY:
// The configuration below contains public Web client identifiers only.
// NEVER put Firebase Admin private keys or service account credentials here.
// ==============================================================================

importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

firebase.initializeApp({
  apiKey: "AIzaSyARdhGJLdx0svHtzA4AlKCNuswy2L0KwSA",
  authDomain: "emtaz-matrouh.firebaseapp.com",
  projectId: "emtaz-matrouh",
  storageBucket: "emtaz-matrouh.firebasestorage.app",
  messagingSenderId: "261034289906",
  appId: "1:261034289906:web:006eff87282e76483cbe6b",
  measurementId: "G-PRB2CXXCYS"
});

const messaging = firebase.messaging();

// Background Message Handler for FCM
messaging.onBackgroundMessage((payload) => {
  console.log('[FCM-SW] Background push notification received:', payload);

  const title = payload.notification?.title || payload.data?.title || 'MANU';
  const body = payload.notification?.body || payload.data?.body || 'لديك تنبيه جديد في المنظومة';
  const targetRoute = payload.data?.route || '/';

  const notificationOptions = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: {
      route: targetRoute,
      fcmMessageId: payload.messageId || 'fcm-' + Date.now()
    },
    vibrate: [200, 100, 200],
    tag: 'matrouh-fcm-' + Date.now(),
    renotify: true,
    actions: [
      { action: 'open', title: 'عرض الآن 👁️' },
      { action: 'dismiss', title: 'إغلاق ✕' }
    ]
  };

  return self.registration.showNotification(title, notificationOptions);
});

// Notification Click Handler (Deep Linking)
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  if (event.action === 'dismiss') {
    return;
  }

  const targetRoute = event.notification.data?.route || '/';
  const urlToOpen = new URL(targetRoute.startsWith('/') ? '#' + targetRoute : '#/' + targetRoute, self.location.origin).href;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.focus();
          client.postMessage({
            type: 'NAVIGATE_TO_ROUTE',
            route: targetRoute
          });
          return;
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(urlToOpen);
      }
    })
  );
});
