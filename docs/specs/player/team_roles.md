# SPEC: TEAM ROLES — ROLES TÁCTICOS Y COMPOSICIÓN DE ESCUADRA (4 vs 4)

- **Estado**: Propuesto (Fase 0.5 — Game Architecture)
- **Dominio**: Player & Squad Roles
- **Ubicación**: `docs/specs/player/team_roles.md`

---

## 🎯 Filosofía de Roles: Funciones, No Clases Rígidas

En GRAVITY no existen clases de RPG tradicionales ni "héroes" con roles inmutables. 

Los **Roles Tácticos** son definidos por la **combinación de módulos de Exoesqueleto, Drones equipados y Utilidad de Red** que cada uno de los 4 jugadores elige para la partida.

Una escuadra equilibrada se compone de 4 funciones dinámicas que se complementan en el mapa.

---

## 🛡️ Los 4 Roles Tácticos Fundamentales

```
┌─────────────────────────────────────────────────────────────┐
│                    ESCUADRA TÁCTICA 4 vs 4                  │
├──────────────────┬──────────────────┬───────────────────────┤
│ 👁️ RECON (Intel) │ 🛡️ BREACH (Control)│ ⚡ TECH DISRUPTOR     │
│ (Mapeo & Visión) │ (Frente & Cobert) │ (Hackeo & EMP)       │
├──────────────────┴──────────────────┴───────────────────────┤
│                    🎯 OVERWATCH (Sustento / Fuego Cobertura)│
└─────────────────────────────────────────────────────────────┘
```

---

### 1. 👁️ Recon / Intel Architect (Adquisición de Información)
- **Función Primaria**: Mapear la Niebla de Guerra, identificar las firmas electromagnéticas del equipo enemigo y transmitir la ubicación exacta del Núcleo IA.
- **Herramientas Tácticas**: Dron Micro-Sonar, marcadores térmicos a través de paredes ligeras, sensores de movimiento estáticos.
- **Sinergia con la Escuadra**: Revela la posición de los enemigos para que el Breacher y el Disruptor ataquen con ventaja total de información (Pilar 1).

### 2. 🛡️ Vanguard / Breacher (Control Territorial & Frente)
- **Función Primaria**: Absorber impacto, asegurar coberturas en chokepoints y avanzar físicamente hacia la sala del Núcleo IA.
- **Herramientas Tácticas**: Exoesqueleto de alta densidad, Dron de escudo direccional, cargas de apertura de brecha ligera.
- **Sinergia con la Escuadra**: Proporciona cobertura física para que el operador de Hackeo trabaje de forma segura en el Núcleo (Pilar 3 y 4).

### 3. ⚡ Tech Disruptor / Hacker (Guerra Electrónica)
- **Función Primaria**: Inhabilitar la electrónica enemiga, interceptar señales de drones contrarios y acelerar el tiempo de hackeo del Núcleo IA.
- **Herramientas Tácticas**: Dron EMP de pulso, transmisor de interferencia visual, inyectores de virus de puerto.
- **Sinergia con la Escuadra**: Desactiva los visores y coberturas electrónicas enemigas justo cuando el Vanguard entra en la sala (Pilar 5).

### 4. 🎯 Overwatch / Anchor (Sustento & Fuego de Cobertura)
- **Función Primaria**: Mantener la línea de retaguardia, aplicar fuego de supresión de largo alcance y proporcionar soporte energético a los drones de la escuadra.
- **Herramientas Tácticas**: Rifles de precisión con asistencia de trayectoria de dron, Dron de reabastecimiento de batería/munición.
- **Sinergia con la Escuadra**: Impide que los flanqueadores enemigos cierren la distancia sobre el Breacher y el Recon (Pilar 2).

---

## 🔄 Flexibilidad y Sinergias de Escuadra

- **Cero Restricción de Personaje Unico**: La escuadra no está atada a "un personaje único por equipo". Dos operadores pueden llevar módulos de Intel si la estrategia de la partida requiere un mapa hiper-revelado.
- **Vulnerabilidad de Composiciones Desbalanceadas**:
  - *Escuadra 4x Asalto Pautado*: Queda ciega ante Niebla de Guerra y es aplastada por trampas EMP.
  - *Escuadra 4x Intel*: Posee visión total, pero carece de la fuerza de retención física para capturar el Núcleo ante un Breacher pesado.

---

## ⚖️ Auditoría contra los 5 Pilares de Diseño

1. **Pilar 1 (La información es el recurso más valioso)**: Cumplido. El rol de *Recon* es indispensable para el éxito de las maniobras ofensivas.
2. **Pilar 2 (El jugador nunca combate solo)**: Cumplido. Las 4 funciones están estrechamente interconectadas; el Breacher necesita la información del Recon y la asistencia del Disruptor.
3. **Pilar 3 (El objetivo es controlar el núcleo, no eliminar enemigos)**: Cumplido. La composición de escuadra se evalúa por su capacidad de asegurar y sostener el perímetro del Núcleo.
4. **Pilar 4 (El terreno decide la batalla)**: Cumplido. El *Overwatch* domina las líneas largas mientras el *Breacher* domina los interiores estrechos.
5. **Pilar 5 (La cooperación supera al héroe individual)**: Cumplido. Ningún rol puede resolver los problemas de la partida por sí solo; la victoria exige la cadena de acciones de los 4 operadores.
