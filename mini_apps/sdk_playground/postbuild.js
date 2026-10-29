import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const htmlPath = path.resolve(__dirname, 'dist/index.html');

if (fs.existsSync(htmlPath)) {
  let content = fs.readFileSync(htmlPath, 'utf8');

  const scriptStart = content.indexOf('<script');
  const scriptEnd = content.lastIndexOf('</script>');

  if (scriptStart !== -1 && scriptEnd !== -1) {
    let scriptTag = content.substring(scriptStart, scriptEnd + 9);
    // Remove type="module" and crossorigin to avoid iOS WKWebView file:// protocol restrictions
    scriptTag = scriptTag
      .replace(/\s*type=["']module["']/g, '')
      .replace(/\s*crossorigin(?:=["'][^"']*["'])?/g, '');

    // Remove the bundle script from its original position
    content = content.slice(0, scriptStart) + content.slice(scriptEnd + 9);

    const earlyErrorListener = `<script>
      window.__WEBVIEW_LOGS__ = window.__WEBVIEW_LOGS__ || [];
      window.addEventListener('error', function(e) {
        var msg = (e.message || 'Script Error');
        if (e.filename) msg += ' (' + e.filename + ':' + (e.lineno || '') + ':' + (e.colno || '') + ')';
        var entry = {
          id: 'err_' + Date.now(),
          type: 'error',
          level: 'error',
          message: msg,
          stack: e.error && e.error.stack ? e.error.stack : null,
          timeMs: Date.now()
        };
        window.__WEBVIEW_LOGS__.push(entry);
        try {
          if (window.__SuperAppWebDebug__ && window.__SuperAppWebDebug__.postMessage) {
            window.__SuperAppWebDebug__.postMessage(JSON.stringify(entry));
          }
        } catch(ex) {}
      });
    </script>
  `;

    content = content.replace('</head>', () => `${earlyErrorListener}</head>`);
    content = content.replace('</body>', () => `    ${scriptTag}\n  </body>`);
  }

  fs.writeFileSync(htmlPath, content, 'utf8');
  console.log('[postbuild] Safely positioned bundle script before </body> in sdk_playground/index.html');
}
