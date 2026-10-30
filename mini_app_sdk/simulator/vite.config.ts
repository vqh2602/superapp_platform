import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5175,
  },
  resolve: {
    alias: {
      '@vqh2602/sdk-transport': path.resolve(__dirname, '../src/transport'),
    },
  },
  build: {
    outDir: path.resolve(__dirname, '../simulator-dist'),
    emptyOutDir: true,
  },
});
