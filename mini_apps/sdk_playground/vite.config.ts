import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: path.resolve(__dirname, '../../assets/mini_apps/sdk_playground'),
    emptyOutDir: true,
    assetsDir: 'assets',
  },
});
