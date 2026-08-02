# SPEC: CORE GAME LOOP — CICLO PRINCIPAL DE PARTIDA (4 vs 4)

- **Estado**: Propuesto (Fase 0.5 — Game Architecture)
- **Dominio**: Core Gameplay
- **Ubicación**: `docs/specs/core/core_game_loop.md`

---

## 🎯 Visión General del Game Loop

GRAVITY es una experiencia de combate táctico 4 vs 4 basada en rondas o sesiones donde dos escuadras compiten por el control, hackeo y estabilización del **Núcleo IA**.

El ciclo de partida prioriza la adquisición de información, el posicionamiento en el terreno y la sincronización con los drones por encima del combate directo o los reflejos puros.

---

## 🔄 Las 4 Fases de una Partida

```
┌─────────────────────────────────────────────────────────────┐
│ 1. RECONOCIMIENTO Y PLANIFICACIÓN (Fase Silenciosa)          │
│    - Despliegue de drones de scouting                      │
│    - Mapeo de niebla de guerra y firmas térmicas           │
│    - Selección de rutas de aproximación                    │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. DESPLIEGUE TÁCTICO Y CONTROL TERRITORIAL                 │
│    - Toma de puntos clave del terreno                       │
│    - Establecimiento de líneas de visión defensivas         │
│    - Interrupción de la red y hackeo de cobertura           │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. CONFLICTO Y SECUENCIA DE HACKEO DEL NÚCLEO IA            │
│    - Inserción del protocolo de hackeo en el Núcleo         │
│    - Perímetro defensivo activo / Interrupción enemiga     │
│    - Transferencia autoritativa de datos del Núcleo         │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. RESOLUCIÓN Y CONSOLIDACIÓN                               │
│    - Consolidación del control / Sobrecarga del Núcleo     │
│    - Evaluación de desempeño táctico y de escuadra          │
└─────────────────────────────────────────────────────────┘
```

---

## 🎮 Flujo Detallado del Jugador (Player Journey)

### Fase 1: Reconocimiento y Planificación
1. **Despliegue de Drones**: Al iniciar la partida, los operadores lanzan o controlan sus drones de asistencia para mapear el mapa cubierto por Niebla de Guerra.
2. **Recolección de Inteligencia**: Los jugadores identifican la ubicación exacta del Núcleo IA (que puede variar de posición en cada partida o ronda), así como trampas y firmas de red enemigas.
3. **Toma de Decisiones Estratégicas**: La escuadra decide si realizará una aproximación dividida (*pincer movement*) o una concentración de fuerza (*stack push*).

### Fase 2: Despliegue Táctico y Control Territorial
1. **Avance en Formación**: Los jugadores avanzan utilizando coberturas. El operador al frente cubre ángulos con su exoesqueleto y el dron del operador de retaguardia escanea flancos.
2. **Combate por Posición**: Los enfrentamientos armados ocurren para denegar o capturar zonas elevadas o pasillos estratégicos. La munición y los recursos tecnológicos son finitos.
3. **Hackeo de Entorno**: Desactivación de puertas de acceso, hackeo de torretas de seguridad o alteración de la visibilidad del mapa.

### Fase 3: Conflicto y Secuencia de Hackeo del Núcleo IA
1. **Inicio del Hackeo**: Un jugador (o su dron especializado) debe vincularse físicamente al Núcleo IA para iniciar la transferencia de datos.
2. **Creación del Perímetro Defensivo**: Durante el hackeo, el Núcleo emite un campo electromagnético. La escuadra atacante debe defender al operador que hackea, mientras la escuadra defensora intenta interrumpir el enlace.
3. **Escalada de Tensión**: El tiempo de transferencia genera una barra de progreso visible para ambos equipos, forzando la convergencia del combate hacia la sala del Núcleo.

### Fase 4: Resolución y Consolidación
1. **Condición de Victoria Primaria**: Completar el 100% de la secuencia de hackeo del Núcleo IA o mantener el control total del área durante el tiempo límite.
2. **Condición de Victoria Secundaria**: Denegación total del tiempo al equipo enemigo mediante control territorial.
3. **Cero Victoria por Elimination**: Eliminar a los 4 operadores enemigos NO otorga la victoria automática si la secuencia del Núcleo enemigo está por completar su ciclo y no es interrumpida.

---

## 🧠 Decisiones Estratégicas Clave durante la Partida

- **¿Gastar energía del Dron en reconocimiento temprano o guardarla para combate?**
- **¿Avance sigiloso manteniendo niebla de guerra o avance agresivo revelando posición?**
- **¿Hackear infraestructuras secundarias (puertas/cámaras) o avanzar directo al Núcleo?**
- **¿Sacrificar un operador para asegurar el progreso del Núcleo o replegarse y reorganizar?**

---

## ⚖️ Auditoría contra los 5 Pilares de Diseño

1. **Pilar 1 (La información es el recurso más valioso)**: Cumplido. La Fase 1 de Reconocimiento dicta la estrategia de entrada. Quien no recopila información ingresa a ciegas y es emboscado.
2. **Pilar 2 (El jugador nunca combate solo)**: Cumplido. La secuencia de hackeo del Núcleo exige que un jugador hackee mientras la escuadra y los drones cubren sus ángulos.
3. **Pilar 3 (El objetivo es controlar el núcleo, no eliminar enemigos)**: Cumplido. La eliminación de enemigos no finaliza la partida; el foco absoluto es la barra de transferencia del Núcleo.
4. **Pilar 4 (El terreno decide la batalla)**: Cumplido. El control de chokepoints y zonas elevadas determina la viabilidad de la Fase 2 y 3.
5. **Pilar 5 (La cooperación supera al héroe individual)**: Cumplido. Un único jugador no puede simultáneamente hackear el Núcleo y cubrir sus 360 grados de línea de visión.
