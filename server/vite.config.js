import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig(({ mode }) => {
  if (mode === 'development') {
    return {
      build: {
        emptyOutDir: false,
        copyPublicDir: false
      },
      plugins: [ vue() ],
    }
  } else {
    return {
      plugins: [ vue() ],
    }
  }
})
