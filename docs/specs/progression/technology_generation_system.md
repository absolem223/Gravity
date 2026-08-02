# SPEC: TECHNOLOGY GENERATION SYSTEM — SISTEMA DE GENERACIONES TECNOLÓGICAS

- **Estado**: Propuesto (Fase 0.5 — Game Architecture)
- **Dominio**: Progression & Tech Tree
- **Ubicación**: `docs/specs/progression/technology_generation_system.md`

---

## 🎯 Filosofía de la Progresión en Partida

GRAVITY rechaza los sistemas de "niveles de experiencia" (XP) tradicionales de los juegos de rol o MOBAs donde los personajes ganan atributos de forma abstracta e intangible.

La progresión dentro de una partida ocurre mediante **Generaciones Tecnológicas Permanentes**:

$$\text{Evolución del Jugador} = \text{Generaciones Tecnológicas} \quad (\text{Operador} + \text{Dron})$$

### Principios Fundamentales:
1. **Permanencia e Inmutabilidad**: Una vez alcanzada una Generación superior, **no puede perderse ni revertirse** por morir o perder una ronda.
2. **Evolución Conjunta**: La Generación eleva simultáneamente las capacidades biomecánicas del Exoesqueleto y el ancho de banda del Dron.
3. **Decisión Doctrinaria Irreversible**: La elección de rama tecnológica requiere compromiso estratégico para toda la partida.

---

## 🏛️ Las 3 Generaciones Tecnológicas

```
┌─────────────────────────────────────────────────────────────┐
│ GENERACIÓN 1 — TECNOLOGÍA BASE                              │
│ - Estado inicial del Operador y Dron al iniciar la partida. │
│ - Radar básico, armas neutras y escaneo de niebla estándar. │
└──────────────┬──────────────────────────────────────────────┘
               │ Acceso a Centro de Integración + Inversión
               ▼
┌─────────────────────────────────────────────────────────────┐
│ GENERACIÓN 2 — ESPECIALIZACIÓN TECNOLÓGICA (Rama Elegida)   │
│ Elección PERMANENTE de 1 Doctrina Tecnológica:              │
│ 1. Reconocimiento | 2. Defensa | 3. Logística |             │
│ 4. Asistencia Ofensiva | 5. Manipulación Tecnológica       │
└──────────────┬──────────────────────────────────────────────┘
               │ Acceso a Estación Avanzada + Inversión Mayor
               ▼
┌─────────────────────────────────────────────────────────────┐
│ GENERACIÓN 3 — EVOLUCIÓN AVANZADA                           │
│ - Profundización radical de la Doctrina elegida.            │
│ - Desbloqueo de efectos de red de alto impacto para la escuadra.│
└─────────────────────────────────────────────────────────────┘
```

---

## 🏢 Infraestructura Física: Centros de Integración Tecnológica

La progresión tecnológica **NO ocurre automáticamente flotando en el aire ni desde el menú de pausa**.

Para avanzar de Generación, el jugador debe interactuar físicamente con **Centros de Integración Tecnológica (Tech Integration Centers / Manufacturing Stations)** distribuidos estratégicamente en el mapa.

### Conflicto Territorial por la Progresión:
- **Estaciones Neutrales**: Ubicadas en zonas de riesgo medio y en los laterales del mapa.
- **Vulnerabilidad durante la Integración**: El proceso de síntesis e instalación de la nueva Generación requiere 4 segundos de canalización física o enlace de dron, generando momentos de alta vulnerabilidad.
- **Puntos de Control Disputados**: Acampar cerca del Núcleo sin controlar un Centro de Integración impide que la escuadra evolucione a Generaciones superiores.

---

## 💰 Sistema de Inversión: Evolución vs Mantenimiento

Es vital separar los recursos recolectados (chatarra, nodos, tecnología abandonada) en dos bolsas operativas:

| Destino del Recurso | Propósito | ¿Se pierde si el dron muere? | Dónde se efectúa |
| :--- | :--- | :--- | :--- |
| **Recursos de Mantenimiento** | Reparar dron, reemplazar módulos dañados, recargar baterías. | Sí, se consume en la acción táctica inmediata. | En el campo / Puntos de reabastecimiento ligeros. |
| **Recursos de Evolución** | Pagar el salto a Generación 2 o Generación 3. | No, se consolidan en la infraestructura al evolucionar. | Exclusivamente en Centros de Integración Tecnológica. |

---

## 🌐 Tecnologías con Efecto de Red (Network Effect)

Aunque la evolución pertenece al operador individual, sus beneficios están diseñados para **causar un impacto positivo en toda la escuadra**:

- **Ejemplo Reconocimiento Gen 3**: El operador desbloquea el *Radar Neuronal*. La ubicación de enemigos escaneados por su dron no solo aparece en sus visores, sino que se retransmite automáticamente a los visores de los 3 aliados con asistencia de trayectoria (*Smart Vectoring*).
- **Ejemplo Logística Gen 3**: El operador desbloquea el *Overclock Energético*. Los drones de sus aliados consumen un 30% menos de batería mientras operen a menos de 20 metros de su posición.
- **Ejemplo Manipulación Gen 3**: El operador reduce el tiempo de descarga del Núcleo IA de toda la escuadra durante la fase de Perímetro.

---

## ⚖️ Auditoría contra los 5 Pilares

1. **Pilar 1 (La información es el recurso más valioso)**: Cumplido. La decisión de qué rama tecnológica elegir se basa en qué información necesita la escuadra para contraatacar al rival.
2. **Pilar 2 (El jugador nunca combate solo)**: Cumplido. Los efectos de red de las Generaciones avanzadas potencian directamente a los compañeros.
3. **Pilar 3 (El objetivo es controlar el Núcleo IA)**: Cumplido. Las estaciones tecnológicas avanzadas están posicionadas para obligar a controlar el territorio alrededor del Núcleo.
4. **Pilar 4 (El terreno decide la batalla)**: Cumplido. El control físico de los Centros de Integración Tecnológica en la geometría del nivel determina qué equipo evoluciona primero.
5. **Pilar 5 (La cooperación supera al héroe individual)**: Cumplido. Una escuadra coordinada que combina una Gen 2 de Reconocimiento con una Gen 2 de Defensa superará siempre a cuatro jugadores Gen 1 desconectados.
