{{flutter_js}}
{{flutter_build_config}}
(function () {
  function stage(name, error) {
    const state = { stage: name, error: error ? String(error.stack || error) : null };
    window.__SUPERAPP_STARTUP__ = state;
    window.dispatchEvent(new CustomEvent('superapp.startup', { detail: state }));
    console[name === 'error' ? 'error' : 'info']('[Flutter startup]', name, state.error || '');
    const label = document.querySelector('#loading p');
    if (label) label.textContent = name === 'error'
      ? 'Không thể khởi chạy Flutter Web: ' + state.error
      : 'Flutter Web: ' + name + '...';
    if (name === 'ready') document.getElementById('loading')?.remove();
  }
  window.addEventListener('flutter-first-frame', () => stage('ready'), { once: true });
  window.addEventListener('unhandledrejection', event => stage('error', event.reason));
  stage('loading-entrypoint');
  Promise.resolve(_flutter.loader.load({
    config: { canvasKitBaseUrl: 'canvaskit/', canvasKitVariant: 'full' },
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        stage('initializing-engine');
        const appRunner = await engineInitializer.initializeEngine();
        stage('running-app');
        await appRunner.runApp();
      } catch (error) {
        stage('error', error);
      }
    }
  })).catch(error => stage('error', error));
})();
