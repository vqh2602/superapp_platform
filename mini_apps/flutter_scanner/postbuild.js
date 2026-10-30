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

fs.mkdirSync(destDir, { recursive: true });
fs.cpSync(srcDir, destDir, { recursive: true });
console.log(`[postbuild] Đã sao chép toàn bộ Flutter Web build từ ${srcDir} sang ${destDir}`);
