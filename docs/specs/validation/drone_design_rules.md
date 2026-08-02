# SPEC VALIDATION: DRONE DESIGN RULES — REGLAS, RECOVERY SYSTEM Y GENERACIONES DEL DRON

- **Estado**: Actualizado / Revisión 3.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/drone_design_rules.md`

---

## 🎯 1. Filosofía del Dron: La Extensión Permanente del Operador

En GRAVITY, la identidad inmutable del jugador no es solo una persona con un rifle, sino la **Tríada Táctica**:

$$\text{Identidad del Jugador} = \text{Operador Humano} + \text{Exoesqueleto Táctico} + \text{Dron Permanente}$$

---

## 📈 2. El Dron a través de las Generaciones Tecnológicas

El Dron evoluciona en sintonía con el avance de las Generaciones Tecnológicas del Operador:

### Generación 1 (Dron Estándar Base):
- Capacidades iniciales de escaneo de niebla en cono primario.
- Batería estándar, soporte de transmisión de datos básico.
- Cero módulos avanzados de defensa o empache.

### Generación 2 (Dron Especializado según Doctrina Elegida):
- **Rama Reconocimiento**: Sonar de alta frecuencia, escaneo omnidireccional y filtrado térmico.
- **Rama Defensa**: Proyección de micro-escudos y atenuación balística en el perímetro del operador.
- **Rama Logística**: Campo de recarga de batería para drones aliados y enlace de componentes.
- **Rama Asistencia Ofensiva**: *Smart Vectoring* y marcado de puntos débiles en armaduras enemigas.
- **Rama Manipulación Tecnológica**: Hackeo remoto de puertas, terminales e inhabilitación de visores.

### Generación 3 (Dron de Evolución Avanzada y Efectos de Red):
- Desbloqueo de habilidades pasivas de escuadra (efectos de red). El dron retransmite señales avanzadas a toda la escuadra y duplica el alcance de enlace con el Núcleo IA.

---

## 🔧 3. Sistema de Pérdida y Recuperación por Piezas

Cuando un Dron es destruido por fuego o interrupción enemiga:
- **NO existe regeneración mágica por tiempo**.
- El dron destruido genera un sitio de restos (**Wreckage Site / Scrap Zone**).
- La recuperación exige **Recursos de Mantenimiento** (obtenidos de la chatarra tecnológica del mapa) para sintetizar un nuevo dron en los puntos de reabastecimiento o mediante un operador con rol logístico (*Field Engineer*).
- **Diferenciación Clave**: Los *Recursos de Mantenimiento* reconstruyen el dron destruido en su Generación actual; no elevan la Generación Tecnológica del operador (lo cual requiere *Recursos de Evolución* en un Centro de Integración).

---

## ⚖️ Decisiones Tácticas del Jugador

1. **¿Gastar chatarra en reconstruir inmediatamente mi dron Gen 2 destruido o ahorrar para alcanzar Gen 3 en el Centro de Integración?**
2. **¿Avanzar a disputar las piezas del dron enemigo destruido en la Scrap Zone o mantener el control territorial del perímetro del Núcleo?**
