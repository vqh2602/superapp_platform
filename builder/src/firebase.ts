import { initializeApp } from "firebase/app";
import { getAnalytics, isSupported } from "firebase/analytics";

// Your web app's Firebase configuration
export const firebaseConfig = {
  apiKey: "AIzaSyDVIT2yCEKT7HkadBERP0cHNJAtdWJZmAY",
  authDomain: "superapp-platform-3c7d6.firebaseapp.com",
  projectId: "superapp-platform-3c7d6",
  storageBucket: "superapp-platform-3c7d6.firebasestorage.app",
  messagingSenderId: "755925909283",
  appId: "1:755925909283:web:4882f4e649061c98ed1696",
  measurementId: "G-TZDYXZXV5N"
};

// Initialize Firebase
export const app = initializeApp(firebaseConfig);

// Initialize Analytics (optional/supported check)
export let analytics: ReturnType<typeof getAnalytics> | null = null;
if (typeof window !== 'undefined') {
  isSupported().then(supported => {
    if (supported) {
      analytics = getAnalytics(app);
    }
  }).catch(() => undefined);
}

