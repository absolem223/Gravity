# PIXEL ART & ASSET GUIDELINES — GUÍA DE ESTILOS Y IMPORTACIÓN

Directrices para arte 2D, texturas, spritesheets e importación en el motor.

---

## 🎨 Parámetros de Importación de Texturas

1. **Texture Filtering**: Usar `Nearest` (Nearest Neighbor) por defecto para prevenir difuminado de píxeles.
2. **Compress Mode**: `Lossless` para spritesheets de personajes y elementos de UI.
3. **Mipmaps**: Desactivar mipmaps en assets 2D pixel art para evitar artefactos visuales a distintas distancias de cámara.
4. **Grid Alignment**: Spritesheets alineados a grilla potencia de 2 (ej. 16x16, 32x32, 64x64).
