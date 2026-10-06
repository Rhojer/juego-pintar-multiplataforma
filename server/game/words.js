/**
 * words.js
 * Banco de palabras de Rayando:
 * - Todas son de UNA SOLA PALABRA (sin espacios ni frases compuestas).
 * - Fáciles de dibujar y adivinar.
 * - Incluye sustantivos cotidianos, animales, comida, naturaleza,
 *   acciones (verbos dibujables) y términos venezolanos populares.
 */

const wordBank = {
  // Verbos y acciones fáciles de representar con dibujos
  // Acciones y verbos
  acciones: [
    'bailar', 'correr', 'dormir', 'llorar', 'cantar',
    'nadar', 'cocinar', 'saltar', 'comer', 'pintar',
    'reir', 'barrer', 'peinar', 'manejar', 'escribir',
    'volar', 'pescar', 'boxear', 'limpiar', 'patinar',
    'gritar', 'besar', 'abrazar', 'cortar', 'lavar',
    'rayar', 'apoyar',
  ],

  // Comida, frutas y platos
  comida: [
    'arepa', 'empanada', 'cachapa', 'tequeño', 'hallaca',
    'mango', 'cambur', 'piña', 'manzana', 'fresa',
    'naranja', 'limon', 'sandia', 'aguacate', 'platano',
    'pizza', 'hamburguesa', 'huevo', 'queso', 'pan',
    'torta', 'helado', 'galleta', 'sopa', 'tajadas',
    'chocolate', 'chicha', 'papelon', 'guarapo', 'mandoca',
    'pollo', 'cebolla', 'mayonesa', 'yogur',
  ],

  // Animales comunes y autóctonos
  animales: [
    'perro', 'gato', 'caballo', 'elefante', 'mono',
    'tortuga', 'loro', 'pato', 'pez', 'tiburon',
    'ballena', 'raton', 'leon', 'tigre', 'vaca',
    'cerdo', 'oveja', 'conejo', 'araña', 'serpiente',
    'mariposa', 'abeja', 'rana', 'pinguino', 'cangrejo',
    'jirafa', 'pulpo', 'buho', 'aguila', 'turpial',
    'chigüire', 'morrocoy', 'cunaguaro', 'tonina', 'caiman',
    'ardilla', 'camello', 'papagayo',
  ],

  // Objetos y herramientas cotidianas
  objetos: [
    'martillo', 'tijera', 'lapiz', 'zapato', 'mesa',
    'silla', 'cama', 'carro', 'avion', 'barco',
    'reloj', 'telefono', 'guitarra', 'libro', 'vaso',
    'llave', 'paraguas', 'sombrero', 'lentes', 'espejo',
    'tenedor', 'cuchillo', 'cuchara', 'plato', 'cepillo',
    'vela', 'candado', 'maleta', 'pelota', 'bicicleta',
    'cohete', 'puente', 'bombillo', 'budare', 'cuatro',
    'maracas', 'tambor', 'hamaca', 'alpargata', 'gandola',
    'botella', 'toalla', 'anillo', 'yate', 'yoyo',
  ],

  // Naturaleza, clima y lugares
  naturaleza: [
    'playa', 'sol', 'luna', 'estrella', 'nube',
    'lluvia', 'fuego', 'volcan', 'montaña', 'rio',
    'arbol', 'flor', 'isla', 'desierto', 'cueva',
    'arcoiris', 'casa', 'castillo', 'hospital', 'iglesia',
    'cerro', 'selva', 'laguna', 'viento', 'rayo',
    'valle', 'arroyo',
  ],
};

// ---------------------------------------------------------------------------
// Reglas Fonéticas para Modos Especiales
// ---------------------------------------------------------------------------

/**
 * Fonética Modo Che Boludo (Argentino):
 * Las palabras con 'll' o 'y' se reemplazan por 'sh'.
 * e.g. 'playa' -> 'plasha', 'caballo' -> 'cabasho', 'lluvia' -> 'shuvia', 'llave' -> 'shave'
 */
function transformCheBoludo(word) {
  return word.toLowerCase().replace(/ll/g, 'sh').replace(/y/g, 'sh');
}

/**
 * Fonética Modo Españolete:
 * Las 'c' que suenan como 's' (antes de 'e' o 'i') y las 's' se reemplazan por 'z'.
 * e.g. 'casa' -> 'caza', 'sol' -> 'zol', 'queso' -> 'quezo', 'cocinar' -> 'cozinar'
 */
function transformEspanolete(word) {
  return word.toLowerCase().replace(/c(?=[ei])/g, 'z').replace(/s/g, 'z');
}

/**
 * Fonética Modo Chinense:
 * Las 'r' (y 'rr') se reemplazan por 'l'.
 * e.g. 'perro' -> 'pelo', 'carro' -> 'calo', 'arroz' -> 'aloz', 'guitarra' -> 'guitala', 'flor' -> 'flol'
 */
function transformChinense(word) {
  return word.toLowerCase().replace(/rr/g, 'l').replace(/r/g, 'l');
}

/**
 * Transforma una palabra según el modo especial activo.
 * @param {string} word
 * @param {string} modeId
 * @returns {string}
 */
