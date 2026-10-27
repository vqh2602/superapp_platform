document.querySelector('#close').addEventListener('click', () => {
  if (window.FlutterBridge?.postMessage) {
    window.FlutterBridge.postMessage(JSON.stringify({ id: crypto.randomUUID(), appId: 'web_demo', action: 'navigation.close', payload: {} }));
  } else {
    document.querySelector('#status').textContent = 'Mở trong Super App để gọi navigation.close.';
  }
});
