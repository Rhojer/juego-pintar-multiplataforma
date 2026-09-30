/**
 * GameRoom.js
 * Represents a single game room. Manages players, turns, scoring, and
 * emits Socket.io events directly to the room channel.
 */

const crypto = require('crypto');
const { getAllWords, pickRandomWord, pickThreeWords, pickThreeWordsForMode, SPECIAL_MODES } = require('./words');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const MAX_PLAYERS     = 8;
const TURN_DURATION   = 80;   // seconds per turn
const HINT_INTERVAL   = 20;   // reveal a letter every N seconds
const DRAWER_SCORE    = 50;   // bonus points for drawer when someone guesses
const MAX_SCORE       = 300;  // points for guessing within the first few seconds
const MIN_SCORE       = 50;   // minimum points for a correct guess

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Builds a hint string for a word: each letter becomes '_', spaces preserved.
 * e.g. 'arepa' -> '_ _ _ _ _'   'pan de jamón' -> '_ _ _   _ _   _ _ _ _ _'
 * @param {string} word
 * @returns {string}
 */
function buildHint(word) {
  return word
    .split('')
    .map((ch) => (ch === ' ' ? '  ' : '_'))
    .join(' ')
    .replace(/   /g, '   '); // keep multi-space gaps readable
}

/**
 * Reveals one more letter in the hint, chosen randomly from still-hidden positions.
 * @param {string} word     - original word
 * @param {string} hint     - current hint (e.g. '_ _ _ _ _')
 * @param {number} revealCount - how many letters have already been revealed
 * @returns {string} updated hint
 */
function revealNextLetter(word, hint, revealCount) {
  // Build list of indices (in original word) that are still hidden and not spaces
  const hiddenIndices = [];
  let hintIdx = 0;

  for (let i = 0; i < word.length; i++) {
    if (word[i] !== ' ') {
      // Each letter occupies 2 chars in hint ('_ '), except the last one
      const hintChar = hint[hintIdx];
      if (hintChar === '_') hiddenIndices.push({ wordIdx: i, hintIdx });
      hintIdx += 2;
    } else {
      hintIdx += 3; // spaces produce '  ' (3 chars with surrounding spaces)
    }
  }

  if (hiddenIndices.length === 0) return hint; // all revealed

  // Pick a random hidden letter to expose
  const chosen = hiddenIndices[Math.floor(Math.random() * hiddenIndices.length)];
  const hintArr = hint.split('');
  hintArr[chosen.hintIdx] = word[chosen.wordIdx];
  return hintArr.join('');
}

/**
 * Normalizes a string for comparison: removes accents, trims, and converts to lowercase.
 * e.g. 'Limón' -> 'limon', 'plátano' -> 'platano', 'avión' -> 'avion'
 * @param {string} str
 * @returns {string}
 */
