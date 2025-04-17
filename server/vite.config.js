import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

export default defineConfig(({ mode }) => {
  process.env = {...process.env, ...loadEnv(mode, process.cwd())};

  if (mode === 'development') {
    return {
      build: {
        emptyOutDir: true,
        terserOptions: { compress: false, mangle: false },
        minify: false,
        outDir: process.env.VITE_BUILD_DIR,
        copyPublicDir: true
      },
      plugins: [ vue(), vueDevTools() ],
    }
  } else {
    return {
      build: {
        emptyOutDir: true,
        outDir: process.env.VITE_BUILD_DIR
      },
      plugins: [ vue() ],
    }
  }
})
