import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { logger } from './logger.js';

const MIME_TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
};

export function startSimulatorServer(port: number = 5175): http.Server {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);

  // Search candidate directories for simulator web bundle
  const candidates = [
    path.resolve(__dirname, '../../../simulator-dist'),
    path.resolve(__dirname, '../../simulator-dist'),
    path.resolve(__dirname, '../simulator-dist'),
    path.resolve(__dirname, '../../../dist/simulator'),
    path.resolve(__dirname, '../../dist/simulator'),
  ];

  let distDir = candidates.find((dir) => fs.existsSync(dir) && fs.existsSync(path.join(dir, 'index.html')));

  if (!distDir) {
    distDir = candidates[0];
  }

  const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    const parsedUrl = new URL(req.url || '/', `http://localhost:${port}`);
    let pathname = parsedUrl.pathname;
    let filePath = path.join(distDir!, pathname);

    if (!filePath.startsWith(distDir!)) {
      res.writeHead(403);
      res.end('Forbidden');
      return;
    }

    fs.stat(filePath, (err, stats) => {
      if (err || !stats.isFile()) {
        filePath = path.join(distDir!, 'index.html');
      }

      const ext = path.extname(filePath).toLowerCase();
      const contentType = MIME_TYPES[ext] || 'application/octet-stream';

      fs.readFile(filePath, (readErr, data) => {
        if (readErr) {
          res.writeHead(404);
          res.end('Not Found');
          return;
        }
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(data);
      });
    });
  });

  server.listen(port, () => {
    logger.success(`Browser Simulator đang chạy tại: http://localhost:${port}`);
    logger.info(`Trải nghiệm giả lập Mini App tại: http://localhost:${port}/?url=http://localhost:3000`);
  });

  return server;
}
