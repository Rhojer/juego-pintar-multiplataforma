/**
 * handlers.js
 * Registers all Socket.io event handlers for the Rayando game.
 *
 * Every socket keeps track of which room it belongs to via socket.roomCode
 * so we can look up the GameRoom on any event without needing the client
 * to send the code repeatedly.
 */

const gameManager = require('../game/GameManager');

/**
 * Attaches all game-related socket event handlers to the given io instance.
 * @param {import('socket.io').Server} io
 */
function registerHandlers(io) {
  io.on('connection', (socket) => {
    console.log(`[Socket] Connected: ${socket.id}`);

    // ------------------------------------------------------------------
    // Helper: look up the room this socket belongs to
    // ------------------------------------------------------------------
    function getMyRoom() {
      if (!socket.roomCode) return null;
      return gameManager.getRoom(socket.roomCode);
    }

    // ------------------------------------------------------------------
    // Helper: safely parse a nickname from client data
    // ------------------------------------------------------------------
    function sanitizeNickname(raw) {
      if (typeof raw !== 'string' || !raw.trim()) return `Jugador_${socket.id.slice(0, 4)}`;
      return raw.trim().substring(0, 20);
    }

    // ==================================================================
    // JOIN PUBLIC ROOM
    // Payload: { nickname: string }
    // ==================================================================
    socket.on('join-public', ({ nickname } = {}) => {
      try {
        const nick = sanitizeNickname(nickname);
        const room = gameManager.getOrCreatePublicRoom();

        const player = room.addPlayer(socket.id, nick);
        if (!player) {
          socket.emit('join-error', { message: 'No se pudo unir: sala llena o en juego.' });
          return;
        }

        socket.roomCode = room.code;
        socket.join(room.code);

        const publicRoom = room.getPublicState();

        // Confirm to joining socket
        socket.emit('room-joined', {
          roomCode:    room.code,
          isPrivate:   room.isPrivate,
          nickname:    player.nickname,
          player,
          players:     publicRoom.players,
          totalRounds: publicRoom.totalRounds,
          room:        publicRoom,
        });

        // Notify everyone else in the room
        socket.to(room.code).emit('player-joined', {
          player,
          players: room.getPublicState().players,
        });

        console.log(`[Room ${room.code}] ${nick} joined (${room.players.size} players).`);
      } catch (err) {
        console.error('[join-public] Error:', err);
        socket.emit('join-error', { message: 'Error interno al unirse.' });
      }
    });

    // ==================================================================
    // CREATE PRIVATE ROOM
    // Payload: { nickname: string }
    // ==================================================================
    socket.on('create-private', ({ nickname } = {}) => {
      try {
        const nick = sanitizeNickname(nickname);
        const room = gameManager.createRoom(true);

        const player = room.addPlayer(socket.id, nick);
        if (!player) {
          // Should never happen for a brand-new room, but guard anyway
          socket.emit('join-error', { message: 'No se pudo crear la sala.' });
          return;
        }

        socket.roomCode = room.code;
        socket.join(room.code);

        const publicRoom = room.getPublicState();

        socket.emit('room-joined', {
          roomCode:    room.code,
          isPrivate:   true,
          nickname:    player.nickname,
          player,
          players:     publicRoom.players,
          totalRounds: publicRoom.totalRounds,
          room:        publicRoom,
        });

        console.log(`[Room ${room.code}] Private room created by ${nick}.`);
      } catch (err) {
        console.error('[create-private] Error:', err);
        socket.emit('join-error', { message: 'Error interno al crear la sala.' });
      }
    });

    // ==================================================================
    // JOIN PRIVATE ROOM
    // Payload: { nickname: string, roomCode: string }
    // ==================================================================
    socket.on('join-private', ({ nickname, roomCode } = {}) => {
      try {
        if (!roomCode || typeof roomCode !== 'string') {
          socket.emit('join-error', { message: 'Código de sala inválido.' });
          return;
        }

        const code = roomCode.trim().toUpperCase();
        const room = gameManager.getRoom(code);

        if (!room) {
          socket.emit('join-error', { message: `Sala "${code}" no encontrada.` });
          return;
        }

        if (!room.hasSpace()) {
          socket.emit('join-error', { message: 'La sala está llena o ya está en juego.' });
          return;
        }

        const nick   = sanitizeNickname(nickname);
        const player = room.addPlayer(socket.id, nick);

        if (!player) {
          socket.emit('join-error', { message: 'No se pudo unir a la sala.' });
          return;
        }

        socket.roomCode = room.code;
        socket.join(room.code);

        const publicRoom = room.getPublicState();

        socket.emit('room-joined', {
          roomCode:    room.code,
          isPrivate:   true,
          nickname:    player.nickname,
          player,
          players:     publicRoom.players,
          totalRounds: publicRoom.totalRounds,
          room:        publicRoom,
        });

        socket.to(room.code).emit('player-joined', {
          player,
          players: room.getPublicState().players,
        });

        console.log(`[Room ${room.code}] ${nick} joined private room (${room.players.size} players).`);
      } catch (err) {
        console.error('[join-private] Error:', err);
        socket.emit('join-error', { message: 'Error interno al unirse.' });
      }
    });

    // ==================================================================
    // PLAYER READY (supports toggle and both event names)
    // ==================================================================
    function handleReadyToggle() {
      try {
        const room = getMyRoom();
        if (!room || room.status !== 'waiting') return;

        const player = room.players.get(socket.id);
        if (!player) return;

        // Toggle ready status
        player.isReady = !player.isReady;

        const publicRoom = room.getPublicState();
        const payload = {
          playerId: socket.id,
          isReady:  player.isReady,
          players:  publicRoom.players,
        };

        // Broadcast with both event names for maximum client compatibility
        io.to(room.code).emit('player-ready', payload);
        io.to(room.code).emit('player-ready-update', payload);

        console.log(`[Room ${room.code}] ${player.nickname} ready: ${player.isReady}`);

        // Check if ALL players are ready (minimum 2 players)
        const allPlayers = [...room.players.values()];
        const allReady   = allPlayers.length >= 2 && allPlayers.every((p) => p.isReady);

        if (allReady) {
          console.log(`[Room ${room.code}] All players ready (${allPlayers.length}) — starting game.`);
          room.startGame(io);
        }
      } catch (err) {
        console.error('[player-ready] Error:', err);
      }
    }

    socket.on('player-ready', handleReadyToggle);
    socket.on('set-ready', handleReadyToggle);

    // ==================================================================
    // DRAWING DATA (stroke chunks from canvas)
    // Payload: { strokes: any }   (format defined by client — passed through)
    // ==================================================================
    socket.on('drawing-data', ({ strokes } = {}) => {
      try {
        const room = getMyRoom();
        if (!room || room.status !== 'playing') return;
        if (room.currentDrawerId !== socket.id) return; // only the drawer may send strokes

        // Relay to everyone else in the room (not back to sender)
        socket.to(room.code).emit('drawing-data', { strokes });
      } catch (err) {
        console.error('[drawing-data] Error:', err);
      }
    });

    // ==================================================================
    // CLEAR CANVAS
    // Payload: {} — drawer wants to clear the board for everyone
    // ==================================================================
    socket.on('clear-canvas', () => {
      try {
        const room = getMyRoom();
        if (!room || room.status !== 'playing') return;
        if (room.currentDrawerId !== socket.id) return;

        socket.to(room.code).emit('canvas-cleared');
      } catch (err) {
        console.error('[clear-canvas] Error:', err);
      }
    });

    // ==================================================================
    // GUESS
    // Payload: { text: string }
    // ==================================================================
    socket.on('guess', ({ text } = {}) => {
      try {
        const room = getMyRoom();
        if (!room || room.status !== 'playing') return;

        const player = room.players.get(socket.id);
        if (!player) return;

        if (typeof text !== 'string' || !text.trim()) return;
        const guessText = text.trim().substring(0, 100);

        const result = room.handleGuess(socket.id, guessText);

        if (result.alreadyGuessed) {
          // Silently drop — player already guessed correctly
          return;
        }

        if (result.correct) {
          // Broadcast correct-guess notification (hides the actual word from chat)
          io.to(room.code).emit('correct-guess', {
            socketId: socket.id,
            nickname: player.nickname,
            points:   result.points,
            players:  room.getPublicState().players,
          });

          // Also send a generic chat message so the guesser sees confirmation
          io.to(room.code).emit('chat-message', {
            type:      'system',
            nickname:  player.nickname,
            text:      `¡${player.nickname} adivinó la palabra! 🎉`,
            isCorrect: true,
          });
        } else {
          // Broadcast the guess as a chat message (visible to all — including drawer)
          io.to(room.code).emit('chat-message', {
            type:      'guess',
            socketId:  socket.id,
            nickname:  player.nickname,
            text:      guessText,
            isCorrect: false,
          });
        }
      } catch (err) {
        console.error('[guess] Error:', err);
      }
    });

    // ==================================================================
    // CHAT MESSAGE (non-guess chat, e.g. lobby chat)
    // Payload: { text: string }
    // ==================================================================
    socket.on('chat-message', ({ text } = {}) => {
      try {
        const room = getMyRoom();
        if (!room) return;

        // During gameplay, all chat goes through 'guess' — block direct chat
        if (room.status === 'playing') return;

        const player = room.players.get(socket.id);
        if (!player) return;

        if (typeof text !== 'string' || !text.trim()) return;

        io.to(room.code).emit('chat-message', {
          type:     'lobby',
          socketId: socket.id,
          nickname: player.nickname,
          text:     text.trim().substring(0, 200),
        });
      } catch (err) {
        console.error('[chat-message] Error:', err);
      }
    });

    // ==================================================================
    // DISCONNECT
    // ==================================================================
    socket.on('disconnect', (reason) => {
      console.log(`[Socket] Disconnected: ${socket.id} (${reason})`);

      try {
        const room = getMyRoom();
        if (!room) return;

        const player      = room.players.get(socket.id);
        const nickname    = player ? player.nickname : 'Jugador desconocido';
        const wasDrawing  = room.currentDrawerId === socket.id;
        const wasPlaying  = room.status === 'playing';

        const isEmpty = room.removePlayer(socket.id);

        if (isEmpty) {
          gameManager.removeRoom(room.code);
          return;
        }

        // Notify remaining players
        io.to(room.code).emit('player-left', {
          socketId: socket.id,
          nickname,
          players:  room.getPublicState().players,
        });

        // If the game is running and the drawer left, skip to the next turn
        if (wasPlaying && wasDrawing) {
          console.log(`[Room ${room.code}] Drawer left — skipping turn.`);
          io.to(room.code).emit('chat-message', {
            type:     'system',
            nickname: 'Sistema',
            text:     `${nickname} (dibujante) se fue. Saltando turno...`,
          });
          // Give clients a moment to process the leave before starting next turn
          setTimeout(() => {
            if (room.status === 'playing') {
              room._endTurn(false); // treat it as a missed turn
            }
          }, 2000);
        }

        // If in waiting lobby and there's only 1 player left, cancel ready state
        if (room.status === 'waiting') {
          for (const p of room.players.values()) p.isReady = false;
          io.to(room.code).emit('player-ready-update', {
            players: room.getPublicState().players,
          });
        }
      } catch (err) {
        console.error('[disconnect] Error:', err);
      }
    });
  });
}

module.exports = { registerHandlers };
