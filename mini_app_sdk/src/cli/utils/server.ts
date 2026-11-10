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

/**
 * Validates whether the incoming Origin header is a trusted local development origin.
 * Prevents arbitrary external websites from reading simulator assets via cross-origin requests.
 */
export function isAllowedCorsOrigin(origin: string): boolean {
  if (!origin || typeof origin !== 'string') return false;
  try {
    const url = new URL(origin);
    return (
      url.hostname === 'localhost' ||
      url.hostname === '127.0.0.1' ||
      url.hostname === '[::1]' ||
      url.hostname.endsWith('.localhost')
    );
  } catch (_) {
    return false;
  }
}

/**
 * Validates whether a target Mini App URL is safe to be embedded in the Simulator iframe.
 * Allows local development URLs (http://localhost, http://127.0.0.1) and HTTPS web apps.
 * Strictly blocks dangerous schemes (javascript:, data:, file:, blob:) and embedded credentials.
 */
export function isAllowedMiniAppUrl(rawUrl: string): boolean {
  if (!rawUrl || typeof rawUrl !== 'string') return false;
  try {
    const parsed = new URL(rawUrl.trim());
    // 1. Strictly block dangerous schemes
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return false;
    }
    // 2. Reject credentials embedded in URL
    if (parsed.username || parsed.password) {
      return false;
    }
    // 3. For http, only allow local loopback origins
    if (parsed.protocol === 'http:') {
      return (
        parsed.hostname === 'localhost' ||
        parsed.hostname === '127.0.0.1' ||
        parsed.hostname === '[::1]' ||
        parsed.hostname.endsWith('.localhost')
      );
    }
    // 4. For https, allow valid remote web hosts
    return parsed.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

/**
 * Starts the Browser Simulator HTTP server strictly bound to localhost (127.0.0.1) by default.
 */
export function startSimulatorServer(port: number = 5175, host: string = '127.0.0.1'): http.Server {
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
    // 1. Restricted CORS policy: only allow trusted local origins, never wildcard '*'
    const reqOrigin = req.headers.origin;
    if (reqOrigin && isAllowedCorsOrigin(reqOrigin)) {
      res.setHeader('Access-Control-Allow-Origin', reqOrigin);
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-tenant-id');
      res.setHeader('Vary', 'Origin');
    }

    // 2. Security Headers
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'SAMEORIGIN');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    const parsedUrl = new URL(req.url || '/', `http://${host}:${port}`);
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

  server.on('error', (err: any) => {
    if (err.code === 'EADDRINUSE') {
      logger.error(`Port ${port} đang được sử dụng bởi một tiến trình khác. Thử lại với tuỳ chọn --port <port khác>.`);
      process.exit(1);
    } else {
      logger.error(`Lỗi server: ${err.message}`);
      process.exit(1);
    }
  });

  // Explicitly bind to host (127.0.0.1 loopback only by default)
  server.listen(port, host, () => {
    logger.success(`Browser Simulator đang chạy an toàn tại: http://${host}:${port}`);
    logger.info(`Trải nghiệm giả lập Mini App tại: http://${host}:${port}/?url=http://localhost:3000`);
  });

  return server;
}
