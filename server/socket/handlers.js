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
          socket.emit('join-error', { message: 'No se pudo unir: sala llena.' });
          return;
        }

        socket.roomCode = room.code;
        socket.sessionToken = player.sessionToken;
        socket.join(room.code);

        const publicRoom = room.getPublicState();

        // Confirm to joining socket
        socket.emit('room-joined', {
          roomCode:     room.code,
          isPrivate:    room.isPrivate,
          sessionToken: player.sessionToken,
          nickname:     player.nickname,
          player,
          players:      publicRoom.players,
          totalRounds:  publicRoom.totalRounds,
          room:         publicRoom,
        });

        // Notify everyone else in the room
        socket.to(room.code).emit('player-joined', {
          player,
          players: room.getPublicState().players,
        });

        // If game is already playing, provide current turn state snapshot immediately
        if (room.status === 'playing') {
          socket.emit('game-started', {
            totalRounds:  room.totalRounds,
            currentRound: room.currentRound,
            players:      publicRoom.players,
          });

          if (room.isSelectingWord) {
            socket.emit('drawer-choosing', {
              drawerId:       room.currentDrawerId,
              drawerNickname: room.players.get(room.currentDrawerId)?.nickname || 'Dibujante',
              timeLimit:      10,
              currentRound:   room.currentRound,
              totalRounds:    room.totalRounds,
              players:        publicRoom.players,
            });
          } else {
            socket.emit('turn-started', {
              drawerId:       room.currentDrawerId,
              drawerNickname: room.players.get(room.currentDrawerId)?.nickname || 'Dibujante',
              wordHint:       room.currentWordHint,
              wordLength:     room.currentWord ? room.currentWord.length : 0,
              roundTime:      room._getTimeLeft(),
              currentRound:   room.currentRound,
              totalRounds:    room.totalRounds,
              word:           null,
              players:        publicRoom.players,
            });

            if (room.currentStrokes && room.currentStrokes.length > 0) {
              socket.emit('drawing-data', { strokes: room.currentStrokes });
            }
          }
        }

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
        socket.sessionToken = player.sessionToken;
        socket.join(room.code);

        const publicRoom = room.getPublicState();

        socket.emit('room-joined', {
          roomCode:     room.code,
          isPrivate:    true,
          sessionToken: player.sessionToken,
          nickname:     player.nickname,
          player,
          players:      publicRoom.players,
          totalRounds:  publicRoom.totalRounds,
          room:         publicRoom,
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
          socket.emit('join-error', { message: 'La sala está llena.' });
          return;
        }

        const nick   = sanitizeNickname(nickname);
        const player = room.addPlayer(socket.id, nick);

        if (!player) {
          socket.emit('join-error', { message: 'No se pudo unir a la sala.' });
          return;
        }

        socket.roomCode = room.code;
        socket.sessionToken = player.sessionToken;
        socket.join(room.code);

        const publicRoom = room.getPublicState();

        socket.emit('room-joined', {
          roomCode:     room.code,
          isPrivate:    true,
          sessionToken: player.sessionToken,
          nickname:     player.nickname,
          player,
          players:      publicRoom.players,
          totalRounds:  publicRoom.totalRounds,
          room:         publicRoom,
        });

        socket.to(room.code).emit('player-joined', {
          player,
          players: room.getPublicState().players,
        });

        // If game is already playing, provide current turn state snapshot immediately
        if (room.status === 'playing') {
          socket.emit('game-started', {
            totalRounds:  room.totalRounds,
            currentRound: room.currentRound,
            players:      publicRoom.players,
          });

          if (room.isSelectingWord) {
            socket.emit('drawer-choosing', {
              drawerId:       room.currentDrawerId,
              drawerNickname: room.players.get(room.currentDrawerId)?.nickname || 'Dibujante',
              timeLimit:      10,
              currentRound:   room.currentRound,
              totalRounds:    room.totalRounds,
              players:        publicRoom.players,
            });
          } else {
            socket.emit('turn-started', {
              drawerId:       room.currentDrawerId,
              drawerNickname: room.players.get(room.currentDrawerId)?.nickname || 'Dibujante',
              wordHint:       room.currentWordHint,
              wordLength:     room.currentWord ? room.currentWord.length : 0,
              roundTime:      room._getTimeLeft(),
              currentRound:   room.currentRound,
              totalRounds:    room.totalRounds,
              word:           null,
              players:        publicRoom.players,
            });

            if (room.currentStrokes && room.currentStrokes.length > 0) {
              socket.emit('drawing-data', { strokes: room.currentStrokes });
            }
          }
        }

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
    // WORD CHOSEN (Drawer picks one of the 3 offered words)
    // Payload: { word: string }
    // ==================================================================
    socket.on('word-chosen', ({ word } = {}) => {
      try {
        const room = getMyRoom();
        if (!room || room.status !== 'playing') return;
        room.confirmWord(socket.id, word);
      } catch (err) {
        console.error('[word-chosen] Error:', err);
      }
    });

    // ==================================================================
    // DRAWING DATA (stroke chunks from canvas)
    // Payload: { strokes: any }   (format defined by client — passed through)
    // ==================================================================
    socket.on('drawing-data', ({ strokes } = {}) => {
      try {
        const room = getMyRoom();
        if (!room || room.status !== 'playing') return;
        if (room.currentDrawerId !== socket.id) return; // only the drawer may send strokes

        // Buffer strokes on room for any players joining mid-turn
        room.addStrokes(strokes);

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

        room.clearStrokes();
        socket.to(room.code).emit('canvas-cleared');
      } catch (err) {
        console.error('[clear-canvas] Error:', err);
      }
    });

    // ==================================================================
    // GUESS (supports both 'guess' and 'send-guess')
    // Payload: { text: string }
    // ==================================================================
    function handleGuess({ text } = {}) {
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
            playerId: socket.id,
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
            playerId:  socket.id,
            nickname:  player.nickname,
            text:      guessText,
            isCorrect: false,
          });
        }
      } catch (err) {
        console.error('[guess] Error:', err);
      }
    }

    socket.on('guess', handleGuess);
    socket.on('send-guess', handleGuess);

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
    // RECONNECT PLAYER
    // Payload: { roomCode: string, sessionToken: string }
    // ==================================================================
    socket.on('reconnect-player', ({ roomCode, sessionToken } = {}) => {
      try {
        if (!roomCode || !sessionToken) {
          socket.emit('reconnect-failed', { message: 'Datos de sesión incompletos.' });
          return;
        }

        const code = roomCode.trim().toUpperCase();
        const room = gameManager.getRoom(code);

        if (!room) {
          socket.emit('reconnect-failed', { message: 'La sala ya no existe o terminó.' });
          return;
        }

        const reconnectedPlayer = room.reconnectPlayer(socket.id, sessionToken);
        if (!reconnectedPlayer) {
          socket.emit('reconnect-failed', { message: 'Sesión no válida o expirada.' });
          return;
        }

        socket.roomCode = room.code;
        socket.sessionToken = sessionToken;
        socket.join(room.code);

        const publicRoom = room.getPublicState();
        const isDrawing = room.currentDrawerId === socket.id;

        socket.emit('reconnected-success', {
          roomCode:               room.code,
          isPrivate:              room.isPrivate,
          sessionToken,
          status:                 room.status,
          nickname:               reconnectedPlayer.nickname,
          player:                 reconnectedPlayer,
          players:                publicRoom.players,
          currentRound:           room.currentRound,
          totalRounds:            room.totalRounds,
          currentDrawerId:        room.currentDrawerId,
          currentDrawerNickname:  room.players.get(room.currentDrawerId)?.nickname || 'Dibujante',
          isDrawing,
          isSelectingWord:        room.isSelectingWord,
          offeredWords:           isDrawing && room.isSelectingWord ? room.offeredWords : null,
          currentWord:            isDrawing ? room.currentWord : null,
          wordHint:               room.currentWordHint,
          wordLength:             room.currentWord ? room.currentWord.length : 0,
          hasGuessed:             room.correctGuessers.has(socket.id),
          timeLeft:               room._getTimeLeft(),
          currentStrokes:         room.currentStrokes || [],
        });

        // Notify other players in the room
        socket.to(room.code).emit('player-reconnected', {
          socketId: socket.id,
          nickname: reconnectedPlayer.nickname,
          players:  publicRoom.players,
        });

        console.log(`[Room ${room.code}] ${reconnectedPlayer.nickname} reconnected with socket ${socket.id}.`);
      } catch (err) {
        console.error('[reconnect-player] Error:', err);
        socket.emit('reconnect-failed', { message: 'Error interno al reconectar.' });
      }
    });

    // ==================================================================
    // LEAVE ROOM (explicit user exit)
    // ==================================================================
    socket.on('leave-room', () => {
      try {
        const room = getMyRoom();
        if (!room) return;

        const player = room.players.get(socket.id);
        const nickname = player ? player.nickname : 'Jugador';
        const sessionToken = room.socketToToken.get(socket.id);

        const isEmpty = sessionToken
          ? room.permanentlyRemoveSession(sessionToken)
          : room.removePlayer(socket.id);

        socket.leave(room.code);
        delete socket.roomCode;
        delete socket.sessionToken;

        if (isEmpty) {
          gameManager.removeRoom(room.code);
          return;
        }

        io.to(room.code).emit('player-left', {
          socketId: socket.id,
          nickname,
          players:  room.getPublicState().players,
        });
      } catch (err) {
        console.error('[leave-room] Error:', err);
      }
    });

    // ==================================================================
    // DISCONNECT (with 25s grace period)
    // ==================================================================
    socket.on('disconnect', (reason) => {
      console.log(`[Socket] Disconnected: ${socket.id} (${reason})`);

      try {
        const room = getMyRoom();
        if (!room) return;

        const player = room.players.get(socket.id);
        const nickname = player ? player.nickname : 'Jugador desconocido';

        // Notify room that player disconnected temporarily
        io.to(room.code).emit('player-disconnected-temp', {
          socketId: socket.id,
          nickname,
          graceSeconds: 25,
        });

        // Start grace period in room
        room.startDisconnectGrace(socket.id, (isEmpty, removedPlayer) => {
          if (isEmpty) {
            console.log(`[Room ${room.code}] Room is empty after grace period. Removing room.`);
            gameManager.removeRoom(room.code);
            return;
          }

          // Notify room of permanent departure
          io.to(room.code).emit('player-left', {
            socketId: socket.id,
            nickname: removedPlayer ? removedPlayer.nickname : nickname,
            players:  room.getPublicState().players,
          });

          // If in waiting lobby and only 1 player remains, reset ready
          if (room.status === 'waiting') {
            for (const p of room.players.values()) p.isReady = false;
            io.to(room.code).emit('player-ready-update', {
              players: room.getPublicState().players,
            });
          }
        });
      } catch (err) {
        console.error('[disconnect] Error:', err);
      }
    });
  });
}

module.exports = { registerHandlers };
