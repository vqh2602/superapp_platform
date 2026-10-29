import { spawn } from 'node:child_process';
import { loadManifest } from '../utils/config.js';
import { logger } from '../utils/logger.js';
import { startSimulatorServer } from '../utils/server.js';

export interface DevCommandOptions {
  port?: string;
  simulatorPort?: string;
  open?: boolean;
  noSimulator?: boolean;
}

export async function devServer(options: DevCommandOptions = {}): Promise<void> {
  const manifest = loadManifest();
  const port = options.port || '3000';
  const simulatorPort = options.simulatorPort || '5175';

  logger.title(`Khởi chạy Mini App Development Server`);
  logger.info(`Đang chạy ứng dụng: ${manifest.name} (${manifest.appId})`);

  let simServer: any = null;
  if (!options.noSimulator) {
    try {
      simServer = startSimulatorServer(parseInt(simulatorPort, 10));
    } catch (e) {
      logger.warn(`Không thể khởi chạy Simulator trên cổng ${simulatorPort}`);
    }
  }

  logger.info(`Vite Server: http://localhost:${port}`);
  logger.info(`Browser Simulator: http://localhost:${simulatorPort}/?url=http://localhost:${port}`);

  const child = spawn('npx', ['vite', '--port', port], {
    stdio: 'inherit',
    shell: true,
  });

  child.on('error', (err) => {
    logger.error('Lỗi khởi động Vite Dev Server:', err);
  });

  process.on('SIGINT', () => {
    logger.info('Đang dừng Development Server & Simulator...');
    if (simServer) {
      try {
        simServer.close();
      } catch (_) {}
    }
    child.kill('SIGINT');
    process.exit(0);
  });
}
