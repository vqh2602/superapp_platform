#!/usr/bin/env node
/**
 * bump-version.cjs
 * 
 * Tự động đồng bộ và nâng phiên bản (auto-bump version) trên toàn bộ hệ sinh thái:
 * 1. Kiểm tra phiên bản mới nhất trên npm registry (@vqh2602/mini-app-sdk)
 * 2. Tự động tính toán phiên bản mới (patch/minor/major) để đảm bảo không bị lỗi 403 Forbidden
 * 3. Đồng bộ vào:
 *    - mini_app_sdk (package.json, client.ts, cli/index.ts)
 *    - mini_apps: sdk_playground, schema_runtime, sample_store (package.json, app.json)
 *    - backend: seed.service.ts, registry.service.ts
 *    - test/unit/ (Dart unit test manifests)
 * 4. Rebuild SDK và đồng bộ vào local/global node_modules
 * 5. Rebuild & Deploy các Mini Apps lên Backend
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '..');
const SDK_DIR = path.join(ROOT_DIR, 'mini_app_sdk');
const MINI_APPS_DIR = path.join(ROOT_DIR, 'mini_apps');
const BACKEND_DIR = path.join(ROOT_DIR, 'backend');
const USER_NODE_MODULES_SDK = '/Users/vuongquanghuy/node_modules/@vqh2602/mini-app-sdk';

function log(emoji, msg) {
  console.log(`${emoji}  ${msg}`);
}

function parseSemver(v) {
  const clean = (v || '1.0.0').replace(/^[^0-9]*/, '');
  const parts = clean.split('.').map(n => parseInt(n, 10) || 0);
  while (parts.length < 3) parts.push(0);
  return parts;
}

function semverGt(v1, v2) {
  const [a1, b1, c1] = parseSemver(v1);
  const [a2, b2, c2] = parseSemver(v2);
  if (a1 !== a2) return a1 > a2;
  if (b1 !== b2) return b1 > b2;
  return c1 > c2;
}

function bump(version, type = 'patch') {
  const [major, minor, patch] = parseSemver(version);
  if (type === 'major') return `${major + 1}.0.0`;
  if (type === 'minor') return `${major}.${minor + 1}.0`;
  return `${major}.${minor}.${patch + 1}`;
}

function getLatestNpmVersion(pkgName) {
  try {
    const res = execSync(`npm view ${pkgName} version`, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'ignore'], timeout: 5000 });
    return res.trim();
  } catch {
    return null;
  }
}

function replaceInFile(filePath, regex, replacement) {
  if (!fs.existsSync(filePath)) return;
  const content = fs.readFileSync(filePath, 'utf-8');
  const updated = content.replace(regex, replacement);
  if (content !== updated) {
    fs.writeFileSync(filePath, updated, 'utf-8');
  }
}

