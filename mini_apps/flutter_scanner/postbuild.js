import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const srcDir = path.resolve(__dirname, 'build/web');
const destDir = path.resolve(__dirname, 'dist');

if (!fs.existsSync(srcDir)) {
  console.error('[postbuild] Thư mục build/web không tồn tại. Hãy chạy flutter build web trước.');
  process.exit(1);
}

fs.rmSync(destDir, { recursive: true, force: true });
fs.mkdirSync(destDir, { recursive: true });
fs.cpSync(srcDir, destDir, { recursive: true });
console.log(`[postbuild] Đã sao chép toàn bộ Flutter Web build từ ${srcDir} sang ${destDir}`);

// Flutter's CLI accepts absolute base paths; hosted miniapp packages need a
// relative base so their JS, fonts and CanvasKit resolve inside the version URL.
const indexPath = path.join(destDir, 'index.html');
const index = fs.readFileSync(indexPath, 'utf8');
fs.writeFileSync(indexPath, index.replace(/<base href="[^"]*">/, '<base href="./">'));

// This JS build uses the full CanvasKit renderer on all browsers. Avoid shipping
// unused Chromium/Skwasm/debug-symbol variants with the downloadable miniapp.
const canvasKit = path.join(destDir, 'canvaskit');
fs.rmSync(canvasKit, { recursive: true, force: true });
fs.mkdirSync(canvasKit, { recursive: true });
for (const file of ['canvaskit.js', 'canvaskit.wasm']) {
  fs.copyFileSync(path.join(srcDir, 'canvaskit', file), path.join(canvasKit, file));
}
