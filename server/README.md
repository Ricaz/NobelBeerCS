# Øl-CS Webserver

Front-end for Øl CS.

Accepts TCP connection from AMX Mod X mod, keeps track of scores, and hosts a website to display them and play sound effects.

## Usage
1. Install dependencies with `npm i`
2. Configure `.env` from `.env-example`.
3. Copy certificates to `tls/cert.pem` and `tls/key.pem` (or link provided self-signed localhost certs)
4. Build using `npm run build`
5. Run using `npm run start` (or execute `src/webapp.js`)
