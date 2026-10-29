import { startSimulatorServer } from '../utils/server.js';
import { logger } from '../utils/logger.js';

export interface SimulatorCommandOptions {
  port?: string;
  appUrl?: string;
}

export async function runSimulator(options: SimulatorCommandOptions = {}): Promise<void> {
  const port = parseInt(options.port || '5175', 10);
  const appUrl = options.appUrl || 'http://localhost:3000';

  logger.title(`Khởi chạy SuperApp Browser Simulator & DevTools`);
  startSimulatorServer(port);

  logger.info(`Để kết nối với Mini App, mở: http://localhost:${port}/?url=${encodeURIComponent(appUrl)}`);

  process.on('SIGINT', () => {
    logger.info('Đang dừng Browser Simulator...');
    process.exit(0);
  });
}
