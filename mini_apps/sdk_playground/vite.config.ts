import { defineConfig, Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';
import path from 'path';

function stripModuleTag(): Plugin {
  return {
    name: 'strip-module-tag',
    enforce: 'post',
    generateBundle(_, bundle) {
      for (const file in bundle) {
        const item = bundle[file];
        if (file.endsWith('.html') && 'source' in item && typeof item.source === 'string') {
          item.source = item.source
            .replace(/<script type="module"[^>]*>/g, '<script>')
            .replace(/<script type="module">/g, '<script>');
        }
      }
    },
  };
}

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react(), viteSingleFile(), stripModuleTag()],
  base: './',
  build: {
    outDir: path.resolve(__dirname, '../../assets/mini_apps/sdk_playground'),
    emptyOutDir: true,
  },
});
