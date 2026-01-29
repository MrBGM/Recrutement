importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyA4gFkg8wz1zB7cBaQfLHf3Lx2fXoBY9Zc",
  authDomain: "ai-chat-23aa5.firebaseapp.com",
  projectId: "ai-chat-23aa5",
  storageBucket: "ai-chat-23aa5.firebasestorage.app",
  messagingSenderId: "364659039092",
  appId: "1:364659039092:web:d06724261cff094a0aaa21"
});

const messaging = firebase.messaging();

// ICÔNES - Créez ces fichiers dans web/icons/
const ICONS = {
  default: '/icons/icon-192x192.png',
  badge: '/icons/badge-96x96.png',
  message: '/icons/message-192x192.png',
  group: '/icons/group-192x192.png'
};

// Gestionnaire de messages en arrière-plan
messaging.onBackgroundMessage((payload) => {
  console.log('[SW] Message reçu:', payload);
  
  const notificationData = payload.data || {};
  const notificationTitle = payload.notification?.title || 'AI Chat';
  const notificationBody = payload.notification?.body || '';
  
  let icon = ICONS.default;
  let tag = 'chat-notification';
  let actions = [];
  
  // Personnaliser selon le type
  if (notificationData.type === 'new_message') {
    icon = notificationData.senderName?.includes('groupe') 
      ? ICONS.group 
      : ICONS.message;
    
    tag = `message-${notificationData.conversationId}`;
    
    actions = [
      {
        action: 'reply',
        title: 'Répondre',
        icon: '/icons/reply-96x96.png'
      },
      {
        action: 'open',
        title: 'Ouvrir',
        icon: '/icons/open-96x96.png'
      }
    ];
  }
  
  const notificationOptions = {
    body: notificationBody,
    icon: icon,
    badge: ICONS.badge,
    tag: tag,
    renotify: true,
    requireInteraction: false,
    silent: false,
    data: notificationData,
    actions: actions,
    timestamp: Date.now()
  };
  
  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Gestion des clics
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification cliquée:', event.notification.data);
  
  event.notification.close();
  
  const data = event.notification.data || {};
  const conversationId = data.conversationId;
  const urlToOpen = conversationId 
    ? `/?conversation=${conversationId}&message=${data.messageId || ''}`
    : '/';
  
  // Action spécifique
  if (event.action === 'reply') {
    // Ouvrir avec focus sur champ de saisie
    const replyUrl = `/?conversation=${conversationId}&focus=input`;
    event.waitUntil(openOrFocusWindow(replyUrl));
    return;
  }
  
  if (event.action === 'open' || !event.action) {
    event.waitUntil(openOrFocusWindow(urlToOpen));
  }
});

// Gestion de la fermeture
self.addEventListener('notificationclose', (event) => {
  console.log('[SW] Notification fermée:', event.notification.tag);
  // Optionnel: tracker les analytics
});

// Helper pour ouvrir/focus une fenêtre
function openOrFocusWindow(url) {
  return clients.matchAll({
    type: 'window',
    includeUncontrolled: true
  }).then((clientList) => {
    // Chercher un onglet déjà ouvert
    for (const client of clientList) {
      if (client.url.includes(self.location.origin) && 'focus' in client) {
        // Navigation si nécessaire
        if (!client.url.includes(url.split('?')[0])) {
          client.navigate(url);
        }
        return client.focus();
      }
    }
    
    // Ouvrir un nouvel onglet
    if (clients.openWindow) {
      return clients.openWindow(url);
    }
  });
}

// Gestion des messages du frontend
self.addEventListener('message', (event) => {
  console.log('[SW] Message du frontend:', event.data);
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

console.log('[SW] ✅ Service Worker initialisé avec succès');