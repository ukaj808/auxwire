import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path';
import tailwindcss from '@tailwindcss/vite';

// https://vite.dev/config/
console.log(resolve(__dirname, '../tls/localhost-key+1.pem'));
export default defineConfig({
  plugins: [vue(), tailwindcss()],
  base: '/vite-proxy',
  server: {
    //    origin: 'https://localhost:8443',
    https: {
      key: resolve(__dirname, '../tls/localhost-key.pem'),
      cert: resolve(__dirname, '../tls/localhost.pem'),
    },
    /*
    hmr: {
      protocol: 'wss',
      path: '/hmr',
    },
  */
  },
  build: {
    manifest: true,
    rollupOptions: {
      input: {
        home: resolve(__dirname, 'src/pages/home/main.ts'),
        room: resolve(__dirname, 'src/pages/room/main.ts'),
        'audio-socket-worker': resolve(__dirname, 'src/scripts/aux-audio-socket-worker.ts'),
        'worklet-processor': resolve(__dirname, 'src/scripts/aux-worklet-processor.ts'),
      },
    },
  },
})
