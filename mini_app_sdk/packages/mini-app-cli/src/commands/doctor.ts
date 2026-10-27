import fs from 'node:fs';
import path from 'node:path';
import { logger } from '../utils/logger.js';

export async function runDoctor(): Promise<void> {
  logger.title('Kiểm tra môi trường phát triển Mini App (Doctor)');

  // 1. Node.js
  const nodeVer = process.version;
  const major = parseInt(nodeVer.slice(1).split('.')[0], 10);
  if (major >= 18) {
    logger.success(`Node.js version: ${nodeVer} (Tốt)`);
  } else {
    logger.warn(`Node.js version: ${nodeVer} (Khuyến nghị nâng cấp lên >= v18)`);
  }

  // 2. app.json
  const manifestPath = path.join(process.cwd(), 'app.json');
  if (fs.existsSync(manifestPath)) {
    try {
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
      logger.success(`Tìm thấy app.json hợp lệ: ${manifest.name} (${manifest.appId}) v${manifest.version}`);
    } catch {
      logger.error('File app.json bị lỗi cú pháp JSON');
    }
  } else {
    logger.info('Chưa có file app.json trong thư mục hiện tại (Dùng "miniapp create <tên>" để tạo mới)');
  }

  // 3. Dynamic Registry Backend check
  try {
    const res = await fetch('http://localhost:3000/api/v1/registry/apps', {
      headers: { 'x-tenant-id': 'tenant_001' },
      signal: AbortSignal.timeout(1500),
    });
    if (res.ok) {
      logger.success('Kết nối SuperApp Dynamic Registry Backend (Port 3000): Sẵn sàng');
    } else {
      logger.warn(`Dynamic Registry Backend phản hồi HTTP ${res.status}`);
    }
  } catch {
    logger.info('Dynamic Registry Backend (Port 3000) chưa được bật hoặc chạy cổng khác');
  }

  console.log('\nMọi kiểm tra cơ bản đã hoàn tất!\n');
}
