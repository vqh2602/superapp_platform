// Sử dụng Official SDK: import superApp from '@vqh2602/mini-app-sdk';
document.querySelector('#close').addEventListener('click', async () => {
  try {
    if (window.superApp?.closeApp) {
      await window.superApp.closeApp();
    } else if (window.FlutterBridge?.postMessage) {
      window.FlutterBridge.postMessage(JSON.stringify({ id: crypto.randomUUID(), appId: 'web_demo', action: 'navigation.close', payload: {} }));
    } else {
      document.querySelector('#status').textContent = 'Mở trong Super App để gọi navigation.close.';
    }
  } catch (err) {
    document.querySelector('#status').textContent = 'Lỗi: ' + (err.message || err);
  }
});
