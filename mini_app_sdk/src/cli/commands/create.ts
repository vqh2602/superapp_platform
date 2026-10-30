import fs from 'node:fs';
import path from 'node:path';
import { logger } from '../utils/logger.js';

export interface CreateCommandOptions {
  template?: string;
}

export async function createProject(projectName: string, options: CreateCommandOptions = {}): Promise<void> {
  const targetDir = path.resolve(process.cwd(), projectName);

  if (fs.existsSync(targetDir)) {
    logger.error(`Thư mục "${projectName}" đã tồn tại. Vui lòng chọn tên khác hoặc xoá thư mục cũ.`);
    process.exit(1);
  }

  logger.title(`Khởi tạo Mini App mới: ${projectName}`);
  logger.step(1, 3, `Đang tạo cấu trúc thư mục tại: ${targetDir}`);
  fs.mkdirSync(targetDir, { recursive: true });
  fs.mkdirSync(path.join(targetDir, 'src'), { recursive: true });
  fs.mkdirSync(path.join(targetDir, 'public'), { recursive: true });

  const sanitizedId = projectName.toLowerCase().replace(/[^a-z0-9_-]/g, '_');

  // 1. app.json manifest
  const appJson = {
    appId: sanitizedId,
    name: projectName.replace(/[-_]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()),
    version: '1.0.0',
    description: `SuperApp Mini App: ${projectName}`,
    entry: 'index.html',
    category: 'utilities',
    themeColor: '#0068FF',
    permissions: [
      'auth.userProfile',
      'device.battery',
      'device.network',
      'storage',
    ],
  };
  fs.writeFileSync(path.join(targetDir, 'app.json'), JSON.stringify(appJson, null, 2));

  // 2. package.json
  const packageJson = {
    name: projectName,
    private: true,
    version: '1.0.0',
    type: 'module',
    scripts: {
      dev: 'vite',
      build: 'tsc && vite build',
      preview: 'vite preview',
    },
    dependencies: {
      '@vqh2602/mini-app-sdk': '^1.0.7',
    },
    devDependencies: {
      typescript: '^5.6.3',
      vite: '^5.4.11',
    },
  };
  fs.writeFileSync(path.join(targetDir, 'package.json'), JSON.stringify(packageJson, null, 2));

  // 3. tsconfig.json
  const tsconfig = {
    compilerOptions: {
      target: 'ES2020',
      useDefineForClassFields: true,
      module: 'ESNext',
      lib: ['ES2020', 'DOM', 'DOM.Iterable'],
      skipLibCheck: true,
      moduleResolution: 'bundler',
      allowImportingTsExtensions: true,
      resolveJsonModule: true,
      isolatedModules: true,
      noEmit: true,
      strict: true,
      noUnusedLocals: true,
      noUnusedParameters: true,
      noFallthroughCasesInSwitch: true,
    },
    include: ['src'],
  };
  fs.writeFileSync(path.join(targetDir, 'tsconfig.json'), JSON.stringify(tsconfig, null, 2));

  // 4. vite.config.ts
  const viteConfig = `import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  server: {
    port: 3000,
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
  },
});
`;
  fs.writeFileSync(path.join(targetDir, 'vite.config.ts'), viteConfig);

  // 5. index.html
  const indexHtml = `<!DOCTYPE html>
<html lang="vi">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover" />
    <title>${appJson.name}</title>
    <style>
      * { box-sizing: border-box; margin: 0; padding: 0; }
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; color: #0f172a; padding: 16px; }
      .card { background: white; border-radius: 12px; padding: 16px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
      .btn { display: block; width: 100%; padding: 12px; border-radius: 8px; border: none; font-weight: 600; font-size: 14px; cursor: pointer; margin-bottom: 8px; }
      .btn-primary { background: #0068FF; color: white; }
      .btn-success { background: #10B981; color: white; }
      .btn-secondary { background: #e2e8f0; color: #334155; }
      h1 { font-size: 20px; font-weight: 700; margin-bottom: 4px; }
      p { font-size: 13px; color: #64748b; line-height: 1.5; }
      pre { background: #0f172a; color: #38bdf8; padding: 12px; border-radius: 8px; font-size: 12px; overflow-x: auto; max-height: 200px; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>🚀 ${appJson.name}</h1>
      <p>SuperApp Mini App SDK Demo Starter</p>
    </div>

    <div class="card">
      <button id="btnLogin" class="btn btn-primary">👤 1. Đăng nhập SuperApp</button>
      <button id="btnPay" class="btn btn-success">💳 2. Thanh toán đơn hàng</button>
      <button id="btnDevice" class="btn btn-secondary">📱 3. Kiểm tra thông tin thiết bị</button>
      <button id="btnToast" class="btn btn-secondary">🔔 4. Hiển thị thông báo Toast</button>
    </div>

    <div class="card">
      <p style="font-weight: 600; margin-bottom: 8px;">Kết quả phản hồi:</p>
      <pre id="output">Sẵn sàng gọi SDK...</pre>
    </div>

    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
`;
  fs.writeFileSync(path.join(targetDir, 'index.html'), indexHtml);

  // 6. src/main.ts
  const mainTs = `import superApp from '@vqh2602/mini-app-sdk';

const outputEl = document.getElementById('output') as HTMLPreElement;

function log(data: any) {
  outputEl.textContent = JSON.stringify(data, null, 2);
}

// 1. Đăng nhập
document.getElementById('btnLogin')?.addEventListener('click', async () => {
  try {
    const res = await superApp.auth.login({ scopes: ['user.profile', 'user.phone'] });
    log(res);
    await superApp.ui.showToast(\`Xin chào \${res.user.name}!\`);
  } catch (err: any) {
    log({ error: err });
  }
});

// 2. Thanh toán
document.getElementById('btnPay')?.addEventListener('click', async () => {
  try {
    const order = await superApp.transport.invoke<{ orderId: string }>('payment.createOrder', {
      orderId: 'ORDER_' + Date.now(),
      amount: 45000,
      description: 'Thanh toán đơn hàng mẫu Mini App',
    });
    const res = await superApp.transport.invoke('payment.openCheckout', { orderId: order.orderId });
    log(res);
  } catch (err: any) {
    log({ error: err });
  }
});

// 3. Thông tin thiết bị
document.getElementById('btnDevice')?.addEventListener('click', async () => {
  try {
    const battery = await superApp.device.getBatteryInfo();
    const network = await superApp.device.getNetworkInfo();
    const system = await superApp.device.getSystemInfo();
    log({ battery, network, system });
  } catch (err: any) {
    log({ error: err });
  }
});

// 4. Toast & Rung
document.getElementById('btnToast')?.addEventListener('click', async () => {
  await superApp.device.vibrate('light');
  await superApp.ui.showToast('Thông báo Toast từ SuperApp SDK');
});
`;
  fs.writeFileSync(path.join(targetDir, 'src/main.ts'), mainTs);

  // 7. .gitignore
  const gitignore = `node_modules
dist
.DS_Store
*.local
`;
  fs.writeFileSync(path.join(targetDir, '.gitignore'), gitignore);

  // 8. README.md
  const readme = `# ${projectName}

Dự án Mini App chạy trên nền tảng SuperApp.

## Bắt đầu

\`\`\`bash
# 1. Cài đặt thư viện
npm install

# 2. Khởi chạy dev server & simulator
npx miniapp dev

# 3. Đóng gói sản phẩm
npx miniapp build

# 4. Xuất bản lên SuperApp Dynamic Registry
npx miniapp upload
\`\`\`
`;
  fs.writeFileSync(path.join(targetDir, 'README.md'), readme);

  logger.step(2, 3, 'Khởi tạo mã nguồn và file cấu hình manifest app.json thành công!');
  logger.step(3, 3, 'Hoàn tất.');
  logger.success(`Mini App "${projectName}" đã sẵn sàng!`);
  console.log(`\nTiếp theo, hãy thực hiện:\n  cd ${projectName}\n  npm install\n  npx miniapp dev\n`);
}
