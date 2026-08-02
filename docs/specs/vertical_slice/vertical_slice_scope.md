# SPEC: VERTICAL SLICE SCOPE — ALCANCE DEL PRIMER PROTOTIPO JUGABLE

- **Estado**: Activo — Fase 1: Vertical Slice Design
- **Ubicación**: `docs/specs/vertical_slice/vertical_slice_scope.md`
- **Versión**: 1.0

---

## 🎯 La Pregunta del Vertical Slice

> **"¿El núcleo táctico de GRAVITY es divertido?"**

El Vertical Slice no es una versión reducida de GRAVITY completo. Es una prueba de concepto jugable que demuestra si la combinación de **información táctica + Dron como extensión + objetivo territorial** genera una experiencia que vale la pena construir.

**Criterio de éxito**: 4 jugadores terminan la sesión y quieren jugar otra ronda.

---

## 🔴 Lo Que NO Pertenece al Vertical Slice

| Fuera de Scope | Razón |
| :--- | :--- |
| Multiplayer online / networking | Validar el alma del juego no requiere red. El VS es local cooperativo. |
| Roster completo de operadores | Solo necesitamos 4 prototipos que demuestren los 4 roles. |
| Ramas de evolución Gen 2 y Gen 3 | El sistema de Generaciones se valida en sandbox después. |
| Balance final de números | Los números se ajustan con datos de playtest, no antes. |
| Arte definitivo | Placeholders funcionales son suficientes para validar mecánicas. |
| Economía completa de recursos | Solo el flujo básico de Mantenimiento (reparar drones). |
| Sistema de matchmaking | No hay red. Sesión local única. |

---

## ✅ Lo Que SÍ Pertenece al Vertical Slice

---

### 👥 1. Jugadores

| Parámetro | Decisión |
| :--- | :--- |
| **Formato** | 2 a 4 jugadores en **cooperativo local** |
| **Input 1 - 3** | Mando / Joystick (cada jugador su propio controlador) |
| **Input 4** | Teclado + Ratón (jugador adicional como alternativa) |
| **Sesión** | Sin matchmaking. Un host lanza la sesión, los demás se unen localmente. |
| **Split-screen** | No requerido. Perspectiva top-down o cámara isométrica comparten pantalla. |

> 🔶 **Decisión Abierta**: La perspectiva de cámara del VS (top-down, isométrica o first-person) no está definida en el GDD. Es la primera decisión técnica del Vertical Slice que debe resolverse antes de construir el mapa de prueba.

---

### 🧑‍💼 2. Operadores Prototipo (4 en total)

Cada operador prototipo debe demostrar una función táctica clara y diferenciada. No se busca profundidad de personaje — se busca **demostración de rol**.

#### Operador A — Recon (INTEL PROTOTYPE)
- **Función demostrable**: Ver lo que otros no pueden ver.
- **Mecánicas activas en VS**: Dron con cono de escaneo extendido. Modo Piloto con detección de firmas enemigas a través de paredes a corta distancia.
- **Ausencias aceptadas**: Sin Sonar de Alta Frecuencia Gen 2. Sin Radar Neuronal Gen 3.
- **Pregunta que valida**: *¿El Recon cambia las decisiones del equipo con su información?*

#### Operador B — Vanguard (BREACHER PROTOTYPE)
- **Función demostrable**: Absorber impacto y asegurar coberturas.
- **Mecánicas activas en VS**: Mayor resistencia balística base. Dron en Modo Escolta con proyección de micro-barrera frontal breve (1 seg de duración, cooldown de 8 seg).
- **Ausencias aceptadas**: Sin Perímetro Fortificado Gen 3. Sin módulos de exoesqueleto avanzados.
- **Pregunta que valida**: *¿El Breacher permite al equipo avanzar hacia el Núcleo cuando sin él sería imposible?*

