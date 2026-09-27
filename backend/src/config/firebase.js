const admin = require('firebase-admin');
const { env } = require('./env');

let app = null;

function initFirebase() {
  if (!env.firebaseProjectId || !env.firebaseClientEmail || !env.firebasePrivateKey) {
    console.warn('Firebase Admin credentials missing — push notifications disabled');
    return null;
  }

  if (admin.apps.length) {
    app = admin.apps[0];
    return app;
  }

  app = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: env.firebaseProjectId,
      clientEmail: env.firebaseClientEmail,
      privateKey: env.firebasePrivateKey,
    }),
  });

  console.log('Firebase Admin initialized');
  return app;
}

function getMessaging() {
  if (!app && !admin.apps.length) return null;
  try {
    return admin.messaging();
  } catch (_) {
    return null;
  }
}

module.exports = { initFirebase, getMessaging };