function normalizeForComparison(str) {
  return (str || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}



// ---------------------------------------------------------------------------
// GameRoom class
// ---------------------------------------------------------------------------

class GameRoom {
  /**
   * @param {string}  code      - unique room identifier
   * @param {boolean} isPrivate - private rooms have 6-char alphanumeric codes
   */
  constructor(code, isPrivate) {
    this.code        = code;
    this.isPrivate   = isPrivate;

    /** @type {Map<string, {id: string, nickname: string, score: number, isReady: boolean, isDrawing: boolean}>} */
    this.players = new Map();

    /** @type {'waiting'|'playing'|'results'} */
    this.status = 'waiting';

    this.currentDrawerId   = null;
    this.currentWord       = null;   // only sent to the drawer
    this.currentWordHint   = null;   // sent to guessers
    this.roundTime         = TURN_DURATION;
    this.currentRound      = 0;
    this.totalRounds       = 3;
    this.drawOrder         = [];     // ordered socket IDs for drawing turns
    this.drawOrderIndex    = 0;      // pointer into drawOrder
    this.turnTimer         = null;   // setTimeout handle for turn end
    this.hintTimer         = null;   // setInterval handle for hint reveals
    this.tickTimer         = null;   // setInterval handle for seconds countdown
    this.wordSelectionTimer = null;  // setTimeout handle for word selection
    this.turnStartTime     = null;   // Date.ms when current turn started
    this.offeredWords      = [];     // 3 words offered to drawer
    this.isSelectingWord   = false;  // true while drawer is choosing
    this.currentStrokes    = [];     // buffer of strokes for mid-turn joins

    /** @type {Set<string>} socket IDs that guessed correctly this turn */
    this.correctGuessers   = new Set();

    /** @type {Map<string, number>} points earned this turn by each player */
    this.turnPointsGained  = new Map();

    /** @type {SocketIO.Server} set via startGame() */
    this._io               = null;

    this._hintRevealCount  = 0;     // how many hint letters revealed so far

    /** @type {Map<string, Object>} sessionToken -> player */
    this.sessions          = new Map();

    /** @type {Map<string, string>} socketId -> sessionToken */
    this.socketToToken     = new Map();

    /** @type {Map<string, NodeJS.Timeout>} sessionToken -> disconnect timeout */
    this.disconnectTimeouts = new Map();

    /** @type {Object|null} currently active special mode for this turn */
    this.currentSpecialMode       = null;
    this.totalTurnsPlayed         = 0;
    this.lastSpecialModeTurn      = -99;
    this.specialModesTriggeredCount = 0;

    /** @type {number} Timestamp of last user activity (for scale/cleanup) */
    this.lastActivity      = Date.now();
  }

  // -------------------------------------------------------------------------
  // Player management
  // -------------------------------------------------------------------------

  /**
   * Adds a player to the room.
   * @param {string} socketId
   * @param {string} nickname
   * @param {string} [avatar='arepa']
   * @returns {{ id: string, sessionToken: string, nickname: string, avatar: string, score: number, isReady: boolean, isDrawing: boolean }|null}
   *          null if room is full
   */
  addPlayer(socketId, nickname, avatar = 'arepa') {
    if (this.players.size >= MAX_PLAYERS) return null;

    this.lastActivity = Date.now();
    const sessionToken = crypto.randomUUID();
    const player = {
      id:           socketId,
      sessionToken,
      nickname:     nickname.trim().substring(0, 20) || `Jugador${this.players.size + 1}`,
      avatar:       typeof avatar === 'string' && avatar.trim() ? avatar.trim() : 'arepa',
      score:        0,
      isReady:      this.status === 'playing',
      isDrawing:    false,
      disconnected: false,
    };

    this.players.set(socketId, player);
    this.sessions.set(sessionToken, player);
    this.socketToToken.set(socketId, sessionToken);

    // If game is in progress, add to draw order so they also get turns
    if (this.status === 'playing') {
      if (!this.drawOrder.includes(socketId)) {
        this.drawOrder.push(socketId);
      }
    }

    return player;
  }

  /**
   * Starts a 25-second grace period when a socket disconnects.
   * @param {string} socketId
   * @param {Function} onPermanentlyRemoved (isEmpty, removedPlayer) => void
   */
  startDisconnectGrace(socketId, onPermanentlyRemoved) {
    const sessionToken = this.socketToToken.get(socketId);
    if (!sessionToken) {
      const isEmpty = this.removePlayer(socketId);
      if (onPermanentlyRemoved) onPermanentlyRemoved(isEmpty, null);
      return;
    }

    const player = this.sessions.get(sessionToken);
    if (!player) return;

    player.disconnected = true;

    // Clear any existing timer for this token
    if (this.disconnectTimeouts.has(sessionToken)) {
      clearTimeout(this.disconnectTimeouts.get(sessionToken));
    }

    console.log(`[Room ${this.code}] Player ${player.nickname} disconnected. Starting 25s grace period.`);

    const timeout = setTimeout(() => {
      this.disconnectTimeouts.delete(sessionToken);
      console.log(`[Room ${this.code}] Grace period expired for ${player.nickname}. Permanently removing.`);
      const isEmpty = this.permanentlyRemoveSession(sessionToken);
      if (onPermanentlyRemoved) {
        onPermanentlyRemoved(isEmpty, player);
      }
    }, 25000);

    this.disconnectTimeouts.set(sessionToken, timeout);
  }

  /**
   * Reconnects an existing player with a new socket ID.
   * @param {string} newSocketId
   * @param {string} sessionToken
   * @returns {Object|null} player or null if not found
   */
  reconnectPlayer(newSocketId, sessionToken) {
    const player = this.sessions.get(sessionToken);
    if (!player) return null;

    // Cancel grace timeout
    if (this.disconnectTimeouts.has(sessionToken)) {
      clearTimeout(this.disconnectTimeouts.get(sessionToken));
      this.disconnectTimeouts.delete(sessionToken);
    }

    const oldSocketId = player.id;

    // Update socket mappings
    this.players.delete(oldSocketId);
    this.socketToToken.delete(oldSocketId);

    player.id = newSocketId;
    player.disconnected = false;

    this.players.set(newSocketId, player);
    this.socketToToken.set(newSocketId, sessionToken);

    // Update drawOrder
    this.drawOrder = this.drawOrder.map((id) => (id === oldSocketId ? newSocketId : id));

    // Update current drawer if this player was drawing
    if (this.currentDrawerId === oldSocketId) {
      this.currentDrawerId = newSocketId;
    }

    // Update correctGuessers
    if (this.correctGuessers.has(oldSocketId)) {
      this.correctGuessers.delete(oldSocketId);
      this.correctGuessers.add(newSocketId);
    }

    // Update turnPointsGained
    if (this.turnPointsGained.has(oldSocketId)) {
      const pts = this.turnPointsGained.get(oldSocketId);
      this.turnPointsGained.delete(oldSocketId);
      this.turnPointsGained.set(newSocketId, pts);
    }

    console.log(`[Room ${this.code}] Player ${player.nickname} reconnected successfully! (new socket: ${newSocketId})`);
    return player;
  }

  /**
   * Permanently removes a player session.
   * @param {string} sessionToken
   * @returns {boolean} true if the room is now empty
   */
  permanentlyRemoveSession(sessionToken) {
    if (this.disconnectTimeouts.has(sessionToken)) {
      clearTimeout(this.disconnectTimeouts.get(sessionToken));
      this.disconnectTimeouts.delete(sessionToken);
    }

    const player = this.sessions.get(sessionToken);
    if (!player) return this.players.size === 0;

    const socketId = player.id;
    this.players.delete(socketId);
    this.sessions.delete(sessionToken);
    this.socketToToken.delete(socketId);
    this.correctGuessers.delete(socketId);
    this.turnPointsGained.delete(socketId);
    this.drawOrder = this.drawOrder.filter((id) => id !== socketId);

    // If the drawer left permanently during playing, skip turn
    if (this.status === 'playing' && this.currentDrawerId === socketId) {
      this._endTurn(false);
    }

    return this.players.size === 0;
  }

  /**
   * Removes a player from the room by socketId.
   * @param {string} socketId
   * @returns {boolean} true if the room is now empty
   */
  removePlayer(socketId) {
    const sessionToken = this.socketToToken.get(socketId);
    if (sessionToken) {
      return this.permanentlyRemoveSession(sessionToken);
    }

    this.players.delete(socketId);
    this.correctGuessers.delete(socketId);
    this.turnPointsGained.delete(socketId);
    this.drawOrder = this.drawOrder.filter((id) => id !== socketId);

    return this.players.size === 0;
  }

  /**
   * Returns true if the room can still accept new players.
   */
  hasSpace() {
    return this.players.size < MAX_PLAYERS;
  }

  /**
   * Adds strokes to turn buffer for mid-game/turn synchronization.
   * Capped to MAX_STROKES_BUFFER to conserve memory under high concurrency.
   * @param {any} strokes
   */
  addStrokes(strokes) {
    this.lastActivity = Date.now();
    const MAX_STROKES_BUFFER = 500;
    if (!this.currentStrokes) this.currentStrokes = [];
    if (Array.isArray(strokes)) {
      this.currentStrokes.push(...strokes);
    } else if (strokes) {
      this.currentStrokes.push(strokes);
    }
    if (this.currentStrokes.length > MAX_STROKES_BUFFER) {
      this.currentStrokes = this.currentStrokes.slice(-MAX_STROKES_BUFFER);
    }
  }

  /**
   * Clears the current stroke buffer.
   */
  clearStrokes() {
    this.currentStrokes = [];
  }

  /**
   * Cleans up all active timers and maps to avoid memory leaks.
   */
  destroy() {
    clearTimeout(this.turnTimer);
    clearInterval(this.hintTimer);
    clearInterval(this.tickTimer);
    clearTimeout(this.wordSelectionTimer);
    for (const timeout of this.disconnectTimeouts.values()) {
      clearTimeout(timeout);
    }
    this.disconnectTimeouts.clear();
    this.players.clear();
    this.sessions.clear();
    this.socketToToken.clear();
    this.correctGuessers.clear();
    this.turnPointsGained.clear();
    this.currentStrokes = [];
  }

  // -------------------------------------------------------------------------
  // Public state (safe to broadcast — no secret word)
  // -------------------------------------------------------------------------

  /**
   * Builds a sanitized room snapshot suitable for broadcasting.
   * The actual word is never included; only its character count hint.
   */
  getPublicState() {
    const currentDrawer = this.players.get(this.currentDrawerId);
    const timeLeft = this._getTimeLeft();

    return {
      code:                   this.code,
      isPrivate:              this.isPrivate,
      status:                 this.status,
      currentRound:           this.currentRound,
      totalRounds:            this.totalRounds,
      currentDrawerNickname:  currentDrawer ? currentDrawer.nickname : null,
      currentDrawerId:        this.currentDrawerId,
      isSelectingWord:        this.isSelectingWord,
      wordHint:               this.currentWordHint,
      wordLength:             this.currentWord ? this.currentWord.length : 0,
      timeLeft,
      specialMode:          this.currentSpecialMode,
      players: [...this.players.values()].map((p) => ({
        id:           p.id,
        nickname:     p.nickname,
        avatar:       p.avatar || 'arepa',
        score:        p.score,
        isReady:      p.isReady,
        isDrawing:    p.isDrawing,
        disconnected: p.disconnected || false,
      })),
    };
  }

  // -------------------------------------------------------------------------
  // Game lifecycle
  // -------------------------------------------------------------------------

  /**
   * Kicks off the game. Called externally once all players are ready.
   * @param {import('socket.io').Server} io
   */
  startGame(io) {
    if (this.status === 'playing') return;
    if (this.players.size < 2) return;

    this._io         = io;
    this.status      = 'playing';
    this.currentRound = 1;

    // Build draw order: every player draws once per round
    this.drawOrder      = [...this.players.keys()];
    this.drawOrderIndex = 0;

    // Reset all scores
    for (const player of this.players.values()) {
      player.score    = 0;
      player.isReady  = false;
      player.isDrawing = false;
    }

    console.log(`[Room ${this.code}] Game started with ${this.players.size} players.`);

    // Broadcast 'game-started' to everyone in the room
    this._io.to(this.code).emit('game-started', {
      totalRounds:  this.totalRounds,
      currentRound: this.currentRound,
      players:      this.getPublicState().players,
    });

    // Start first turn with a brief 1-second delay so clients can navigate smoothly
    setTimeout(() => {
      if (this.status === 'playing') {
        this._startTurn();
      }
    }, 1000);
  }

  /**
   * Starts a new drawing turn for the next drawer in the draw order.
   * @private
   */
  _startTurn() {
    if (!this._io) return;

    // Clear any lingering timers
    this._clearTimers();
    this.correctGuessers.clear();
    this.turnPointsGained.clear();
    this._hintRevealCount = 0;
    this.currentStrokes = [];

    // Determine whose turn it is
    // Advance round when we've cycled through all players
    if (this.drawOrderIndex >= this.drawOrder.length) {
      this.drawOrderIndex = 0;
      this.currentRound++;

      if (this.currentRound > this.totalRounds) {
        this._endGame();
        return;
      }
    }

    const drawerId = this.drawOrder[this.drawOrderIndex];
    this.drawOrderIndex++;

    // Handle the case where the scheduled drawer has disconnected
    if (!this.players.has(drawerId)) {
      this._startTurn(); // skip to next
      return;
    }

    // Update drawer flags
    for (const player of this.players.values()) {
      player.isDrawing = player.id === drawerId;
    }

    this.currentDrawerId = drawerId;
    this.isSelectingWord = true;
    this.totalTurnsPlayed++;
    this.currentSpecialMode = null;

    const drawerNickname = this.players.get(drawerId)?.nickname || 'Dibujante';

    // Check if this turn activates a Special Mode:
    // ~35% chance, with >= 2 turns cooldown, or guaranteed once if round >= 2 and none yet
    const modeKeys = Object.keys(SPECIAL_MODES);
    const turnsSinceSpecial = this.totalTurnsPlayed - this.lastSpecialModeTurn;
    const isSpecialTurn = (turnsSinceSpecial >= 2 && Math.random() < 0.35) ||
      (this.currentRound >= 2 && this.specialModesTriggeredCount === 0 && turnsSinceSpecial >= 1);

    if (isSpecialTurn) {
      const randomKey = modeKeys[Math.floor(Math.random() * modeKeys.length)];
      const modeData = SPECIAL_MODES[randomKey];
      this.currentSpecialMode = {
        id: modeData.id,
        name: modeData.name,
        emoji: modeData.emoji,
        subtitle: modeData.subtitle,
        bannerText: modeData.bannerText,
        badgeColor: modeData.badgeColor,
        textColor: modeData.textColor,
        celebrationText: modeData.celebrationText,
      };
      this.lastSpecialModeTurn = this.totalTurnsPlayed;
      this.specialModesTriggeredCount++;
      console.log(`[Room ${this.code}] 💥 SPECIAL MODE TRIGGERED: ${modeData.name} (${modeData.emoji}) for ${drawerNickname}`);
    }

    this.offeredWords = this.currentSpecialMode
      ? pickThreeWordsForMode(this.currentSpecialMode.id)
      : pickThreeWords();

    console.log(`[Room ${this.code}] Round ${this.currentRound}/${this.totalRounds} — ${drawerNickname} is choosing between: ${this.offeredWords.join(', ')}`);

    // Emit 'choose-word' to the drawer with the 3 choices
    this._io.to(drawerId).emit('choose-word', {
      words:          this.offeredWords,
      timeLimit:      10,
      drawerNickname,
      specialMode:    this.currentSpecialMode,
    });

    // Emit 'drawer-choosing' to the entire room
    this._io.to(this.code).emit('drawer-choosing', {
      drawerId:       this.currentDrawerId,
      drawerNickname,
      timeLimit:      10,
      currentRound:   this.currentRound,
      totalRounds:    this.totalRounds,
      players:        this.getPublicState().players,
      specialMode:    this.currentSpecialMode,
    });

    // 10-second countdown for word selection
    let choosingTimeLeft = 10;
    this._io.to(this.code).emit('timer-tick', choosingTimeLeft);
    this._io.to(this.code).emit('timer-tick-data', { seconds: choosingTimeLeft, phase: 'choosing' });

    if (this.tickTimer) clearInterval(this.tickTimer);
    this.tickTimer = setInterval(() => {
      choosingTimeLeft = Math.max(0, choosingTimeLeft - 1);
      this._io.to(this.code).emit('timer-tick', choosingTimeLeft);
      this._io.to(this.code).emit('timer-tick-data', { seconds: choosingTimeLeft, phase: 'choosing' });
    }, 1000);

    // If drawer doesn't pick in 10s, auto-select first word
    this.wordSelectionTimer = setTimeout(() => {
      if (this.isSelectingWord && this.status === 'playing') {
        console.log(`[Room ${this.code}] Drawer timeout choosing word. Auto-selecting "${this.offeredWords[0]}"`);
        this.confirmWord(drawerId, this.offeredWords[0]);
      }
    }, 10000);
  }

  /**
   * Confirms the word chosen by the drawer and starts the drawing phase.
   * @param {string} socketId
   * @param {string} chosenWord
   */
  confirmWord(socketId, chosenWord) {
    if (!this.isSelectingWord || this.currentDrawerId !== socketId) return;

    if (this.wordSelectionTimer) {
      clearTimeout(this.wordSelectionTimer);
      this.wordSelectionTimer = null;
    }
    if (this.tickTimer) {
      clearInterval(this.tickTimer);
      this.tickTimer = null;
    }

    this.isSelectingWord = false;

    // Validate chosen word from offered list or fallback to first
    const validWord = (this.offeredWords && this.offeredWords.includes(chosenWord))
      ? chosenWord
      : (this.offeredWords && this.offeredWords[0]) || pickRandomWord();

    this.currentWord     = validWord;
    this.currentWordHint = buildHint(this.currentWord);
    this.turnStartTime   = Date.now();
    this.currentStrokes  = [];

    const drawerNickname = this.players.get(this.currentDrawerId)?.nickname || 'Dibujante';
    console.log(`[Room ${this.code}] Round ${this.currentRound}/${this.totalRounds} — ${drawerNickname} draws "${this.currentWord}"`);

    // Emit 'turn-started' to each socket: drawer gets secret word, guessers get hint
    const publicPlayers = this.getPublicState().players;
    for (const p of this.players.values()) {
      const isDrawer = p.id === this.currentDrawerId;
      this._io.to(p.id).emit('turn-started', {
        drawerId:              this.currentDrawerId,
        drawerNickname:        drawerNickname,
        wordHint:              this.currentWordHint,
        wordLength:            this.currentWord.length,
        roundTime:             TURN_DURATION,
        currentRound:          this.currentRound,
        totalRounds:           this.totalRounds,
        word:                  isDrawer ? this.currentWord : null,
        players:               publicPlayers,
        specialMode:           this.currentSpecialMode,
      });
    }

    // Also send 'your-word' directly to drawer for full compatibility
    this._io.to(this.currentDrawerId).emit('your-word', {
      word:        this.currentWord,
      wordHint:    this.currentWordHint,
      specialMode: this.currentSpecialMode,
    });

    // Second-by-second countdown for client timer
    this._timeLeft = TURN_DURATION;
    this._io.to(this.code).emit('timer-tick', this._timeLeft);
    this._io.to(this.code).emit('timer-tick-data', { seconds: this._timeLeft, phase: 'drawing' });

    this.tickTimer = setInterval(() => {
      this._timeLeft = Math.max(0, this._timeLeft - 1);
      this._io.to(this.code).emit('timer-tick', this._timeLeft);
      this._io.to(this.code).emit('timer-tick-data', { seconds: this._timeLeft, phase: 'drawing' });
    }, 1000);

    // Schedule hint reveals (every HINT_INTERVAL seconds)
    this.hintTimer = setInterval(() => {
      this._hintRevealCount++;
      this.currentWordHint = revealNextLetter(
        this.currentWord,
        this.currentWordHint,
        this._hintRevealCount,
      );
      this._io.to(this.code).emit('hint-update', { wordHint: this.currentWordHint, hint: this.currentWordHint });
      this._io.to(this.code).emit('word-hint-update', { wordHint: this.currentWordHint, hint: this.currentWordHint });
    }, HINT_INTERVAL * 1000);

    // Schedule automatic turn end
    this.turnTimer = setTimeout(() => {
      this._endTurn(false);
    }, TURN_DURATION * 1000);
  }

  /**
   * Ends the current turn, calculates scores, and broadcasts results.
   * @param {boolean} allGuessed - true when every non-drawer guessed correctly
   * @private
   */
  _endTurn(allGuessed) {
    this._clearTimers();

    if (!this._io) return;

    // Award drawer bonus: one point for each correct guesser
    if (this.currentDrawerId && this.players.has(this.currentDrawerId)) {
      const drawerBonus = this.correctGuessers.size * DRAWER_SCORE;
      this.players.get(this.currentDrawerId).score += drawerBonus;
      if (drawerBonus > 0) {
        this.turnPointsGained.set(this.currentDrawerId, drawerBonus);
      }
    }

    console.log(`[Room ${this.code}] Turn ended. Word was "${this.currentWord}". Guessed: ${this.correctGuessers.size}`);

    this._io.to(this.code).emit('turn-ended', {
      word:         this.currentWord,
      players:      [...this.players.values()].map((p) => ({
        id:           p.id,
        nickname:     p.nickname,
        score:        p.score,
        pointsGained: this.turnPointsGained.get(p.id) || 0,
      })),
      allGuessed,
      currentRound: this.currentRound,
      totalRounds:  this.totalRounds,
      specialMode:  this.currentSpecialMode,
    });

    // Reset special mode at the conclusion of the turn
    this.currentSpecialMode = null;

    // Pause 5 seconds before starting the next turn so clients can show minimal results overlay
    setTimeout(() => {
      if (this.status === 'playing') {
        this._startTurn();
      }
    }, 5000);
  }

  /**
   * Ends the game and resets room to 'waiting' state.
   * @private
   */
  _endGame() {
    this._clearTimers();
    this.status = 'results';

    // Sort players by score descending for leaderboard
    const leaderboard = [...this.players.values()]
      .sort((a, b) => b.score - a.score)
      .map((p, index) => ({
        rank:     index + 1,
        id:       p.id,
        nickname: p.nickname,
        score:    p.score,
      }));

    console.log(`[Room ${this.code}] Game over. Winner: ${leaderboard[0]?.nickname}`);

    if (this._io) {
      const publicPlayers = this.getPublicState().players;
      this._io.to(this.code).emit('game-over', { leaderboard, players: publicPlayers });
      this._io.to(this.code).emit('game-ended', { leaderboard, players: publicPlayers });
    }

    // Reset to waiting after a short delay
    setTimeout(() => {
      this._resetRoom();
    }, 10000);
  }

  /**
   * Resets all room state so players can start a new game.
   * @private
   */
  _resetRoom() {
    this.status          = 'waiting';
    this.currentDrawerId = null;
    this.currentWord     = null;
    this.currentWordHint = null;
    this.currentRound    = 0;
    this.drawOrder       = [];
    this.drawOrderIndex  = 0;
    this.isSelectingWord = false;
    this.offeredWords    = [];
    this.currentStrokes  = [];
    this.correctGuessers.clear();
    this.turnPointsGained.clear();
    this.currentSpecialMode       = null;
    this.totalTurnsPlayed         = 0;
    this.lastSpecialModeTurn      = -99;
    this.specialModesTriggeredCount = 0;

    for (const player of this.players.values()) {
      player.score     = 0;
      player.isReady   = false;
      player.isDrawing = false;
    }

    if (this._io) {
      this._io.to(this.code).emit('room-reset', this.getPublicState());
    }
  }

  // -------------------------------------------------------------------------
  // Guessing logic
  // -------------------------------------------------------------------------

  /**
   * Processes a guess from a player.
   * @param {string} socketId
   * @param {string} guess
   * @returns {{ correct: boolean, alreadyGuessed: boolean }}
   */
  handleGuess(socketId, guess) {
    // Drawers can't guess their own word
    if (socketId === this.currentDrawerId) {
      return { correct: false, alreadyGuessed: false };
    }

    // Can't guess again after already getting it right
    if (this.correctGuessers.has(socketId)) {
      return { correct: false, alreadyGuessed: true };
    }

    // Accent-insensitive and case-insensitive check
    const isCorrect = normalizeForComparison(guess) === normalizeForComparison(this.currentWord);

    if (isCorrect) {
      const timeLeft = this._getTimeLeft();
      const points   = this._calculateScore(timeLeft);

      if (this.players.has(socketId)) {
        this.players.get(socketId).score += points;
        this.turnPointsGained.set(socketId, points);
      }

      this.correctGuessers.add(socketId);

      // Non-drawer players who can still guess
      const guessers = [...this.players.keys()].filter(
        (id) => id !== this.currentDrawerId,
      );
      const allGuessed = guessers.length > 0 && guessers.every((id) => this.correctGuessers.has(id));

      if (allGuessed) {
        // Immediately end countdown: snap timer to 0 and end turn early
        this._timeLeft = 0;
        this._io.to(this.code).emit('timer-tick', 0);
        this._io.to(this.code).emit('timer-tick-data', { seconds: 0, phase: 'drawing' });
        if (this.tickTimer) {
          clearInterval(this.tickTimer);
          this.tickTimer = null;
        }
        if (this.turnTimer) {
          clearTimeout(this.turnTimer);
          this.turnTimer = null;
        }
        setTimeout(() => this._endTurn(true), 600);
      }

      return { correct: true, alreadyGuessed: false, points, allGuessed, specialMode: this.currentSpecialMode };
    }

    return { correct: false, alreadyGuessed: false, specialMode: this.currentSpecialMode };
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /**
   * Calculates score based on how much time remains.
   * @param {number} timeLeft  seconds remaining
   * @returns {number}
   */
  _calculateScore(timeLeft) {
    // Linear interpolation: full time -> MAX_SCORE, 0 time -> MIN_SCORE
    const ratio = Math.max(0, Math.min(1, timeLeft / TURN_DURATION));
    return Math.round(MIN_SCORE + (MAX_SCORE - MIN_SCORE) * ratio);
  }

  /**
   * Returns how many seconds are left in the current turn.
   * @returns {number}
   */
  _getTimeLeft() {
    if (!this.turnStartTime) return 0;
    const elapsed = Math.floor((Date.now() - this.turnStartTime) / 1000);
    return Math.max(0, TURN_DURATION - elapsed);
  }

  /**
   * Clears both the turn timeout and hint interval.
   * @private
   */
  _clearTimers() {
    if (this.wordSelectionTimer) {
      clearTimeout(this.wordSelectionTimer);
      this.wordSelectionTimer = null;
    }
    if (this.turnTimer) {
      clearTimeout(this.turnTimer);
      this.turnTimer = null;
    }
    if (this.hintTimer) {
      clearInterval(this.hintTimer);
      this.hintTimer = null;
    }
    if (this.tickTimer) {
      clearInterval(this.tickTimer);
      this.tickTimer = null;
    }
  }
}

module.exports = GameRoom;
