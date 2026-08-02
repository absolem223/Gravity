# SPEC VALIDATION: DESIGN VALIDATION — AUDITORÍA DE PILARES Y DECISIONES

- **Estado**: Aprobado (Fase 0.5 — Validación y Profundización)
- **Ubicación**: `docs/specs/validation/design_validation.md`

---

## 🎯 Objetivo de la Auditoría

Evaluar todos los sistemas funcionales diseñados en GRAVITY (`core_game_loop`, `operators_system`, `combat_system`, `objective_system`, `map_design_guidelines`, `team_roles`) contra los 5 Pilares de Diseño Irrenunciables.

El propósito es garantizar que ningún sistema se degenere en un "shooter con habilidades", sino que sostenga un juego táctico puro basado en información, posicionamiento y coordinación.

---

## 📊 Matriz de Auditoría por Sistema

### 1. Sistema de Movimiento y Combate (`combat_system.md`)
- **Pilar que Refuerza**: *Pilar 1 (Información)*, *Pilar 4 (Terreno)* y *Pilar 5 (Cooperación)*.
- **Riesgo de Contradicción**: Que los jugadores de alto nivel técnico intenten depender de puntería pura (*reflex headshots*) ignorando la supresión de fuego y la Niebla de Guerra.
- **Decisión Bloqueada (Inmutable)**:
  - Cero tiro de precisión instantáneo en carrera o salto. La supresión de fuego distorsiona la mira obligatoriamente.
  - El Tiempo para Matar (TTK) frontal sin información de dron es significativamente elevado.
- **Pregunta Abierta de Diseño**:
  - ¿Debe la supresión reducir también el ángulo de cono de visión del jugador en pantalla (efecto túnel), o solo distorsionar el visor electrónico?

---

### 2. Sistema de Operadores y Exoesqueletos (`operators_system.md`)
- **Pilar que Refuerza**: *Pilar 2 (El jugador nunca combate solo)* y *Pilar 5 (La cooperación supera al héroe)*.
- **Riesgo de Contradicción**: Diseñar operadores "autónomos y autosuficientes" que puedan curarse, revelar mapa, abrir brechas y disparar con alta potencia de forma aislada (*Lone Wolf Syndrome*).
- **Decisión Bloqueada (Inmutable)**:
  - Todo operador TIENE que depender de la información o cobertura de un aliado para ser 100% efectivo.
  - Las habilidades consume la misma fuente de energía compartida que el Dron.
- **Pregunta Abierta de Diseño**:
  - ¿Debería la sobrecarga de energía del exoesqueleto inhabilitar al dron durante 3 segundos como penalización de uso desmedido?

---

### 3. Sistema del Dron de Asistencia (`drone_design_rules.md`)
- **Pilar que Refuerza**: *Pilar 1 (La información es el recurso más valioso)* y *Pilar 2 (Nunca combate solo)*.
- **Riesgo de Contradicción**: Convertir al Dron en una "mascota pasiva" o en una "torreta automática de daño" que combate por el jugador sin requerir decisiones tácticas.
- **Decisión Bloqueada (Inmutable)**:
  - El dron NO es un arma de daño primario; es un sensor de red, perturbador y extensión de la vista.
  - La destrucción del dron genera una penalización temporal de información severa.
- **Pregunta Abierta de Diseño**:
  - ¿Debe el dron emitir un zumbido de audio audible a través de las paredes cuando está en modo escaneo de alta frecuencia?

---

### 4. Sistema del Núcleo IA (`objective_system.md`)
- **Pilar que Refuerza**: *Pilar 3 (El objetivo es el Núcleo, no eliminar enemigos)*.
- **Riesgo de Contradicción**: Que las escuadras ignoren el Núcleo y jueguen la partida como un *Team Deathmatch* tradicional hasta agotar el tiempo.
- **Decisión Bloqueada (Inmutable)**:
  - Eliminar al equipo enemigo no otorga la victoria si el Núcleo enemigo está a punto de completar la transferencia y no es desactivado a tiempo.
  - El avance de la barra del Núcleo exige presencia física/lógica en el perímetro.
- **Pregunta Abierta de Diseño**:
  - ¿Debería el equipo que va perdiendo recibir un impulso de velocidad de hackeo si logra ingresar al perímetro en los últimos 30 segundos?

---

### 5. Guía de Diseño de Mapas (`map_design_guidelines.md`)
- **Pilar que Refuerza**: *Pilar 4 (El terreno decide la batalla)*.
- **Riesgo de Contradicción**: Diseñar arenas abiertas o mapas tipo "tres carriles rectos de MOBA" donde la geometría no influya en las líneas de visión.
- **Decisión Bloqueada (Inmutable)**:
  - Existen conductos exclusivos para Drones en cada sala principal del mapa.
  - Cero líneas de visión directas de más de 30 metros sin elementos de oclusión.
- **Pregunta Abierta de Diseño**:
  - ¿Debería la destructibilidad del entorno ser permanente durante toda la partida o reparable por terminales de ingeniería?
