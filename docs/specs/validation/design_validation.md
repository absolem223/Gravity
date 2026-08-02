# SPEC VALIDATION: DESIGN VALIDATION — AUDITORÍA DE DECISIONES Y PILARES

- **Estado**: Actualizado / Revisión 2.0 (Fase 0.5 — Validación y Profundización)
- **Ubicación**: `docs/specs/validation/design_validation.md`

---

## 🎯 Objetivo de la Auditoría

Mantener el control absoluto de la visión arquitectónica de **PROJECT GRAVITY**, clasificando las decisiones en **Confirmadas (Inmutables)** y **Abiertas (En Profundización)**.

---

## 🔒 DECISIONES CONFIRMADAS (Inmutables)

Las siguientes decisiones forman parte de la identidad fundamental de GRAVITY y no pueden ser alteradas sin un RFC aprobado con justificación extrema:

1. **La Información como Recurso Principal**:
   - Disparar o avanzar sin información previa de niebla de guerra es un error táctico letal. El Tiempo para Matar (TTK) frontal sin información es elevado.
2. **El Dron como Extensión Permanente del Operador**:
   - El jugador es la Tríada Táctica: *Operador Humano + Exoesqueleto + Dron Permanente*.
   - El Dron no es una habilidad con cooldown, ni una mascota, ni un gadget descartable.
3. **Objetivo Basado en Control Tecnológico del Núcleo IA**:
   - El objetivo es una operación tecnológica continuada por control territorial en el perímetro del Núcleo, NO un "plantar bomba" ni un *Team Deathmatch*.
4. **La Cooperación es Superior al Héroe Individual**:
   - Cero mecánicas de "Press Button to Win" o "Lone Wolf Carry". Ningún operador es autosuficiente.

---

## 🔓 DECISIONES ABIERTAS (En Proceso de Profundización)

Las siguientes áreas continúan abiertas para experimentación y ajuste durante la Fase 0.5 y prototipado en `sandbox/`:

1. **Economía Exacta de Piezas y Componentes**:
   - Ratio exacto de caída de piezas entre nodos del mapa vs drones destruidos (documentado en `drone_resource_economy.md`).
2. **Progresión de Drones en Partida**:
   - Árbol de mejoras y variantes de drones elegibles durante la síntesis en puntos de reabastecimiento.
3. **Variantes de Operadores y Especificación de Kits**:
   - Definición final de la lista de operadores de lanzamiento bajo las 5 preguntas obligatorias de `operator_design_rules.md`.
4. **Balance entre Autonomía y Control Directo del Dron**:
   - Proporción de uso entre el Modo Escolta (Autónomo) y el Modo Piloto (Control Directo vulnerable).

---

## 📊 Matriz de Auditoría por Sistema

### 1. Sistema de Movimiento y Combate (`combat_system.md`)
- **Pilar que Refuerza**: *Pilar 1 (Información)*, *Pilar 4 (Terreno)* y *Pilar 5 (Cooperación)*.
- **Decisión Confirmada**: La supresión de fuego y la Niebla de Guerra bloquean la efectividad de tiradores mecánicos puros.

### 2. Sistema de Drones y Economía (`drone_design_rules.md` & `drone_resource_economy.md`)
- **Pilar que Refuerza**: *Pilar 1 (Información)* y *Pilar 4 (El terreno decide)*.
- **Decisión Confirmada**: La pérdida del dron exige recolección física de piezas en el mapa (Scrap Zones) para su síntesis.

### 3. Sistema del Núcleo IA (`objective_system.md`)
- **Pilar que Refuerza**: *Pilar 3 (El objetivo es el Núcleo)*.
- **Decisión Confirmada**: La transferencia exige presencia de red y control territorial en el perímetro.
