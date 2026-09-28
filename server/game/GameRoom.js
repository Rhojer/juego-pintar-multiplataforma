/**
 * GameRoom.js
 * Represents a single game room. Manages players, turns, scoring, and
 * emits Socket.io events directly to the room channel.
 */

const { getAllWords, pickRandomWord, pickThreeWords } = require('./words');

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

    /** @type {SocketIO.Server} set via startGame() */
    this._io               = null;

    this._hintRevealCount  = 0;     // how many hint letters revealed so far
  }

  // -------------------------------------------------------------------------
  // Player management
  // -------------------------------------------------------------------------

  /**
   * Adds a player to the room.
   * @param {string} socketId
   * @param {string} nickname
   * @returns {{ id: string, nickname: string, score: number, isReady: boolean, isDrawing: boolean }|null}
   *          null if room is full or game already in progress
   */
  addPlayer(socketId, nickname) {
    if (this.players.size >= MAX_PLAYERS) return null;

    const player = {
      id:        socketId,
      nickname:  nickname.trim().substring(0, 20) || `Jugador${this.players.size + 1}`,
      score:     0,
      isReady:   this.status === 'playing',
      isDrawing: false,
    };

    this.players.set(socketId, player);

    // If game is in progress, add to draw order so they also get turns
    if (this.status === 'playing') {
      if (!this.drawOrder.includes(socketId)) {
        this.drawOrder.push(socketId);
      }
    }

    return player;
  }

  /**
   * Removes a player from the room.
   * @param {string} socketId
   * @returns {boolean} true if the room is now empty
   */
  removePlayer(socketId) {
    this.players.delete(socketId);
    this.correctGuessers.delete(socketId);

    // Remove from draw order if present
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
   * @param {any} strokes
   */
  addStrokes(strokes) {
    if (!this.currentStrokes) this.currentStrokes = [];
    if (Array.isArray(strokes)) {
      this.currentStrokes.push(...strokes);
    } else if (strokes) {
      this.currentStrokes.push(strokes);
    }
  }

  /**
   * Clears the current stroke buffer.
   */
  clearStrokes() {
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
      players: [...this.players.values()].map((p) => ({
        id:        p.id,
        nickname:  p.nickname,
        score:     p.score,
        isReady:   p.isReady,
        isDrawing: p.isDrawing,
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
    this.offeredWords    = pickThreeWords();
    const drawerNickname = this.players.get(drawerId)?.nickname || 'Dibujante';

    console.log(`[Room ${this.code}] Round ${this.currentRound} — ${drawerNickname} is choosing between: ${this.offeredWords.join(', ')}`);

    // Emit 'choose-word' to the drawer with the 3 choices
    this._io.to(drawerId).emit('choose-word', {
      words:          this.offeredWords,
      timeLimit:      10,
      drawerNickname,
    });

    // Emit 'drawer-choosing' to the entire room
    this._io.to(this.code).emit('drawer-choosing', {
      drawerId:       this.currentDrawerId,
      drawerNickname,
      timeLimit:      10,
      currentRound:   this.currentRound,
      totalRounds:    this.totalRounds,
      players:        this.getPublicState().players,
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
    console.log(`[Room ${this.code}] Round ${this.currentRound} — ${drawerNickname} draws "${this.currentWord}"`);

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
      });
    }

    // Also send 'your-word' directly to drawer for full compatibility
    this._io.to(this.currentDrawerId).emit('your-word', {
      word:     this.currentWord,
      wordHint: this.currentWordHint,
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
    }

    console.log(`[Room ${this.code}] Turn ended. Word was "${this.currentWord}". Guessed: ${this.correctGuessers.size}`);

    this._io.to(this.code).emit('turn-ended', {
      word:    this.currentWord,
      players: [...this.players.values()].map((p) => ({
        id:       p.id,
        nickname: p.nickname,
        score:    p.score,
      })),
      allGuessed,
    });

    // Pause briefly before starting the next turn so clients can show results
    setTimeout(() => {
      if (this.status === 'playing') {
        this._startTurn();
      }
    }, 4000);
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

    const normalizedGuess = guess.trim().toLowerCase();
    const normalizedWord  = (this.currentWord || '').toLowerCase();
    const isCorrect       = normalizedGuess === normalizedWord;

    if (isCorrect) {
      const timeLeft = this._getTimeLeft();
      const points   = this._calculateScore(timeLeft);

      if (this.players.has(socketId)) {
        this.players.get(socketId).score += points;
      }

      this.correctGuessers.add(socketId);

      // Non-drawer players who can still guess
      const guessers = [...this.players.keys()].filter(
        (id) => id !== this.currentDrawerId,
      );
      const allGuessed = guessers.every((id) => this.correctGuessers.has(id));

      if (allGuessed) {
        // Everyone got it — end turn early
        setTimeout(() => this._endTurn(true), 1500);
      }

      return { correct: true, alreadyGuessed: false, points, allGuessed };
    }

    return { correct: false, alreadyGuessed: false };
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
