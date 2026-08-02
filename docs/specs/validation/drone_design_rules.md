# SPEC VALIDATION: DRONE DESIGN RULES — REGLAS Y RECOVERY SYSTEM DEL DRON

- **Estado**: Actualizado / Revisión 2.0 (Fase 0.5 — Validación y Profundización)
- **Ubicación**: `docs/specs/validation/drone_design_rules.md`

---

## 🎯 1. Filosofía del Dron: La Extensión Permanente del Operador

En GRAVITY, la identidad inmutable del jugador no es solo una persona con un rifle, sino la **Tríada Táctica**:

$$\text{Identidad del Jugador} = \text{Operador Humano} + \text{Exoesqueleto Táctico} + \text{Dron Permanente}$$

### Diferenciación Frente a Habilidades Tradicionales:
- **No es una Habilidad Temporal (*Cooldown Skill*)**: El dron está físicamente presente en el juego desde el segundo 0 hasta el final de la partida.
- **No es una Mascota Pasiva (*Pet*)**: No actúa como un compañero de RPG que ataca de forma autónoma descontrolada.
- **No es un Gadget Secundario (*Utilería*)**: No se tira y se olvida como una granada. Es la segunda fuente principal de percepción y presencia táctica del operador.

### Especialización Progresiva del Dron:
A lo largo de la partida, el dron del operador puede adaptarse y especializarse en 5 ramas según las necesidades de la escuadra:
1. **Reconocimiento e Inteligencia**: Sonar de alta frecuencia, marcado térmico, filtrado de niebla de guerra.
2. **Defensa Territorial**: Proyección de barreras electromagnéticas, atenuación de daño balístico, intercepción de granadas.
3. **Soporte Logístico**: Reabastecimiento energético de escuadra, aceleración de recargas, transferencia de escudo.
4. **Asistencia Ofensiva**: Vectorización de fuego (*Smart Vectoring*), supresión coordinada, marcado de puntos débiles.
5. **Manipulación Tecnológica**: Hackeo remoto de puertas, inhabilitación de visores enemigos, sobrecarga de terminales.

---

## 🔧 2. Sistema de Pérdida y Recuperación: Economía de Piezas y Componentes

Cuando un Dron es destruido por fuego o interrupción enemiga, **NO existe una regeneración automática por tiempo sin consecuencias**. La pérdida del dron deja al operador ciego e incompleto.

```
┌─────────────────────────────────────────────────────────────┐
│                 DESTRUCCIÓN DEL DRON EN COMBATE             │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ 📍 EMISIÓN DE RESTOS TECNOLÓGICOS (Wreckage Site)           │
│ El dron destruido deja caer Componentes y Piezas en el mapa. │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ 🛠️ RECOLECCIÓN Y RECUPERACIÓN                                │
│ Piezas obtenibles de:                                       │
│ 1. Restos de Drones Enemigos/Aliados destruidos             │
│ 2. Torres y Sensores Defensivos neutralizados               │
│ 3. Tecnología abandonada en sectores del mapa               │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ 🔄 SÍNTESIS EN PUNTO DE REABASTECIMIENTO                     │
│ Reparar Dron / Mejorar Módulos / Sintetizar Variante        │
└─────────────────────────────────────────────────────────────┘
```

### Refuerzo del Pilar "El terreno decide la batalla":
- La destrucción de drones genera **Puntos de Interés Dinámicos (Scrap Zones)** en la geometría del mapa.
- Un sector donde ocurrió un tiroteo tenso se llena de restos tecnológicos valiosos. La escuadra que logre controlar físicamente ese terreno podrá cosechar componentes para reparar sus drones y mejorar sus módulos para el siguiente asalto al Núcleo.

---

## 🛠️ 3. Nuevo Rol Táctico: Tech Scavenger / Field Engineer (Logística y Recursos)

La introducción de la economía de piezas abre la posibilidad de una función táctica especializada en la gestión de recursos de red:

- **Función Primaria**: Recuperación rápida de componentes en zonas de conflicto, reparación acelerada de drones aliados en el campo y fortificación de terminales.
- **Herramientas**: Extractor de piezas a distancia (vía dron de soporte), campo de recarga de batería acelerado.
- **Dependencia y Balance**: El Scavenger no posee la potencia de penetración del *Breacher* ni el alcance del *Overwatch*, por lo que requiere protección armada mientras cosecha restos en zonas disputadas.

---

## ⚖️ Decisiones Tácticas del Jugador

1. **¿Avanzar a cosechar las piezas del dron enemigo destruido o mantener la posición segura?**
2. **¿Gastar los componentes recolectados en reconstruir mi dron destruido o transferirlos para mejorar el dron de soporte de mi aliado?**
3. **¿Arriesgar el dron en un escaneo profundo sabiendo que su destrucción dejará recursos al enemigo?**
