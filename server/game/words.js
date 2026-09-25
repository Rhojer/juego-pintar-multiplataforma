/**
 * words.js
 * Venezuelan-themed word bank for Rayando.
 * Words are organized by category so future features (category voting) are easy to add.
 */

const wordBank = {
  comida: [
    'arepa', 'hallaca', 'cachapa', 'tequeño', 'pabellón criollo',
    'caraotas', 'tajadas', 'papelón', 'guarapo', 'chicha',
    'mandoca', 'empanada', 'pasticho', 'pepito', 'perro caliente',
    'hervido', 'sancocho', 'tostones', 'asado negro', 'bienmesabe',
    'quesillo', 'golfeado', 'pan de jamón', 'polvorosa', 'besitos de coco',
    'majarete', 'cazuela marinera', 'crema de auyama', 'morcilla', 'chorizos',
  ],

  jerga: [
    'chévere', 'pana', 'vaina', 'arrecho', 'chamo',
    'chamito', 'corotos', 'broma', 'chiva', 'gandola',
    'musiú', 'catire', 'pargo', 'mamar gallo', 'echar paja',
    'sifrino', 'chiroso', 'perolero', 'arrechera', 'pichirre',
    'bululú', 'chévere', 'leche', 'ladilla', 'vergación',
    'a la orden', 'eso sí está', 'me cae gordo', 'está pelabola', 'qué molleja',
  ],

  lugares: [
    'Caracas', 'Maracaibo', 'Valencia', 'Barquisimeto', 'Maturín',
    'Margarita', 'Los Roques', 'El Ávila', 'Morrocoy', 'Canaima',
    'Mérida', 'Cumaná', 'Ciudad Bolívar', 'Puerto Ordaz', 'Maracay',
    'Paraguana', 'Salto Ángel', 'Orinoco', 'Río Negro', 'Llanos',
  ],

  animales: [
    'turpial', 'tonina', 'baquiro', 'chigüire', 'cunaguaro',
    'flamenco', 'guacamaya', 'morrocoy', 'caiman', 'anaconda',
    'perro de agua', 'corocoro', 'lapa', 'danta', 'oso palmero',
    'perico', 'garza', 'cachicamo', 'manatí', 'nutria',
  ],

  cultura: [
    'joropo', 'cuatro', 'arpa', 'maracas', 'tambor',
    'gaita', 'Miss Venezuela', 'béisbol', 'pelota', 'papelón con limón',
    'carnaval', 'Simón Bolívar', 'bandola', 'joropo llanero', 'velorio',
    'parranda', 'diablos danzantes', 'Semana Santa', 'feria de la Chinita', 'retreta',
  ],

  objetos: [
    'budare', 'corotos', 'hamaca', 'chinchorro', 'totuma',
    'pilón', 'metate', 'sebucán', 'tinaja', 'catumare',
    'cesta', 'guayuco', 'mapire', 'alpargatas', 'sombrero llanero',
  ],

  naturaleza: [
    'tepuy', 'sabana', 'selva', 'manglares', 'delta',
    'cerro', 'laguna', 'río', 'fila', 'cueva',
    'playa', 'arrecife', 'médano', 'morichal', 'caño',
  ],

  deportes: [
    'béisbol', 'softbol', 'boxeo', 'ciclismo', 'natación',
    'voleibol', 'baloncesto', 'fútbol', 'taekwondo', 'levantamiento de pesas',
  ],
};

/**
 * Returns a flat array of all words across every category,
 * with duplicates removed (some words appear in multiple categories intentionally).
 * @returns {string[]}
 */
function getAllWords() {
  const allWords = Object.values(wordBank).flat();
  return [...new Set(allWords)];
}

module.exports = { wordBank, getAllWords };
