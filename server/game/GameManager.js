/**
 * GameManager.js
 * Singleton that owns all active GameRoom instances.
 * Provides helpers for creating, retrieving, and cleaning up rooms.
 */

const { v4: uuidv4 } = require('uuid');
const GameRoom        = require('./GameRoom');

// Maximum players per room (mirrors the constant in GameRoom for checks here)
const MAX_PLAYERS = 8;

class GameManager {
  constructor() {
    /**
     * All active rooms keyed by their room code.
     * @type {Map<string, GameRoom>}
     */
    this.rooms = new Map();
  }

  // ---------------------------------------------------------------------------
  // Room creation
  // ---------------------------------------------------------------------------

  /**
   * Creates a new room.
   * Private rooms get a human-readable 6-char alphanumeric code.
   * Public rooms get a full UUID (used internally; players join by matchmaking).
   *
   * @param {boolean} isPrivate
   * @returns {GameRoom}
   */
  createRoom(isPrivate) {
    const code = isPrivate ? this._generatePrivateCode() : uuidv4();
    const room = new GameRoom(code, isPrivate);
    this.rooms.set(code, room);
    console.log(`[GameManager] Room created — code: ${code} | private: ${isPrivate}`);
    return room;
  }

  // ---------------------------------------------------------------------------
  // Room retrieval
  // ---------------------------------------------------------------------------

  /**
   * Retrieves a room by its code.
   * @param {string} roomCode
   * @returns {GameRoom|null}
   */
  getRoom(roomCode) {
    return this.rooms.get(roomCode) || null;
  }

  /**
   * Finds a public room with available space, or creates a fresh one.
   * Rooms in 'playing' or 'results' state are skipped.
   * @returns {GameRoom}
   */
  getOrCreatePublicRoom() {
    for (const room of this.rooms.values()) {
      if (!room.isPrivate && room.hasSpace()) {
        return room;
      }
    }
    // No suitable room found — spin up a new one
    return this.createRoom(false);
  }

  // ---------------------------------------------------------------------------
  // Room removal
  // ---------------------------------------------------------------------------

  /**
   * Deletes a room from the manager if it is empty.
   * Call this after every player disconnect.
   * @param {string} roomCode
   */
  removeRoom(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return;

    if (room.players.size === 0) {
      this.rooms.delete(roomCode);
      console.log(`[GameManager] Room ${roomCode} removed (empty).`);
    }
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  /**
   * Returns a summary of all active rooms (useful for admin / healthcheck).
   * @returns {object[]}
   */
  getRoomSummaries() {
    return [...this.rooms.values()].map((r) => ({
      code:       r.code,
      isPrivate:  r.isPrivate,
      players:    r.players.size,
      status:     r.status,
      round:      `${r.currentRound}/${r.totalRounds}`,
    }));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /**
   * Generates a unique 6-character uppercase alphanumeric code for private rooms.
   * Retries on the (very unlikely) chance of a collision.
   * @returns {string}
   * @private
   */
  _generatePrivateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars (0/O, 1/I)
    let code;
    do {
      code = Array.from({ length: 6 }, () =>
        chars[Math.floor(Math.random() * chars.length)],
      ).join('');
    } while (this.rooms.has(code));
    return code;
  }
}

// Export a singleton so every import shares the same state
module.exports = new GameManager();
