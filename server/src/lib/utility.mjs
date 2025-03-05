function tcp(msg) {
  console.log('[TCP]   ' + msg)
}

function ws(msg) {
  console.log('[WS]    ' + msg)
}

function http(msg) {
  console.log('[HTTP]  ' + msg)
}

function score(msg) {
  console.log('[SCORE] ' + msg)
}

export { tcp, ws, http, score }
