/**
 * words.js
 * Proxy/entry point for words and word bank helpers.
 */

const gameWords = require('../game/words');
const modes = require('./modes');

module.exports = {
  ...gameWords,
  ...modes,
};
