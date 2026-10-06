/**
 * modes.js
 * Special modes and phonetic transformations for Rayando.
 */

const SPECIAL_MODES = {
  che_boludo: {
    id: 'che_boludo',
    name: 'Modo Che Boludo',
    emoji: '🇦🇷',
    subtitle: '¡Pará la mano che! ¡Metéle onda con acento porteño, pibe! 🧉',
    bannerText: '¡MODO CHE BOLUDO! ¡HABLA COMO EN BUENOS AIRES, CHE! 🇦🇷',
    badgeColor: '#29B6F6',
    textColor: '#0D47A1',
    ruleHint: 'En este modo las palabras se escriben según la tonada porteña 🇦🇷',
    hintReminder: '¡Casi che! ¡Acuérdate de la pronunciación bien porteña!',
    celebrationText: '¡la clavó al ángulo con acento che boludo! 🇦🇷🎉',
  },
  espanolete: {
    id: 'espanolete',
    name: 'Modo Españolete',
    emoji: '🇪🇸',
    subtitle: '¡Hostia chaval! ¡A todo gas con el acento madrileño! 🥘',
    bannerText: '¡MODO ESPAÑOLETE! ¡A TODO GAS, TÍO! 🇪🇸',
    badgeColor: '#E53935',
    textColor: '#FFD54F',
    ruleHint: 'En este modo las palabras se escriben con el acento de España 🇪🇸',
    hintReminder: '¡Hostia tío! ¡Que no se te olvide el acento de la Madre Patria!',
    celebrationText: '¡ha flipado en colores con su acento y acertó! 🇪🇸🎉',
  },
  chinense: {
    id: 'chinense',
    name: 'Modo Chinense',
    emoji: '🥢',
    subtitle: '¡Hola amio! ¡Atento con la plonunciación del país oliental! 🥢',
    bannerText: '¡MODO CHINENSE! ¡PLONUNCIA BIEN, AMIO! 🥢',
    badgeColor: '#D32F2F',
    textColor: '#FFD700',
    ruleHint: 'En este modo las palabras se escriben como plonuncia el paisano 🥢',
    hintReminder: '¡Casi amio! ¡Recuelda cómo plonuncia el paisano!',
    celebrationText: '¡adivinó clalo amio! ¡Toma calamelo de vuelto! 🍬',
  },
};

/**
 * Fonética Modo Che Boludo (Argentino):
 * Las palabras con 'll' o 'y' se reemplazan por 'sh'.
 * e.g. 'playa' -> 'plasha', 'caballo' -> 'cabasho', 'lluvia' -> 'shuvia', 'llave' -> 'shave'
 */
function transformCheBoludo(word) {
  if (!word || typeof word !== 'string') return '';
  return word.toLowerCase().replace(/ll/g, 'sh').replace(/y/g, 'sh');
}

/**
 * Fonética Modo Españolete:
 * Las 'c' que suenan como 's' (antes de 'e' o 'i') y las 's' se reemplazan por 'z'.
 * e.g. 'casa' -> 'caza', 'sol' -> 'zol', 'queso' -> 'quezo', 'cocinar' -> 'cozinar'
 */
function transformEspanolete(word) {
  if (!word || typeof word !== 'string') return '';
  return word.toLowerCase().replace(/c(?=[ei])/g, 'z').replace(/s/g, 'z');
}

/**
 * Fonética Modo Chinense:
 * Las 'r' (y 'rr') se reemplazan por 'l'.
 * e.g. 'perro' -> 'pelo', 'carro' -> 'calo', 'arroz' -> 'aloz', 'guitarra' -> 'guitala', 'flor' -> 'flol'
 */
function transformChinense(word) {
  if (!word || typeof word !== 'string') return '';
  return word.toLowerCase().replace(/rr/g, 'l').replace(/r/g, 'l');
}

/**
 * Transforma una palabra según el modo especial activo.
 * @param {string} word
 * @param {string} modeId
 * @returns {string}
 */
function transformWordForMode(word, modeId) {
  if (!word) return '';
  if (modeId === 'che_boludo') return transformCheBoludo(word);
  if (modeId === 'espanolete') return transformEspanolete(word);
  if (modeId === 'chinense') return transformChinense(word);
  return word;
}

/**
 * Verifica si una palabra es candidata para el modo (contiene las letras a transformar).
 * @param {string} word
 * @param {string} modeId
 * @returns {boolean}
 */
function isWordEligibleForMode(word, modeId) {
  if (!word) return false;
  return transformWordForMode(word, modeId).toLowerCase() !== word.toLowerCase();
}

module.exports = {
  SPECIAL_MODES,
  transformCheBoludo,
  transformEspanolete,
  transformChinense,
  transformWordForMode,
  isWordEligibleForMode,
};
