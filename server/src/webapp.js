import { createApp } from 'vue'
import 'bootstrap/dist/css/bootstrap.css'
import App from './components/App.vue'
import Scoreboard from './components/Scoreboard.vue'
import ScoreboardRow from './components/ScoreboardRow.vue'

const app = createApp(App)
	.component('Scoreboard', Scoreboard)
	.component('ScoreboardRow', ScoreboardRow)
	.mount('#app')

import 'bootstrap/dist/js/bootstrap.js'
