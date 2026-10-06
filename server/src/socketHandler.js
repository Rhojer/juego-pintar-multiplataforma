/**
 * socketHandler.js
 * Proxy/entry point for socket handlers registration.
 */

const { registerHandlers } = require('../socket/handlers');

module.exports = {
  registerHandlers,
};