function transformWordForMode(word, modeId) {
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
  return transformWordForMode(word, modeId).toLowerCase() !== word.toLowerCase();
}

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
 * Devuelve todas las palabras únicas del banco asegurando que no haya espacios.
 * @returns {string[]}
 */
function getAllWords() {
  const allWords = Object.values(wordBank).flat();
  return [...new Set(allWords)].map(w => w.trim().toLowerCase()).filter(w => !w.includes(' '));
}

const ALL_WORDS = getAllWords();

/**
 * Selecciona una palabra aleatoria.
 * @returns {string}
 */
function pickRandomWord() {
  const index = Math.floor(Math.random() * ALL_WORDS.length);
  return ALL_WORDS[index];
}

/**
 * Selecciona 3 palabras aleatorias distintas para que el dibujante elija.
 * @returns {string[]}
 */
function pickThreeWords() {
  const selected = new Set();
  const maxAttempts = 30;
  let attempts = 0;

  while (selected.size < 3 && attempts < maxAttempts) {
    attempts++;
    const w = ALL_WORDS[Math.floor(Math.random() * ALL_WORDS.length)];
    selected.add(w);
  }

  const fallbackList = ['arepa', 'perro', 'casa', 'bailar', 'sol'];
  for (const fb of fallbackList) {
    if (selected.size >= 3) break;
    selected.add(fb);
  }

  return [...selected].slice(0, 3);
}

/**
 * Selecciona 3 palabras transformadas fonéticamente para un modo especial específico.
 * Filtra las palabras que contengan las letras correspondientes del banco general y las transforma.
 * @param {string} modeId
 * @returns {Array<{ word: string, original: string }>}
 */
function pickThreeWordsForMode(modeId) {
  const eligible = ALL_WORDS.filter(w => isWordEligibleForMode(w, modeId));
  const pool = eligible.length >= 3 ? eligible : ALL_WORDS;

  const chosenOriginals = new Set();
  let attempts = 0;
  while (chosenOriginals.size < 3 && attempts < 40) {
    attempts++;
    const w = pool[Math.floor(Math.random() * pool.length)];
    chosenOriginals.add(w);
  }

  // Fallbacks si hicieran falta
  const fallbacks = modeId === 'che_boludo'
    ? ['playa', 'caballo', 'lluvia']
    : modeId === 'espanolete'
      ? ['casa', 'queso', 'cocinar']
      : ['perro', 'carro', 'arroz'];

  for (const fb of fallbacks) {
    if (chosenOriginals.size >= 3) break;
    chosenOriginals.add(fb);
  }

  return [...chosenOriginals].slice(0, 3).map(original => ({
    original,
    word: transformWordForMode(original, modeId),
  }));
}

/**
 * Calculates Levenshtein edit distance between two strings.
 * @param {string} a
 * @param {string} b
 * @returns {number}
 */
function levenshteinDistance(a, b) {
  const an = a ? a.length : 0;
  const bn = b ? b.length : 0;
  if (an === 0) return bn;
  if (bn === 0) return an;
  const matrix = Array.from({ length: bn + 1 }, () => new Array(an + 1));
  for (let i = 0; i <= an; i++) matrix[0][i] = i;
  for (let j = 0; j <= bn; j++) matrix[j][0] = j;
  for (let j = 1; j <= bn; j++) {
    for (let i = 1; i <= an; i++) {
      matrix[j][i] = b[j - 1] === a[i - 1]
        ? matrix[j - 1][i - 1]
        : Math.min(matrix[j - 1][i - 1] + 1, matrix[j][i - 1] + 1, matrix[j - 1][i] + 1);
    }
  }
  return matrix[bn][an];
}

/**
 * Checks if a normalized guess is close to the secret target word (or untransformed original).
 * @param {string} guess - normalized
 * @param {string} targetWord - normalized
 * @param {string} [originalWord] - optional normalized original word in special mode
 * @returns {boolean}
 */
function isCloseGuess(guess, targetWord, originalWord) {
  if (!guess || !targetWord) return false;
  const g = guess.toLowerCase().trim();
  const t = targetWord.toLowerCase().trim();
  if (!g || !t || g === t) return false;

  // If in special mode and typed original word exactly
  if (originalWord) {
    const orig = originalWord.toLowerCase().trim();
    if (g === orig) return true;
  }

  // Short words (<= 3 chars): only if one contains the other with length diff of 1
  if (t.length <= 3) {
    return Math.abs(g.length - t.length) === 1 && (g.startsWith(t) || t.startsWith(g));
  }

  const dist = levenshteinDistance(g, t);
  const maxAllowed = t.length <= 7 ? 1 : 2;
  if (dist > 0 && dist <= maxAllowed) return true;

  if (originalWord) {
    const orig = originalWord.toLowerCase().trim();
    if (orig.length > 3) {
      const origDist = levenshteinDistance(g, orig);
      const origMax = orig.length <= 7 ? 1 : 2;
      if (origDist <= origMax) return true;
    }
  }

  return false;
}

module.exports = {
  wordBank,
  SPECIAL_MODES,
  getAllWords,
  pickRandomWord,
  pickThreeWords,
  pickThreeWordsForMode,
  transformWordForMode,
  isWordEligibleForMode,
  levenshteinDistance,
  isCloseGuess,
};
