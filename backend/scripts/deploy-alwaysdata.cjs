#!/usr/bin/env node

/**
 * Super App Backend - Automated Deployment to Alwaysdata
 *
 * This script automates:
 * 1. Local NestJS build (`npm run build`)
 * 2. Bundling production artifacts (dist, package.json, package-lock.json)
 * 3. Uploading artifacts to Alwaysdata server via SSH/SCP
 * 4. Installing production dependencies on Alwaysdata
 * 5. Configuring environment variables (.env) on Alwaysdata
 * 6. Restarting the site via Alwaysdata API or process reload
 * 7. Performing health checks on deployed endpoint
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawnSync } = require('child_process');
const readline = require('readline');

// Load environment variables from .env.alwaysdata or .env
function loadEnv() {
  const envFiles = [
    path.resolve(__dirname, '../.env.alwaysdata'),
    path.resolve(__dirname, '../.env'),
  ];
  for (const envFile of envFiles) {
    if (fs.existsSync(envFile)) {
      const content = fs.readFileSync(envFile, 'utf8');
      for (const line of content.split('\n')) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) continue;
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx !== -1) {
          const key = trimmed.slice(0, eqIdx).trim();
          const val = trimmed.slice(eqIdx + 1).trim();
          if (!process.env[key]) {
            process.env[key] = val;
          }
        }
      }
    }
  }
}

loadEnv();

async function prompt(question, defaultVal = '') {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    const query = defaultVal ? `${question} [${defaultVal}]: ` : `${question}: `;
    rl.question(query, (answer) => {
      rl.close();
      resolve(answer.trim() || defaultVal);
    });
  });
}

function runCmd(cmd, options = {}) {
  console.log(`\x1b[36m> ${cmd}\x1b[0m`);
  return execSync(cmd, { stdio: 'inherit', ...options });
}

async function main() {
  console.log('\n\x1b[32m=== Super App Backend - Alwaysdata Deployer ===\x1b[0m\n');

  let account = process.env.ALWAYSDATA_ACCOUNT;
  if (!account) {
    account = await prompt('Enter your Alwaysdata account name (e.g. "myaccount")');
  }
  if (!account) {
    console.error('\x1b[31mError: Alwaysdata account name is required.\x1b[0m');
    process.exit(1);
  }

  const sshHost = process.env.ALWAYSDATA_SSH_HOST || `ssh-${account}.alwaysdata.net`;
  const sshUser = process.env.ALWAYSDATA_SSH_USER || account;
  const remoteDir = process.env.ALWAYSDATA_REMOTE_DIR || 'superapp_backend';
  const apiKey = process.env.ALWAYSDATA_API_KEY || '';
  const siteId = process.env.ALWAYSDATA_SITE_ID || '';

  const dbHost = process.env.DB_HOST || `postgresql-${account}.alwaysdata.net`;
  const dbPort = process.env.DB_PORT || '5432';
  const dbUser = process.env.DB_USERNAME || account;
  const dbPassword = process.env.DB_PASSWORD || '';
  const dbName = process.env.DB_DATABASE || `${account}_registry`;
  const appPort = process.env.PORT || '8100';

  console.log(`\nDeployment Target:`);
  console.log(` - Account:     ${account}`);
  console.log(` - SSH Host:    ${sshUser}@${sshHost}`);
  console.log(` - Remote Dir:  /home/${sshUser}/${remoteDir}`);
  console.log(` - DB Host:     ${dbHost}:${dbPort}`);
  console.log(` - Database:    ${dbName}`);
  console.log(` - App Port:    ${appPort}`);
  console.log('');

  const backendDir = path.resolve(__dirname, '..');

  // Step 1: Build local backend
  console.log('\x1b[33m[1/6] Building backend application (npm run build)...\x1b[0m');
  runCmd('npm run build', { cwd: backendDir });

  // Step 2: Create release archive
  console.log('\n\x1b[33m[2/6] Packaging deployment bundle...\x1b[0m');
  const tempTar = path.resolve(backendDir, 'release.tar.gz');
  if (fs.existsSync(tempTar)) fs.unlinkSync(tempTar);

  runCmd(`tar -czf release.tar.gz dist package.json package-lock.json storage`, { cwd: backendDir });

  // Step 3: Upload bundle to Alwaysdata
  console.log('\n\x1b[33m[3/6] Uploading release bundle to Alwaysdata via SCP...\x1b[0m');
  try {
    runCmd(`ssh -o StrictHostKeyChecking=accept-new ${sshUser}@${sshHost} "mkdir -p ${remoteDir}/storage/miniapps"`);
    runCmd(`scp release.tar.gz ${sshUser}@${sshHost}:${remoteDir}/release.tar.gz`, { cwd: backendDir });
  } catch (err) {
    console.error('\x1b[31mFailed to connect or upload via SSH/SCP. Please verify SSH access in Alwaysdata Admin > Remote access > SSH.\x1b[0m');
    if (fs.existsSync(tempTar)) fs.unlinkSync(tempTar);
    throw err;
  } finally {
    if (fs.existsSync(tempTar)) fs.unlinkSync(tempTar);
  }

  // Step 4: Extract and configure remote environment
  console.log('\n\x1b[33m[4/6] Setting up application on Alwaysdata server...\x1b[0m');
  const envContent = [
    `DB_HOST=${dbHost}`,
    `DB_PORT=${dbPort}`,
    `DB_USERNAME=${dbUser}`,
    `DB_PASSWORD=${dbPassword}`,
    `DB_DATABASE=${dbName}`,
    `DB_SSL=${process.env.DB_SSL || 'false'}`,
    `DB_SYNCHRONIZE=true`,
    `MINIAPP_STORAGE_DIR=/home/${sshUser}/${remoteDir}/storage/miniapps`,
  ].join('\n');

  const localEnvFile = path.resolve(backendDir, '.env.deploy-temp');
  fs.writeFileSync(localEnvFile, envContent + '\n', 'utf8');

  try {
    runCmd(`scp ${localEnvFile} ${sshUser}@${sshHost}:${remoteDir}/.env`);
  } finally {
    if (fs.existsSync(localEnvFile)) fs.unlinkSync(localEnvFile);
  }

  const remoteCommands = [
    `cd ${remoteDir}`,
    `tar -xzf release.tar.gz`,
    `rm release.tar.gz`,
    `chmod 600 .env`,
    `npm install --omit=dev`,
    `mkdir -p storage/miniapps`,
  ].join(' && ');

  runCmd(`ssh ${sshUser}@${sshHost} "${remoteCommands}"`);

  // Step 5: Restart the site
  console.log('\n\x1b[33m[5/6] Restarting service...\x1b[0m');
  let restarted = false;

  if (apiKey && siteId) {
    console.log(`Triggering Alwaysdata API restart for site ${siteId}...`);
    try {
      const authHeader = 'Basic ' + Buffer.from(`${apiKey} account=${account}:`).toString('base64');
      const res = await fetch(`https://api.alwaysdata.com/v1/site/${siteId}/restart/`, {
        method: 'POST',
        headers: {
          Authorization: authHeader,
          'Content-Type': 'application/json',
        },
      });
      if (res.ok || res.status === 204) {
        console.log('\x1b[32mAlwaysdata site restart triggered successfully via API!\x1b[0m');
        restarted = true;
      } else {
        const text = await res.text();
        console.warn(`Alwaysdata API restart returned status ${res.status}: ${text}`);
      }
    } catch (apiErr) {
      console.warn(`Could not trigger API restart: ${apiErr.message}`);
    }
  }

  if (!restarted) {
    // Touch restart file / signal process restart
    console.log('Sending restart signal via SSH...');
    try {
      runCmd(`ssh ${sshUser}@${sshHost} "mkdir -p ${remoteDir}/tmp && touch ${remoteDir}/tmp/restart.txt"`);
      // Also try killing existing node dist/main process if running under supervisor
      runCmd(`ssh ${sshUser}@${sshHost} "pkill -f 'dist/main' || true"`);
      console.log('Restart signal sent.');
    } catch (e) {
      console.warn('SSH restart command warning:', e.message);
    }
  }

  // Step 6: Health check
  console.log('\n\x1b[33m[6/6] Verifying deployment health...\x1b[0m');
  const siteUrl = process.env.ALWAYSDATA_SITE_URL || `https://${account}.alwaysdata.net`;
  console.log(`Testing endpoint: ${siteUrl}/api/v1/catalog/apps`);

  let verified = false;
  for (let attempt = 1; attempt <= 6; attempt++) {
    process.stdout.write(`Attempt ${attempt}/6: waiting for service... `);
    await new Promise((r) => setTimeout(r, 4000));
    try {
      const checkRes = await fetch(`${siteUrl}/api/v1/catalog/apps`);
      if (checkRes.ok) {
        const data = await checkRes.json();
        console.log(`\x1b[32mSUCCESS (status ${checkRes.status})!\x1b[0m`);
        console.log(`\x1b[32mCatalog API is live with ${data.items ? data.items.length : 0} Mini Apps!\x1b[0m`);
        verified = true;
        break;
      } else {
        console.log(`HTTP ${checkRes.status}`);
      }
    } catch (err) {
      console.log(`connecting... (${err.message})`);
    }
  }

  if (!verified) {
    console.log(`\x1b[33mNote: Site may take a little longer to spin up. Please check ${siteUrl}/api/v1/catalog/apps manually.\x1b[0m`);
  }

  console.log('\n\x1b[32m=======================================================');
  console.log(' Deployment Process Completed!');
  console.log(' Alwaysdata Admin: https://admin.alwaysdata.com');
  console.log('=======================================================\x1b[0m\n');
}

main().catch((err) => {
  console.error('\n\x1b[31mDeployment failed:\x1b[0m', err.message);
  process.exit(1);
});
