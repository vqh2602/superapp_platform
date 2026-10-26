import React from 'react';
import ReactDOM from 'react-dom/client';
import { App } from './App';

function mount() {
  const rootEl = document.getElementById('root');
  if (rootEl) {
    ReactDOM.createRoot(rootEl).render(
      <React.StrictMode>
        <App />
      </React.StrictMode>
    );
  } else {
    // If DOM is not yet ready, wait for DOMContentLoaded
    if (document.readyState === 'loading') {
      window.addEventListener('DOMContentLoaded', mount, { once: true });
    } else {
      setTimeout(mount, 50);
    }
  }
}

mount();
