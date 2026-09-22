// Splits players into two teams that are as even as possible, with some randomness.
//
// Every possible split is scored by the difference in average rating between the
// teams. One is picked at random among the splits within `tolerance` of perfectly
// even, so the same players don't always end up together (or apart).

// Above this many players, sample random splits instead of trying all of them
const MAX_ENUMERATE = 20
const SAMPLES = 50000

// ratings: number per player. currentTeams: 0/1 per player (optional), to avoid
// repeating the current teams. Returns { teams: 0/1 per player, imbalance, candidates }
export function balanceTeams(ratings, { tolerance = 0.03, currentTeams = null } = {}) {
	const splits = ratings.length <= MAX_ENUMERATE ? allSplits(ratings.length) : sampleSplits(ratings.length)
	const scored = splits.map((teams) => ({ teams, imbalance: imbalance(ratings, teams) }))
	const best = Math.min(...scored.map((s) => s.imbalance))

	let candidates = scored.filter((s) => s.imbalance <= Math.max(tolerance, best))
	if (currentTeams && candidates.length > 1)
		candidates = candidates.filter((s) => !sameSplit(s.teams, currentTeams))

	const pick = candidates[Math.floor(Math.random() * candidates.length)]
	return { ...pick, candidates: candidates.length }
}

// Relative difference between the teams' average ratings (0 = perfectly even)
export function imbalance(ratings, teams) {
	let sum = [ 0, 0 ], size = [ 0, 0 ]
	teams.forEach((team, i) => { sum[team] += ratings[i]; size[team]++ })
	const avg = [ sum[0] / size[0], sum[1] / size[1] ]
	return Math.abs(avg[0] - avg[1]) / ((avg[0] + avg[1]) / 2)
}

// All splits with team sizes differing by at most one. Player 0 is always on
// team 0, so each split is only listed once.
function allSplits(n) {
	const splits = []
	for (let mask = 0; mask < 1 << n; mask += 2) {
		const teams = Array.from({ length: n }, (_, i) => mask >> i & 1)
		const size = teams.reduce((a, b) => a + b, 0)
		if (size === Math.floor(n / 2) || size === Math.ceil(n / 2))
			splits.push(teams)
	}
	return splits
}

function sampleSplits(n) {
	const seen = new Map()
	for (let s = 0; s < SAMPLES; s++) {
		const order = shuffle([...Array(n).keys()])
		const teams = Array(n)
		order.forEach((player, i) => { teams[player] = i < n / 2 ? 0 : 1 })
		if (teams[0] === 1)
			teams.forEach((t, i) => { teams[i] = 1 - t })
		seen.set(teams.join(''), teams)
	}
	return [...seen.values()]
}

function sameSplit(a, b) {
	const same = a.every((t, i) => t === b[i])
	const flipped = a.every((t, i) => t !== b[i])
	return same || flipped
}

function shuffle(array) {
	for (let i = array.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		[ array[i], array[j] ] = [ array[j], array[i] ]
	}
	return array
}
