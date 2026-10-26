import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: path.resolve(__dirname, '../../assets/mini_apps/schema_runtime'),
    emptyOutDir: true,
    assetsDir: 'assets',
  },
});
