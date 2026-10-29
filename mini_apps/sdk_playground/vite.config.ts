import { defineConfig, Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';
import path from 'path';

function removeModuleAttrs(): Plugin {
  return {
    name: 'remove-module-attrs',
    transformIndexHtml: {
      order: 'post',
      handler(html: string) {
        return html
          .replace(/<script type="module" crossorigin>/g, '<script>')
          .replace(/<script type="module">/g, '<script>');
      },
    },
  };
}

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react(), viteSingleFile(), removeModuleAttrs()],
  base: './',
  build: {
    outDir: path.resolve(__dirname, 'dist'),
    emptyOutDir: true,
  },
});
