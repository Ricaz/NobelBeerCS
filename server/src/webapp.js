import { createApp } from 'vue'
import 'bootstrap/dist/css/bootstrap.css'
import App from './components/App.vue'
import Scoreboard from './components/Scoreboard.vue'
import ScoreboardRow from './components/ScoreboardRow.vue'
import Overlay from './components/Overlay.vue'
import Highlights from './components/Highlights.vue'
import KillFeed from './components/KillFeed.vue'
import AwardsBar from './components/AwardsBar.vue'
import LiveBanner from './components/LiveBanner.vue'

const app = createApp(App)
	.component('Scoreboard', Scoreboard)
	.component('ScoreboardRow', ScoreboardRow)
	.component('Overlay', Overlay)
	.component('Highlights', Highlights)
	.component('KillFeed', KillFeed)
	.component('AwardsBar', AwardsBar)
	.component('LiveBanner', LiveBanner)
	.mount('#app')

import 'bootstrap/dist/js/bootstrap.js'
