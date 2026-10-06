/**
 * gameEngine.js
 * Proxy/entry point for GameRoom and GameManager engine classes.
 */

const GameRoom = require('../game/GameRoom');
const gameManager = require('../game/GameManager');

module.exports = {
  GameRoom,
  GameManager: gameManager.constructor,
  gameManager,
};
