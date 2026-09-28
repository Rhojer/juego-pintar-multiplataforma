/**
 * index.js
 * Entry point for the Rayando multiplayer game server.
 *
 * Stack: Express + Socket.io
 * Architecture:
 *   - Express serves a simple health-check route
 *   - Socket.io handles all real-time game events via ./socket/handlers.js
 *   - In-memory state is managed by ./game/GameManager.js (no DB required)
 */

require('dotenv').config(); // load .env if present (optional in production)

const express          = require('express');
const http             = require('http');
const { Server }       = require('socket.io');
const cors             = require('cors');
const { registerHandlers } = require('./socket/handlers');
const gameManager      = require('./game/GameManager');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
const PORT    = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// ---------------------------------------------------------------------------
// Express app
// ---------------------------------------------------------------------------
const app = express();

// Allow any origin — required for mobile clients and hosted frontends
app.use(cors({ origin: '*' }));
app.use(express.json());

// Health-check / status endpoint
app.get('/', (req, res) => {
  res.json({
    status:  'ok',
    game:    'Rayando',
    version: '1.0.0',
    env:     NODE_ENV,
    uptime:  Math.floor(process.uptime()),
    rooms:   gameManager.getRoomSummaries(),
  });
});

// Admin: list all rooms (protect with a secret header in production)
app.get('/admin/rooms', (req, res) => {
  res.json({ rooms: gameManager.getRoomSummaries() });
});

// ---------------------------------------------------------------------------
// HTTP server + Socket.io
// ---------------------------------------------------------------------------
const httpServer = http.createServer(app);

// Optimize keep-alive timeouts for high-throughput load balancers (Nginx / ALB)
httpServer.keepAliveTimeout = 65000;
httpServer.headersTimeout = 66000;

const io = new Server(httpServer, {
  cors: {
    origin:  '*',
    methods: ['GET', 'POST'],
  },
  // Scale optimizations:
  // Disabling perMessageDeflate saves huge CPU cycles at high concurrency
  perMessageDeflate: false,
  // Limit max packet size to 1MB to prevent memory exhaustion DoS
  maxHttpBufferSize: 1e6,
  // Tune transports: prefer WebSocket, fall back to polling for restrictive networks
  transports: ['websocket', 'polling'],
  // Ping settings to detect dead connections quickly and reclaim resources
  pingTimeout:  20000,
  pingInterval: 10000,
});

// Optional Redis Adapter for multi-node / multi-core horizontal clustering
if (process.env.REDIS_URL || process.env.REDIS_HOST) {
  try {
    const { createAdapter } = require('@socket.io/redis-adapter');
    const { createClient } = require('redis');
    const redisUrl = process.env.REDIS_URL || `redis://${process.env.REDIS_HOST}:${process.env.REDIS_PORT || 6379}`;
    const pubClient = createClient({ url: redisUrl });
    const subClient = pubClient.duplicate();

    Promise.all([pubClient.connect(), subClient.connect()]).then(() => {
      io.adapter(createAdapter(pubClient, subClient));
      console.log('[Server] 🚀 Socket.io Redis adapter active for horizontal multi-core/multi-server scaling!');
    }).catch((err) => {
      console.warn('[Server] Redis connection failed, falling back to in-memory mode:', err.message);
    });
  } catch (err) {
    console.log('[Server] Redis adapter packages not installed, running in high-performance in-memory mode.');
  }
}

// ---------------------------------------------------------------------------
// Register all game event handlers
// ---------------------------------------------------------------------------
registerHandlers(io);

// ---------------------------------------------------------------------------
// Global connection / disconnection logging (fine-grained logs live in handlers.js)
// ---------------------------------------------------------------------------
io.on('connection', (socket) => {
  const totalConnected = io.engine.clientsCount;
  console.log(`[${new Date().toISOString()}] ✅ Player connected    | id: ${socket.id} | total: ${totalConnected}`);

  socket.on('disconnect', () => {
    const remaining = io.engine.clientsCount;
    console.log(`[${new Date().toISOString()}] ❌ Player disconnected | id: ${socket.id} | total: ${remaining}`);
  });
});

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------
httpServer.listen(PORT, () => {
  console.log('');
  console.log('╔════════════════════════════════════════╗');
  console.log('║   🎨 Rayando — Server Ready            ║');
  console.log(`║   Port : ${String(PORT).padEnd(30)}║`);
  console.log(`║   Env  : ${String(NODE_ENV).padEnd(30)}║`);
  console.log('╚════════════════════════════════════════╝');
  console.log('');
});

// ---------------------------------------------------------------------------
// Graceful shutdown — clear all room timers on process exit
// ---------------------------------------------------------------------------
function gracefulShutdown(signal) {
  console.log(`\n[Server] Received ${signal}. Shutting down gracefully...`);

  // Close the HTTP/WS server (stops new connections)
  httpServer.close(() => {
    console.log('[Server] HTTP server closed.');
    process.exit(0);
  });

  // Force exit after 5 s if connections linger
  setTimeout(() => {
    console.error('[Server] Forced exit after timeout.');
    process.exit(1);
  }, 5000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT',  () => gracefulShutdown('SIGINT'));

// Catch unhandled promise rejections so the server doesn't crash silently
process.on('unhandledRejection', (reason) => {
  console.error('[Server] Unhandled Promise Rejection:', reason);
});

process.on('uncaughtException', (err) => {
  console.error('[Server] Uncaught Exception:', err);
  // In production, let PM2 restart the process
  process.exit(1);
});
