# docs/specs/ — FUNCTIONAL GAME SPECIFICATIONS (SPECs)

Las **Specifications (SPECs)** son los documentos funcionales y técnicos de cada sistema del juego, organizados por **Dominios Funcionales** y **Fase de Validación**.

## 📌 Propósito

Las SPECs son la Fuente Única de Verdad (SSOT) funcional del juego. Ningún módulo de gameplay se implementa en `game/modules/` sin una SPEC aprobada previamente en este directorio.

---

## 📈 Progresión Tecnológica (`docs/specs/progression/`)

- [technology_generation_system.md](file:///E:/GRAVITY/docs/specs/progression/technology_generation_system.md): Sistema de Generaciones Tecnológicas (Gen 1 ➔ Gen 2 ➔ Gen 3), Centros de Integración, Recursos de Evolución vs Mantenimiento y Efectos de Red.

---

## 🔍 Validaciones y Profundización de Diseño (`docs/specs/validation/`)

- [design_validation.md](file:///E:/GRAVITY/docs/specs/validation/design_validation.md): Auditoría de decisiones confirmadas vs abiertas y pilares.
- [drone_design_rules.md](file:///E:/GRAVITY/docs/specs/validation/drone_design_rules.md): Reglas del sistema de drones (Tríada Táctica, extensión permanente, recuperación por piezas y evolución por Generaciones).
- [drone_resource_economy.md](file:///E:/GRAVITY/docs/specs/validation/drone_resource_economy.md): Economía de piezas, separación de recursos de evolución vs mantenimiento y anti-snowball.
- [player_experience.md](file:///E:/GRAVITY/docs/specs/validation/player_experience.md): Definición de la experiencia emocional, UX y GRAVITY vs shooters tradicionales.
- [match_flow_spec.md](file:///E:/GRAVITY/docs/specs/validation/match_flow_spec.md): Flujo completo de partida, mecanismos anti-camping y anti-snowball.
- [operator_design_rules.md](file:///E:/GRAVITY/docs/specs/validation/operator_design_rules.md): Reglas obligatorias para diseñar operadores futuros (Cuestionario de 5 preguntas).
- [technical_requirements_preview.md](file:///E:/GRAVITY/docs/specs/validation/technical_requirements_preview.md): Vista previa de subsistemas técnicos requeridos a futuro.

---

## 🏛️ Documento Maestro de Pilares
- [design_pillars.md](file:///E:/GRAVITY/docs/specs/design_pillars.md): Los 5 pilares irrenunciables.

---

## 🏗️ Organización por Dominios Funcionales

### 🎮 1. Core Gameplay
- `core/main_loop.md`: Ciclo de partida y máquina de estados global.
- `core/controls.md`: Mapeo de entradas, esquemas de control y buffer de comandos.
- `core/interaction.md`: Sistema genérico de interacción con entidades del mundo.

### 🏃 2. Player
- `player/movement.md`: Locomoción, físicas, inercia y colisiones.
- `player/exoskeleton.md`: Exoesqueletos, atributos y habilidades.
- `player/operators_system.md`: Trinomio Operador + Exoesqueleto + Dron.
- `player/team_roles.md`: Roles tácticos, Generaciones y Efectos de Red.

### ⚔️ 3. Combat
- `combat/combat_system.md`: Balística, hitscan, supresión y ecuación de 5 variables.

### 🤖 4. Drones
- `drones/drone.md`: IA de asistencia, órdenes, batería y vinculación.

### 🗺️ 5. World
- `world/map_design_guidelines.md`: Capas de movilidad, conductos de drones y Centros de Integración Tecnológica.
- `world/vision_cone.md`: Mecánica de cono de visión y Línea de Visión (LoS).
- `world/hack.md`: Hackeo de terminales, puertas y dispositivos.

### 🏆 6. Match
- `match/objective_system.md`: Fases de captura del Núcleo IA, Centros Tecnológicos y control territorial.
- `match/matchmaking.md`: Lobbies, salas autoritativas y sesiones.

### 🖥️ 7. UI
- `ui/ui.md`: Arquitectura de UI, HUD, menús y reactividad de estado.

### 📊 8. Content
- `content/content_schema.md`: Tablas de datos, esquemas de balance y formato de recursos.
