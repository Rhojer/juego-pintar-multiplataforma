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
  acciones: [
    'bailar', 'correr', 'dormir', 'llorar', 'cantar',
    'nadar', 'cocinar', 'saltar', 'comer', 'pintar',
    'reir', 'barrer', 'peinar', 'manejar', 'escribir',
    'volar', 'pescar', 'boxear', 'limpiar', 'patinar',
    'gritar', 'besar', 'abrazar', 'cortar', 'lavar',
  ],

  // Comida, frutas y platos venezolanos/latinos
  comida: [
    'arepa', 'empanada', 'cachapa', 'tequeño', 'hallaca',
    'mango', 'cambur', 'piña', 'manzana', 'fresa',
    'naranja', 'limon', 'sandia', 'aguacate', 'platano',
    'pizza', 'hamburguesa', 'huevo', 'queso', 'pan',
    'torta', 'helado', 'galleta', 'sopa', 'tajadas',
    'chocolate', 'chicha', 'papelon', 'guarapo', 'mandoca',
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
  ],

  // Naturaleza, clima y lugares
  naturaleza: [
    'playa', 'sol', 'luna', 'estrella', 'nube',
    'lluvia', 'fuego', 'volcan', 'montaña', 'rio',
    'arbol', 'flor', 'isla', 'desierto', 'cueva',
    'arcoiris', 'casa', 'castillo', 'hospital', 'iglesia',
    'cerro', 'selva', 'laguna', 'viento', 'rayo',
  ],
};

/**
 * Devuelve todas las palabras únicas del banco asegurando que no haya espacios.
 * @returns {string[]}
 */
function getAllWords() {
  const allWords = Object.values(wordBank).flat();
  // Filtro estricto: sin espacios y en minúsculas
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

  // Si por alguna razón no llena 3, rellenar con palabras seguras
  const fallbackList = ['arepa', 'perro', 'casa', 'bailar', 'sol'];
  for (const fb of fallbackList) {
    if (selected.size >= 3) break;
    selected.add(fb);
  }

  return [...selected].slice(0, 3);
}

module.exports = {
  wordBank,
  getAllWords,
  pickRandomWord,
  pickThreeWords,
};
