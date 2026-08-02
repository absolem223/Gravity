# SPEC: OBJECTIVE SYSTEM — REVISIÓN 4.0: OPERACIÓN TECNOLÓGICA CON PERSISTENCIA

- **Estado**: Actualizado / Revisión 4.0 (Fase 0.5 — Game Architecture)
- **Dominio**: Match & Objective
- **Ubicación**: `docs/specs/match/objective_system.md`

---

## 🎯 El Núcleo IA: Operación Tecnológica Continuada

El hackeo del Núcleo IA en GRAVITY es una **Operación Tecnológica Continuada y Reactiva**, no un temporizador estático de "plantar bomba". Se sostiene por **Presencia de Red en el Perímetro** — el operador puede moverse, disparar y cubrirse dentro de la zona de enlace.

---

## 🔄 Sistema de Progreso con Persistencia Parcial (Corrección 1 Post-Simulación)

La barra de descarga del Núcleo IA opera bajo tres estados dinámicos. Este sistema evita el reinicio punitivo completo detectado en la simulación y refuerza que el avance acumulado tiene valor real.

```
┌─────────────────────────────────────────────────────────────────────┐
│ ESTADO ACTIVO (Avanzando)                                           │
│ Condición: Mayoría de presencia de red atacante en el perímetro.   │
│ Efecto: La barra de descarga avanza progresivamente.               │
├─────────────────────────────────────────────────────────────────────┤
│ ESTADO CONTESTADO (Congelado)                                       │
│ Condición: Presencia equivalente de ambas escuadras en el perímetro.│
│ Efecto: La descarga se pausa. Máxima tensión táctica.              │
├─────────────────────────────────────────────────────────────────────┤
│ ESTADO DEGRADACIÓN (Cayendo — NO Reinicio)                          │
│ Condición: Mayoría de presencia defensora en el perímetro.         │
│ Efecto: La barra cae -10% cada 30 segundos continuos de control    │
│ defensor. Al superar el 50%, la tasa se reduce a -5%/30 seg.      │
└─────────────────────────────────────────────────────────────────────┘
```

### Reglas del Sistema de Persistencia

1. **Recuperación táctica posible**: Si la escuadra atacante reconquista el perímetro antes de que la barra llegue a 0%, retoma la descarga desde el porcentaje actual.
2. **Umbral de retención al 50%**: Superar la mitad de la descarga es un hito significativo — la degradación se vuelve más lenta, dando más tiempo para recuperar el control.
3. **Descarga no puede permanecer indefinidamente en 0% por congelación**: Si el atacante mantiene presencia en el perímetro, la descarga avanza. Solo se congela en Estado Contestado genuino.

---

## 🏢 Ecosistema de Objetivos del Mapa

El mapa contiene dos categorías de objetivos interconectados:

1. **El Objetivo Primario (Núcleo IA)**: Victoria mediante la descarga completa (100%) con persistencia parcial al ser interrumpida.
2. **Los Objetivos Secundarios (Centros de Integración Tecnológica)**: Permiten el avance a Generaciones 2 y 3 — las capacidades tácticas que determinan el dominio del perímetro del Núcleo.

---

## 🔄 Las 4 Fases de la Operación Tecnológica

### Fase 1 — Triangulación & Mapeo (Información)
Descubrir la firma del Núcleo IA y limpiar la niebla de la sala mediante escaneo de Drones.

### Fase 2 — Apertura de Cortafuegos (Hackeo Inicial)
Romper el protocolo de seguridad inicial mediante Dron o el terminal del operador.

### Fase 3 — Perímetro de Transferencia (Control Territorial)
Descarga continua por presencia de red. Los 3 estados (Activo / Contestado / Degradación) operan en esta fase. El dron puede actuar como antena repetidora del enlace si el operador no tiene línea visual directa al Núcleo.

### Fase 4 — Sobrecarga & Consolidación
Al alcanzar el 100% de descarga: estabilización del Núcleo bajo control del equipo atacante y cierre de la partida.

---

## ⚡ Generadores de Tensión Dinámica

- **Alerta Progresiva del Núcleo**: Con cada 25% de datos descargados, el Núcleo incrementa su tono de sirena y cambia de color — visible para ambas escuadras.
- **Evento de Tormenta Electromagnética (EM Storm)**: Al superar el 50%, el Núcleo emite pulsos que reducen la visibilidad lejana, forzando combate cerrado.
- **Onda de Pulso Continua**: A los 40 minutos sin resolución, el Núcleo activa un pulso que destruye coberturas en el perímetro, forzando el asalto final.
- **Overtime / Sudden Death**: Si el tiempo de ronda finaliza pero un equipo mantiene un enlace activo no contestado, la partida entra en Overtime.

---

## ⚖️ Auditoría contra los 5 Pilares

1. **Pilar 1 (Información)**: Conocer cuándo el rival tiene el perímetro contestado es información crítica para decidir cuándo lanzar el contraataque.
2. **Pilar 2 (Nunca solo)**: El Estado Contestado exige que múltiples operadores y drones sostengan presencia simultánea en el perímetro.
3. **Pilar 3 (El Núcleo es el objetivo)**: La persistencia parcial recompensa el avance acumulado y mantiene el foco permanente en la operación del Núcleo.
4. **Pilar 4 (Terreno)**: La arquitectura del perímetro del Núcleo determina quién puede mantener presencia de red de forma sostenida.
5. **Pilar 5 (Cooperación)**: Mantener el Estado Activo durante el último 10% de la descarga requiere coordinación plena de los 4 operadores y sus drones.
