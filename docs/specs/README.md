# docs/specs/ — FUNCTIONAL GAME SPECIFICATIONS (SPECs)

Las **Specifications (SPECs)** son los documentos funcionales y técnicos de cada sistema del juego, organizados por **Dominios Funcionales** y **Fase de Validación**.

## 📌 Propósito

Las SPECs son la Fuente Única de Verdad (SSOT) funcional del juego. Ningún módulo de gameplay se implementa en `game/modules/` sin una SPEC aprobada previamente en este directorio.

---

## 🏛️ Documento Maestro de Pilares
- [design_pillars.md](file:///E:/GRAVITY/docs/specs/design_pillars.md): Los 5 pilares irrenunciables de GRAVITY.

---

## 📈 Progresión Tecnológica (`docs/specs/progression/`)
- [technology_generation_system.md](file:///E:/GRAVITY/docs/specs/progression/technology_generation_system.md): Generaciones Tecnológicas (Gen 1 → 2 → 3), Doctrinas, Centros de Integración y Efectos de Red.
- [match_pacing_and_technology_timeline.md](file:///E:/GRAVITY/docs/specs/progression/match_pacing_and_technology_timeline.md): Ritmo emocional de partida, tiempos de referencia por Generación y mecanismos anti-riesgo.

---

## 🔍 Validaciones y Profundización de Diseño (`docs/specs/validation/`)
- [design_validation.md](file:///E:/GRAVITY/docs/specs/validation/design_validation.md): Auditoría de pilares — Decisiones Confirmadas vs Abiertas. **Rev 6.0 — Cierre de Fase 0.5**
- [full_match_simulation.md](file:///E:/GRAVITY/docs/specs/validation/full_match_simulation.md): Simulación conceptual de partida completa (38 min, 4v4) con validación de pilares y detección de problemas.
- [full_match_simulation_gen3.md](file:///E:/GRAVITY/docs/specs/validation/full_match_simulation_gen3.md): Simulación Gen 3 (43 min, 4v4) — Efectos de Red, interacción de Doctrinas y validación final de Pilares.
- [sandbox_corrections_review.md](file:///E:/GRAVITY/docs/specs/validation/sandbox_corrections_review.md): 4 correcciones formalizadas post-simulación.
- [drone_design_rules.md](file:///E:/GRAVITY/docs/specs/validation/drone_design_rules.md): Tríada Táctica, extensión permanente, Generaciones del Dron y sistema de recuperación.
- [drone_resource_economy.md](file:///E:/GRAVITY/docs/specs/validation/drone_resource_economy.md): Economía de piezas por fase de partida, flujos de Mantenimiento vs Evolución.
- [match_flow_spec.md](file:///E:/GRAVITY/docs/specs/validation/match_flow_spec.md): Flujo cronológico completo integrado con las 3 Generaciones, anti-camping y anti-snowball.
- [player_experience.md](file:///E:/GRAVITY/docs/specs/validation/player_experience.md): Experiencia emocional, UX y GRAVITY vs shooters tradicionales.
- [operator_design_rules.md](file:///E:/GRAVITY/docs/specs/validation/operator_design_rules.md): Cuestionario Mandatory de 5 preguntas y anti-patrones de operadores.
- [technical_requirements_preview.md](file:///E:/GRAVITY/docs/specs/validation/technical_requirements_preview.md): Requisitos técnicos del Vertical Slice por sistema, arquitectura de módulos GDScript y decisiones técnicas previas al código. **Rev 2.0**

---

## 📊 Fase 1 — Vertical Slice Design (`docs/specs/vertical_slice/`)
- [vertical_slice_scope.md](file:///E:/GRAVITY/docs/specs/vertical_slice/vertical_slice_scope.md): Alcance del primer prototipo jugable. 4 operadores prototipo, Dron Gen 1, Mapa SANDBOX-01, Núcleo IA. **DT-01 ✅ Cerrada (Top-Down Isométrica)**.
- [vertical_slice_validation_plan.md](file:///E:/GRAVITY/docs/specs/vertical_slice/vertical_slice_validation_plan.md): 12 preguntas de validación con criterios de aprobación/fallo y plantilla de playtest.
- [vertical_slice_implementation_plan.md](file:///E:/GRAVITY/docs/specs/vertical_slice/vertical_slice_implementation_plan.md): Plan de implementación con **alcance congelado** — 9 etapas ordenadas por dependencias.
- [vertical_slice_success_criteria.md](file:///E:/GRAVITY/docs/specs/vertical_slice/vertical_slice_success_criteria.md): Contrato de evaluación — criterio principal, matriz de evidencia por pilar, 7 fallos críticos (FC-01 a FC-07) y límites prototipo/producto.
- [local_coop_implementation_notes.md](file:///E:/GRAVITY/docs/specs/vertical_slice/local_coop_implementation_notes.md): Notas de implementación de multijugador local cooperativo.
- [spatial_coop_test_results.md](file:///E:/GRAVITY/docs/specs/vertical_slice/spatial_coop_test_results.md): Resultados del test espacial de combate y coberturas (Etapa 3).
- [drone_validation_test_results.md](file:///E:/GRAVITY/docs/specs/vertical_slice/drone_validation_test_results.md): Resultados de los 6 tests obligatorios de validación del Dron Gen 1 (Etapa 4).

---

## 🏗️ Organización por Dominios Funcionales

### 🎮 1. Core Gameplay
- `core/core_game_loop.md`: Ciclo de partida en 4 fases.
- `core/controls.md`: Mapeo de entradas y buffer de comandos.
- `core/interaction.md`: Sistema genérico de interacción con el mundo.

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
- `world/map_design_guidelines.md`: Capas de movilidad, conductos, Centros de Integración y LoS.
- `world/vision_cone.md`: Mecánica de cono de visión y Línea de Visión (LoS).
- `world/hack.md`: Hackeo de terminales, puertas y dispositivos.

### 🏆 6. Match
- [objective_system.md](file:///E:/GRAVITY/docs/specs/match/objective_system.md): Núcleo IA — persistencia parcial de hackeo, estados Activo/Contestado/Degradación, Centros Tecnológicos. **Rev 4.0**
- `match/matchmaking.md`: Lobbies, salas autoritativas y sesiones.

### 🖥️ 7. UI
- `ui/ui.md`: Arquitectura de UI, HUD, menús y reactividad de estado.

### 📊 8. Content
- `content/content_schema.md`: Tablas de datos, esquemas de balance y formato de recursos.
