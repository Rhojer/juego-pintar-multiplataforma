# 🎨 Rayando — Server

Real-time multiplayer drawing & guessing game with a Venezuelan twist.
Built with **Node.js**, **Express**, and **Socket.io**.

---

## Project Structure

```
server/
├── index.js                  # Entry point — Express + Socket.io bootstrap
├── package.json
├── .env.example
├── game/
│   ├── GameManager.js        # Singleton — owns all active rooms
│   ├── GameRoom.js           # Room state, turn logic, scoring, timers
│   └── words.js              # Venezuelan word bank (8 categories, 130+ words)
└── socket/
    └── handlers.js           # All Socket.io event handlers
```

---

## Quick Start (Local)

```bash
# 1. Install dependencies
npm install

# 2. (Optional) Copy and edit environment variables
cp .env.example .env

# 3. Start in development mode (auto-restart on save)
npm run dev

# 4. Start in production mode
npm start
```

The server listens on **http://localhost:3000** by default.

Health check: `GET /` returns server status + active rooms JSON.

---

## Environment Variables

| Variable   | Default        | Description                          |
|------------|----------------|--------------------------------------|
| `PORT`     | `3000`         | TCP port the server binds to         |
| `NODE_ENV` | `development`  | Set to `production` on VPS           |

---

## VPS Deployment (Ubuntu / Debian)

### 1 — Prerequisites

```bash
# Install Node.js 20.x LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 (process manager)
sudo npm install -g pm2
```

### 2 — Upload & Install

```bash
# Clone or upload your project, then:
cd /var/www/pinturillo-vzla/server
npm install --omit=dev
```

### 3 — Environment File

```bash
cp .env.example .env
nano .env          # set PORT and NODE_ENV=production
```

### 4 — Start with PM2

```bash
# Start the app
pm2 start index.js --name pinturillo

# Save the process list so it survives reboots
pm2 save

# Enable PM2 startup script
pm2 startup          # follow the printed command
```

Useful PM2 commands:

```bash
pm2 status           # list running apps
pm2 logs pinturillo  # stream logs
pm2 restart pinturillo
pm2 stop pinturillo
pm2 delete pinturillo
```

### 5 — Nginx Reverse Proxy

Install Nginx:

```bash
sudo apt install nginx
```

Create `/etc/nginx/sites-available/pinturillo`:

```nginx
server {
    listen 80;
    server_name your-domain.com;   # replace with your domain or IP

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;

        # Required for WebSocket upgrade
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection "upgrade";

        proxy_set_header   Host             $host;
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        # Increase timeouts for long-lived WS connections
        proxy_read_timeout  86400s;
        proxy_send_timeout  86400s;
    }
}
```

Enable and reload:

```bash
sudo ln -s /etc/nginx/sites-available/pinturillo /etc/nginx/sites-enabled/
sudo nginx -t          # verify config
sudo systemctl reload nginx
```

### 6 — HTTPS with Let's Encrypt (Certbot)

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

Certbot auto-renews certificates and patches your Nginx config for TLS.

---

## Socket.io Event Reference

### Client → Server

| Event           | Payload                            | Description                          |
|-----------------|------------------------------------|--------------------------------------|
| `join-public`   | `{ nickname }`                     | Join or create a public room         |
| `create-private`| `{ nickname }`                     | Create a new private room            |
| `join-private`  | `{ nickname, roomCode }`           | Join an existing private room        |
| `player-ready`  | `{}`                               | Mark yourself ready to start         |
| `drawing-data`  | `{ strokes }`                      | Send canvas stroke data (drawer only)|
| `clear-canvas`  | `{}`                               | Clear the board for all (drawer only)|
| `guess`         | `{ text }`                         | Submit a guess during gameplay       |
| `chat-message`  | `{ text }`                         | Lobby chat (disabled during gameplay)|

### Server → Client

| Event                | Description                                          |
|----------------------|------------------------------------------------------|
| `room-joined`        | Confirms join; sends full room state + your player   |
| `join-error`         | Join failed; `{ message }` explains why              |
| `player-joined`      | Another player joined; updated player list           |
| `player-left`        | A player disconnected; updated player list           |
| `player-ready-update`| Someone toggled ready; updated player list           |
| `turn-started`       | New turn begins; word hint + drawer info             |
| `your-word`          | **Drawer only** — the actual word to draw            |
| `hint-update`        | A new letter in the hint revealed                    |
| `correct-guess`      | Someone guessed correctly; updated scores            |
| `chat-message`       | Chat / guess / system message                        |
| `turn-ended`         | Turn over; reveals word + updated scores             |
| `game-over`          | Game finished; final leaderboard                     |
| `room-reset`         | Room returned to waiting state after game            |
| `canvas-cleared`     | Drawer cleared the board                             |
| `drawing-data`       | Canvas strokes relayed from drawer                   |

---

## Scoring

| Action                         | Points                              |
|--------------------------------|-------------------------------------|
| Correct guess (fast)           | Up to **300 pts** (scales with time)|
| Correct guess (slow / last sec)| Minimum **50 pts**                  |
| Drawer (per correct guesser)   | **+50 pts** per player who guesses  |

---

## License

MIT — built for the comunidad venezolana 🇻🇪
