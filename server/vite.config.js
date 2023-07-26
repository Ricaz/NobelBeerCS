import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig(({ mode }) => {
  process.env = {...process.env, ...loadEnv(mode, process.cwd())};

  if (mode === 'development') {
    return {
      build: {
        emptyOutDir: false,
        outDir: process.env.VITE_BUILD_DIR,
        copyPublicDir: false
      },
      plugins: [ vue() ],
    }
  } else {
    return {
      build: {
        emptyOutDir: false,
        outDir: process.env.VITE_BUILD_DIR
      },
      plugins: [ vue() ],
    }
  }
})