#### Operador C — Tech Disruptor (HACKER PROTOTYPE)
- **Función demostrable**: Inhabilitar la tecnología enemiga y abrir el perímetro del Núcleo.
- **Mecánicas activas en VS**: Dron puede hackear la puerta del sector del Núcleo (2 seg de enlace). Puede lanzar sobrecarga EMP del Dron (requiere línea de visión del operador durante 1 seg antes de detonación).
- **Ausencias aceptadas**: Sin inhabilitación de visores (Gen 2). Sin interferencia en Canalizaciones (Gen 2).
- **Pregunta que valida**: *¿El Disruptor crea ventanas de acción para el equipo que de otro modo no existirían?*

#### Operador D — Field Engineer (LOGISTICS PROTOTYPE)
- **Función demostrable**: Sostener la presencia tecnológica del equipo en el campo.
- **Mecánicas activas en VS**: Cosecha remota de Wreck Sites via Dron. Reparación Dron-a-Dron de aliados en campo. Consolidación de Wreck Sites aliados para protegerlos del saqueo.
- **Ausencias aceptadas**: Sin interferencia en Canalizaciones enemigas (Gen 2). Sin Overclock Energético (Gen 3).
- **Pregunta que valida**: *¿El equipo nota su ausencia cuando el Field Engineer cae?*

---

### 🤖 3. Drones — Gen 1 Base

Los cuatro operadores del VS comparten la misma arquitectura base de Dron. No hay ramas de Doctrina en el VS.

| Modo | Comportamiento | Activación |
| :--- | :--- | :--- |
| **Escolta** | Orbita el hombro del operador. Cono de visión secundario activo. Detecta enemigos en rango corto. | Estado por defecto al spawnear. |
| **Estacionario** | El Dron se ancla a la superficie más cercana y actúa como cámara de vigilancia fija. El feed del Dron se transmite al HUD del operador en una ventana pequeña. | Botón de anclaje. El dron permanece hasta ser destruido o retirado. |
| **Piloto** | El operador toma control manual del Dron. Su cuerpo queda inmóvil y vulnerable. Cámara en primera persona del Dron. El operador puede volver a su cuerpo en cualquier momento. | Botón de pilotar. Hold para mantener, soltar para regresar. |

**Batería del Dron**: El Dron tiene una barra de batería compartida con el exoesqueleto. El Modo Piloto activo drena la batería más rápido. Si el Dron es destruido, entra en proceso de síntesis.

**Síntesis tras destrucción**: El Dron tarda en regenerarse. El Field Engineer puede reducir este tiempo con reparación Dron-a-Dron. Sin síntesis, el operador queda sin su extensión táctica — situación de alta vulnerabilidad.

---

### 💰 4. Recursos — Economía Simplificada

Para el VS, el sistema de recursos se reduce al flujo de **Mantenimiento** únicamente. No existe economía de Evolución (Gen 2/Gen 3 no están en el VS).

| Elemento | Descripción |
| :--- | :--- |
| **Componentes de Mantenimiento** | Recogidos de Wreck Sites y nodos básicos del mapa. |
| **Wreck Sites** | Aparecen cuando un Dron es destruido. Permanecen en el mapa 90 segundos antes de disiparse. |
| **Punto de Síntesis** | Zona en la base o punto neutral del mapa donde los Componentes se convierten en tiempo de síntesis reducido para Drones destruidos. |
| **Inventario** | Cada operador porta un máximo de componentes (cap provisional, ajustar en playtest). |

**Anti-Kill-Farming**: Los componentes obtenidos de eliminar operadores enemigos son mínimos. La fuente principal son Wreck Sites y nodos del mapa.

---

### 🎯 5. Objetivo — Núcleo IA Funcional

El VS implementa el sistema de hackeo del Núcleo con **persistencia parcial** validada en las simulaciones.

#### Estados del Progreso:
```
┌─────────────────────────────────────────────────────────┐
│ ACTIVO     → La barra de hackeo avanza                  │
│ CONTESTADO → La barra se congela                        │
│ DEGRADACIÓN → La barra cae lentamente (no reset)        │
└─────────────────────────────────────────────────────────┘
```

