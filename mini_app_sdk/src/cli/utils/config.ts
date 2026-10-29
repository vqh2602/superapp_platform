import fs from 'node:fs';
import path from 'node:path';

export interface MiniAppManifest {
  appId: string;
  name: string;
  version: string;
  description?: string;
  entry: string;
  category?: string;
  iconUrl?: string;
  themeColor?: string;
  permissions?: string[];
}

export function loadManifest(cwd: string = process.cwd()): MiniAppManifest {
  const manifestPath = path.join(cwd, 'app.json');
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`File cấu hình "app.json" không tồn tại trong thư mục: ${cwd}`);
  }

  try {
    const content = fs.readFileSync(manifestPath, 'utf-8');
    const manifest = JSON.parse(content) as MiniAppManifest;

    if (!manifest.appId) {
      throw new Error('Trường "appId" là bắt buộc trong app.json (ví dụ: "coffee_shop")');
    }
    if (!manifest.name) {
      throw new Error('Trường "name" là bắt buộc trong app.json');
    }
    if (!manifest.version) {
      throw new Error('Trường "version" là bắt buộc trong app.json (ví dụ: "1.0.0")');
    }

    return manifest;
  } catch (err: any) {
    throw new Error(`Lỗi đọc file app.json: ${err.message}`);
  }
}
