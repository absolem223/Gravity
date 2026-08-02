# docs/specs/ — FUNCTIONAL GAME SPECIFICATIONS (SPECs)

Las **Specifications (SPECs)** son los documentos funcionales y técnicos de cada sistema del juego, organizados por **Dominios Funcionales**.

## 📌 Propósito

Las SPECs son la Fuente Única de Verdad (SSOT) funcional del juego. Ningún módulo de gameplay se implementa en `game/modules/` sin una SPEC aprobada previamente en este directorio.

---

## 🏗️ Organización por Dominios Funcionales

- `design_pillars.md`: Pilares de diseño, tono y reglas fundamentales de GRAVITY.

### 🎮 1. Core Gameplay
- `core/main_loop.md`: Ciclo de partida y máquina de estados global.
- `core/controls.md`: Mapeo de entradas, esquemas de control y buffer de comandos.
- `core/interaction.md`: Sistema genérico de interacción con entidades del mundo.

### 🏃 2. Player
- `player/movement.md`: Locomoción, físicas, inercia y colisiones.
- `player/exoskeleton.md`: Exoesqueletos, atributos y habilidades.

### ⚔️ 3. Combat
- `combat/combat.md`: Balística, hitscan, hitbox/hurtbox y mitigación de daño.

### 🤖 4. Drones
- `drones/drone.md`: IA de asistencia, órdenes, batería y vinculación.

### 🗺️ 5. World
- `world/map.md`: Geometría, navegación, spawn points y destructibilidad.
- `world/vision_cone.md`: Mecánica de cono de visión y Línea de Visión (LoS).
- `world/hack.md`: Hackeo de terminales, puertas y dispositivos.

### 🏆 6. Match
- `match/matchmaking.md`: Lobbies, salas autoritativas y sesiones.

### 📈 7. Progression
- `progression/progression.md`: Meta-progresión, recompensas y desbloqueables.

### 🌐 8. Network
- `network/network_relevance.md`: Interest Management, filtros de replicación y relevancia de red.

### 🖥️ 9. UI
- `ui/ui.md`: Arquitectura de UI, HUD, menús y reactividad de estado.

### 📊 10. Content
- `content/content_schema.md`: Tablas de datos, esquemas de balance y formato de recursos.