async function main() {
  const args = process.argv.slice(2);
  let bumpType = args[0] || 'patch'; // patch | minor | major | check-publish | explicit version

  log('🔄', 'Bắt đầu quy trình kiểm tra và nâng phiên bản tự động...');

  // 1. Đọc phiên bản cục bộ hiện tại
  const sdkPkgPath = path.join(SDK_DIR, 'package.json');
  const sdkPkg = JSON.parse(fs.readFileSync(sdkPkgPath, 'utf-8'));
  const currentLocalVersion = sdkPkg.version;
  log('📦', `Phiên bản cục bộ hiện tại: ${currentLocalVersion}`);

  // 2. Tra cứu phiên bản mới nhất đã xuất bản trên npm
  const npmVersion = getLatestNpmVersion('@vqh2602/mini-app-sdk');
  log('🌐', `Phiên bản trên npm registry: ${npmVersion || 'chưa tìm thấy (offline)'}`);

  let baseVersion = currentLocalVersion;
  if (npmVersion && (semverGt(npmVersion, currentLocalVersion) || npmVersion === currentLocalVersion)) {
    baseVersion = npmVersion;
  }

  let nextVersion;
  if (/^\d+\.\d+\.\d+/.test(bumpType)) {
    nextVersion = bumpType;
  } else if (bumpType === 'check-publish') {
    if (npmVersion && !semverGt(currentLocalVersion, npmVersion)) {
      nextVersion = bump(baseVersion, 'patch');
      log('⚡', `Phát hiện v${currentLocalVersion} đã có trên npm. Tự động tăng lên: v${nextVersion}`);
    } else {
      log('✅', `Phiên bản v${currentLocalVersion} chưa có trên npm, giữ nguyên để publish.`);
      return;
    }
  } else {
    nextVersion = bump(baseVersion, bumpType);
  }

  log('🚀', `Nâng toàn bộ hệ thống lên phiên bản: \x1b[32m\x1b[1mv${nextVersion}\x1b[0m (từ v${currentLocalVersion})`);

  // 3. Cập nhật mini_app_sdk
  sdkPkg.version = nextVersion;
  fs.writeFileSync(sdkPkgPath, JSON.stringify(sdkPkg, null, 2) + '\n', 'utf-8');

  replaceInFile(
    path.join(SDK_DIR, 'src', 'core', 'client.ts'),
    /public readonly version = '[^']+';/,
    `public readonly version = '${nextVersion}';`
  );

  replaceInFile(
    path.join(SDK_DIR, 'src', 'cli', 'index.ts'),
    /\.version\('[^']+'\);/,
    `.version('${nextVersion}');`
  );

  // 4. Cập nhật các Mini Apps
  const miniApps = ['sdk_playground', 'schema_runtime', 'sample_store'];
  for (const appId of miniApps) {
    const pkgPath = path.join(MINI_APPS_DIR, appId, 'package.json');
    if (fs.existsSync(pkgPath)) {
      const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
      pkg.version = nextVersion;
      if (pkg.dependencies && pkg.dependencies['@vqh2602/mini-app-sdk']) {
        pkg.dependencies['@vqh2602/mini-app-sdk'] = `^${nextVersion}`;
      }
      fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n', 'utf-8');
    }

    const appJsonPath = path.join(MINI_APPS_DIR, appId, 'app.json');
    if (fs.existsSync(appJsonPath)) {
      const manifest = JSON.parse(fs.readFileSync(appJsonPath, 'utf-8'));
      manifest.version = nextVersion;
      fs.writeFileSync(appJsonPath, JSON.stringify(manifest, null, 2) + '\n', 'utf-8');
    }
  }

  // 5. Cập nhật Backend Seeding & Registry
  replaceInFile(
    path.join(BACKEND_DIR, 'src', 'modules', 'seed', 'seed.service.ts'),
    /const targetVersion = '[^']+';/,
    `const targetVersion = '${nextVersion}';`
  );
  replaceInFile(
    path.join(BACKEND_DIR, 'src', 'modules', 'seed', 'seed.service.ts'),
    /Registry v[0-9.]+/g,
    `Registry v${nextVersion}`
  );
  replaceInFile(
    path.join(BACKEND_DIR, 'src', 'modules', 'seed', 'seed.service.ts'),
    /hosted \(v[0-9.]+\)/g,
    `hosted (v${nextVersion})`
  );
  replaceInFile(
    path.join(BACKEND_DIR, 'src', 'modules', 'registry', 'registry.service.ts'),
    /\/schema_runtime\/[0-9.]+\/dist/g,
    `/schema_runtime/${nextVersion}/dist`
  );

  // 6. Cập nhật Dart Unit Tests
  const dartTests = [
    path.join(ROOT_DIR, 'test', 'unit', 'action_bottom_sheet_test.dart'),
    path.join(ROOT_DIR, 'test', 'unit', 'dispatcher_test.dart'),
    path.join(ROOT_DIR, 'test', 'unit', 'native_features_test.dart'),
    path.join(ROOT_DIR, 'test', 'unit', 'nocode_schema_e2e_test.dart'),
    path.join(ROOT_DIR, 'test', 'unit', 'storage_test.dart'),
  ];
  for (const testFile of dartTests) {
    replaceInFile(testFile, /version:\s*'[^']+'/g, `version: '${nextVersion}'`);
    replaceInFile(testFile, /'version':\s*'[^']+'/g, `'version': '${nextVersion}'`);
    replaceInFile(testFile, /\/miniapps\/([^/]+)\/[0-9.]+\/dist/g, `/miniapps/$1/${nextVersion}/dist`);
  }

  log('🔨', 'Đang build lại Mini App SDK...');
  execSync('npm run build', { cwd: SDK_DIR, stdio: 'inherit' });

  // 7. Đồng bộ vào local và user node_modules
  if (fs.existsSync(USER_NODE_MODULES_SDK)) {
    log('📁', `Đồng bộ SDK mới sang ${USER_NODE_MODULES_SDK}...`);
    try {
      execSync(`cp -r dist bin simulator-dist package.json "${USER_NODE_MODULES_SDK}/"`, { cwd: SDK_DIR });
    } catch (e) {
      log('⚠️', `Không thể ghi vào user node_modules: ${e.message}`);
    }
  }

  for (const appId of ['sdk_playground', 'schema_runtime']) {
    const targetSdkDir = path.join(MINI_APPS_DIR, appId, 'node_modules', '@vqh2602', 'mini-app-sdk');
    if (fs.existsSync(targetSdkDir)) {
      execSync(`cp -r dist package.json "${targetSdkDir}/"`, { cwd: SDK_DIR });
    }
    const viteCache = path.join(MINI_APPS_DIR, appId, 'node_modules', '.vite');
    if (fs.existsSync(viteCache)) {
      fs.rmSync(viteCache, { recursive: true, force: true });
    }
  }

  // 8. Đóng gói & Deploy Mini Apps
  log('📦', 'Đóng gói và triển khai Mini Apps với phiên bản mới...');
  execSync('node scripts/build-and-deploy-miniapps.cjs', { cwd: ROOT_DIR, stdio: 'inherit' });

  log('🎉', `Hoàn tất! Phiên bản hiện tại là \x1b[32m\x1b[1mv${nextVersion}\x1b[0m. Sẵn sàng publish lên npm!`);
}

main().catch((err) => {
  console.error('❌ Lỗi khi tự động nâng phiên bản:', err);
  process.exit(1);
});
