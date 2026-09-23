// Shared by the live scoreboard and the stats tables

export const SIPS_PER_BEER = 20

// K/D ratio; stats from several games already carry an averaged 'kd'
export function kdRatio(player) {
  if (player.kd !== undefined)
    return Number(player.kd)
  return player.deaths ? player.kills / player.deaths : player.kills
}

export function beers(sips) {
  return (sips / SIPS_PER_BEER).toFixed(1)
}

// Ids of the players with the most beers and the best K/D (ties share it)
export function crowns(players) {
  const best = (value) => {
    const values = players.map(value)
    const max = Math.max(0, ...values)
    return new Set(max > 0 ? players.filter((p, i) => values[i] === max).map((p) => p.id) : [])
  }
  return {
    beers: best((p) => p.sips),
    kd: best((p) => (p.kills ? kdRatio(p) : 0)),
  }
}