#### Condiciones de Victoria:
- **Victoria de Ataque**: Hackeo del Núcleo al 100%.
- **Victoria de Defensa**: Degradar el hackeo a 0% desde un estado de avance del atacante, O sobrevivir hasta el fin del tiempo de sesión con el Núcleo sin completar.

> 🔶 **Para el VS, el modo es PvE cooperativo**: Los 4 jugadores atacan el Núcleo defendido por IA simple. Esto permite validar el loop táctico sin necesitar un segundo equipo humano.

#### Alertas del Núcleo en VS:
- Al 25%, 50% y 75%: El Núcleo emite un tono de alerta audible y el HUD pulsa.
- Al 50%: La cobertura en el perímetro del Núcleo se reduce ligeramente (EM Storm simplificado).

---

### 🗺️ 6. Mapa de Prueba — SANDBOX-01

El primer mapa del VS es un **mapa de validación de mecánicas**, no un nivel de producción.

#### Requisitos de Geometría:

| Elemento | Especificación |
| :--- | :--- |
| **Rutas** | 3 rutas principales: Norte (ruta larga con cobertura), Centro (chokepoint directo), Sur (conductos de drones) |
| **Coberturas** | Objetos de cobertura baja (agacharse), media (posición firme) y alta (mezzanine/elevación) |
| **Elevación** | Al menos 1 posición elevada con ventaja de visión sobre el corredor central |
| **Conductos de Drones** | 2 conductos: uno en el techo del corredor norte, uno sumergido en la ruta sur. Accesibles solo en Modo Piloto |
| **Zona del Núcleo** | Sala cerrada con 2 entradas. Terminal del Núcleo IA en el centro. Perímetro de enlace definido por una zona de radio visual. |
| **Zona de Recursos** | 3 nodos de componentes: 1 en zona norte (segura), 1 en zona central (disputada), 1 en zona sur (de difícil acceso) |
| **Punto de Síntesis** | 1 punto por equipo, en su zona de spawn, fuera del combate activo |

#### Filosofía de SANDBOX-01:
- El mapa no debe ser bello. Debe ser **legible**.
- Cada elemento del mapa tiene un propósito de validación mecánica.
- La geometría debe poder rehacerse rápidamente si una decisión de diseño falla en playtest.

---

## 📅 Secuencia de Construcción del Vertical Slice

El orden de implementación respeta las dependencias técnicas:

```
1. Input y Control del Operador
   └── Movimiento, cobertura, cámara.

2. Sistema del Dron (Gen 1)
   └── Escolta → Estacionario → Piloto.
   └── Batería, destrucción y síntesis.

3. Mapa SANDBOX-01
   └── Geometría básica, coberturas, conductos.
   └── Zona del Núcleo IA.

4. Núcleo IA — Sistema de Progreso
   └── Estados: Activo / Contestado / Degradación.
   └── Alerta progresiva y EM Storm simplificado.

5. Sistema de Recursos Básico
   └── Wreck Sites, Componentes, Punto de Síntesis.

6. Los 4 Operadores Prototipo
   └── Aplicar diferencias funcionales sobre el operador base.

7. IA Defensora del Núcleo (PvE básico)
   └── Patrulla, respuesta a intrusión, sin comportamientos complejos.

8. Sesión Cooperativa Local
   └── 2-4 jugadores en la misma instancia. Input múltiple.
```

---

## 🔒 Compromisos de Diseño para el VS

Estos elementos están decididos y no deben reabrirse durante el desarrollo del VS:

1. El Dron es siempre visible para aliados en el mapa táctico.
2. La pérdida del Dron no se recupera automáticamente por tiempo — requiere recursos.
3. El hackeo del Núcleo requiere presencia física en el perímetro — no es remoto.
4. El operador en Modo Piloto del Dron es físicamente vulnerable.
5. El daño no varía por operador en Gen 1. Las diferencias son de capacidad táctica, no de daño.
