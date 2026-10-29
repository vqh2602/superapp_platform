import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { loadManifest } from '../utils/config.js';
import { logger } from '../utils/logger.js';

export interface BuildCommandOptions {
  outDir?: string;
}

export async function buildProject(options: BuildCommandOptions = {}): Promise<void> {
  const manifest = loadManifest();
  const outDir = options.outDir || 'dist';

  logger.title(`Đóng gói Mini App: ${manifest.name} (v${manifest.version})`);
  logger.step(1, 3, 'Xác thực cấu hình app.json và các quyền permissions...');
  if (manifest.permissions) {
    logger.info(`Permissions: ${manifest.permissions.join(', ')}`);
  }

  logger.step(2, 3, 'Biên dịch mã nguồn với Vite & TypeScript...');
  try {
    execSync('npx vite build', { stdio: 'inherit' });
  } catch (err: any) {
    logger.error('Lỗi khi biên dịch mã nguồn Mini App', err);
    process.exit(1);
  }

  const distPath = path.resolve(process.cwd(), outDir);
  const indexPath = path.join(distPath, manifest.entry || 'index.html');

  if (!fs.existsSync(indexPath)) {
    logger.error(`Không tìm thấy file entry "${manifest.entry}" trong thư mục build: ${distPath}`);
    process.exit(1);
  }

  logger.step(3, 3, 'Tính toán checksum và tạo metadata gói phát hành...');

  // Compute checksum of dist files
  const hash = crypto.createHash('sha256');
  function hashDirectory(dir: string) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
      const fullPath = path.join(dir, file);
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        hashDirectory(fullPath);
      } else {
        hash.update(fs.readFileSync(fullPath));
      }
    }
  }
  hashDirectory(distPath);
  const bundleChecksum = hash.digest('hex');

  const bundleMeta = {
    appId: manifest.appId,
    name: manifest.name,
    version: manifest.version,
    description: manifest.description,
    entry: manifest.entry,
    category: manifest.category,
    themeColor: manifest.themeColor,
    permissions: manifest.permissions,
    checksum: bundleChecksum,
    builtAt: new Date().toISOString(),
  };

  fs.writeFileSync(path.join(distPath, 'bundle-meta.json'), JSON.stringify(bundleMeta, null, 2));

  logger.success(`Đóng gói thành công gói phát hành Mini App!`);
  logger.info(`Thư mục output: ${distPath}`);
  logger.info(`Bundle SHA256: ${bundleChecksum}`);
  console.log(`\nSẵn sàng tải lên với lệnh:\n  npx miniapp upload\n`);
}
