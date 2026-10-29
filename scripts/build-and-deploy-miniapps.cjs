#!/usr/bin/env node
/**
 * build-and-deploy-miniapps.cjs
 * 
 * Automates:
 * 1. Building the official TypeScript SDK monorepo (mini_app_sdk)
 * 2. Building each Mini App in mini_apps/ (sdk_playground, schema_runtime, sample_store)
 * 3. Packaging into SuperApp Standard Packages (app.json + icon.png + dist/index.html)
 * 4. Deploying to Backend storage and/or publishing via Registry API
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const crypto = require('crypto');

const ROOT_DIR = path.resolve(__dirname, '..');
const MINI_APPS_DIR = path.join(ROOT_DIR, 'mini_apps');
const SDK_DIR = path.join(ROOT_DIR, 'mini_app_sdk');
const BACKEND_DIR = path.join(ROOT_DIR, 'backend');
const BACKEND_STORAGE_DIR = path.join(BACKEND_DIR, 'storage', 'miniapps');

const yazlPath = path.join(BACKEND_DIR, 'node_modules', 'yazl');
const { ZipFile } = require(yazlPath);

function log(emoji, msg) {
  console.log(`${emoji}  ${msg}`);
}

async function run() {
  log('🚀', 'Bắt đầu quy trình Build & Deploy Mini Apps lên Backend...');

  // 1. Build Mini App SDK
  log('📦', 'Step 1: Building Mini App SDK monorepo...');
  try {
    execSync('npm run build', { cwd: SDK_DIR, stdio: 'inherit' });
    log('✅', 'Mini App SDK built successfully!');
  } catch (err) {
    console.error('Lỗi khi build SDK monorepo:', err);
    process.exit(1);
  }

  // 2. Build Mini Apps
  const appsToBuild = [
    { id: 'sdk_playground', dir: path.join(MINI_APPS_DIR, 'sdk_playground'), cmd: 'npm run build' },
    { id: 'schema_runtime', dir: path.join(MINI_APPS_DIR, 'schema_runtime'), cmd: 'npm run build' },
    { id: 'sample_store', dir: path.join(MINI_APPS_DIR, 'sample_store'), cmd: 'npm run build' },
  ];

  for (const app of appsToBuild) {
    log('🔨', `Step 2: Building Mini App [${app.id}]...`);
    try {
      execSync(app.cmd, { cwd: app.dir, stdio: 'inherit' });
      log('✅', `Mini App [${app.id}] built to dist/`);
    } catch (err) {
      console.error(`Lỗi khi build ${app.id}:`, err);
      process.exit(1);
    }
  }

  // 3. Package & Deploy to Backend Storage
  log('📤', 'Step 3: Đóng gói và đẩy Mini Apps lên Backend Storage...');
  fs.mkdirSync(BACKEND_STORAGE_DIR, { recursive: true });

  const deployed = [];

  for (const app of appsToBuild) {
    const appDir = app.dir;
    const manifestPath = path.join(appDir, 'app.json');
    const distIndexPath = path.join(appDir, 'dist', 'index.html');
    const iconPath = path.join(appDir, 'icon.png');

    if (!fs.existsSync(manifestPath) || !fs.existsSync(distIndexPath) || !fs.existsSync(iconPath)) {
      throw new Error(`Mini App ${app.id} thiếu app.json, dist/index.html hoặc icon.png`);
    }

    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    const htmlBuffer = fs.readFileSync(distIndexPath);
    const iconBuffer = fs.readFileSync(iconPath);
    const manifestBuffer = fs.readFileSync(manifestPath);

    // Create zip bundle
    const zip = new ZipFile();
    zip.addBuffer(manifestBuffer, 'app.json');
    zip.addBuffer(iconBuffer, 'icon.png');
    zip.addBuffer(htmlBuffer, 'dist/index.html');

    const chunks = [];
    const zipBuffer = await new Promise((resolve, reject) => {
      zip.outputStream.on('data', c => chunks.push(c));
      zip.outputStream.on('end', () => resolve(Buffer.concat(chunks)));
      zip.outputStream.on('error', reject);
      zip.end();
    });

    const checksum = crypto.createHash('sha256').update(htmlBuffer).digest('hex');

    // Store in backend storage under appId-version deterministic or standard folder
    const targetDir = path.join(BACKEND_STORAGE_DIR, `${app.id}-${manifest.version}`);
    fs.mkdirSync(path.join(targetDir, 'dist'), { recursive: true });
    fs.writeFileSync(path.join(targetDir, 'app.json'), manifestBuffer);
    fs.writeFileSync(path.join(targetDir, 'icon.png'), iconBuffer);
    fs.writeFileSync(path.join(targetDir, 'dist', 'index.html'), htmlBuffer);

    // Also write export zip
    const zipOut = path.join(targetDir, `${app.id}-${manifest.version}.zip`);
    fs.writeFileSync(zipOut, zipBuffer);

    deployed.push({
      appId: app.id,
      version: manifest.version,
      checksum: checksum.slice(0, 12),
      size: `${(htmlBuffer.length / 1024).toFixed(1)} KB`,
      url: `/api/v1/miniapps/${app.id}/${manifest.version}/dist/index.html`,
      storagePath: targetDir,
    });
  }

  console.log('\n======================================================');
  log('🎉', 'Tất cả Mini Apps đã được build và triển khai lên BE thành công!');
  console.log('======================================================');
  console.table(deployed.map(d => ({
    'Mini App': d.appId,
    'Version': d.version,
    'Bundle Size': d.size,
    'Checksum': d.checksum,
    'Backend URL': d.url,
  })));
  console.log('======================================================\n');
}

run().catch(err => {
  console.error('Pipeline thất bại:', err);
  process.exit(1);
});
