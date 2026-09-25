# 🎨 Rayando 🇻🇪

Juego multijugador de dibujo y adivinanzas en tiempo real con temáticas y jerga venezolana (inspirado en Pinturillo).

## 🚀 Arquitectura

El proyecto es multiplataforma y comparte el mismo servidor en tiempo real:

- **`server/`**: Servidor Node.js + Express + Socket.io (desplegado con PM2).
- **`app/`**: Cliente multiplataforma (Móvil & Web) en Flutter con Riverpod y soporte para canvas interactivo.

## 🕹️ Características

- **Salas Públicas y Privadas** con códigos de sala.
- **Banco de palabras criollas**: Comidas (Arepa, Tequeño, Cachapa), lugares (Ávila, Roraima), expresiones y fauna venezolana.
- **Lienzo de dibujo en tiempo real** optimizado para bajo consumo de ancho de banda.
- **Puntuación dinámica** según rapidez para adivinar y bonos para el dibujante.

## 🌐 Conexión

- **Servidor Activo**: `http://162.35.173.35:3001` (o proxy en puerto 80)
