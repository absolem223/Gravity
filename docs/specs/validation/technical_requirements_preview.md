# SPEC: TECHNICAL REQUIREMENTS PREVIEW — REVISIÓN 2.0: REQUISITOS DEL VERTICAL SLICE

- **Estado**: Actualizado — Fase 1: Vertical Slice Design
- **Ubicación**: `docs/specs/validation/technical_requirements_preview.md`
- **Versión**: 2.0 (Anterior: Arquitectura Conceptual → Actual: Requisitos del Primer Prototipo)

---

## 🎯 Propósito de este Documento

En la Fase 0.5, este documento era una vista previa conceptual de los subsistemas técnicos futuros. En la Fase 1, se convierte en la **lista de requisitos técnicos concretos del Vertical Slice**, ordenados por prioridad de implementación y dependencias.

---

## 🔴 Decisiones Técnicas Previas al Código

Las siguientes decisiones deben resolverse **antes de escribir la primera línea de código del VS**. Son el primer bloque de trabajo de la Fase 1.

### DT-01 — Perspectiva de Cámara
- **Estado**: 🔶 ABIERTA — Decisión Prioritaria
- **Opciones**:
  - **A — Top-Down Isométrico**: Mayor legibilidad táctica del mapa. Más fácil de prototipar. Menor inmersión.
  - **B — Third-Person Over-Shoulder**: Mayor inmersión. Más complejo de implementar (curva de aprendizaje de Godot 3D + física). Lectura táctica más difícil en espacios cerrados.
  - **C — First-Person**: Máxima inmersión. Implica diseño de UI de HUD complejo y mayor costo de protipado. El Modo Piloto del Dron ganaría naturalidad.
- **Recomendación de diseño**: Comenzar con Top-Down Isométrico para el VS. La perspectiva puede cambiar en producción sin invalidar las mecánicas validadas.
- **¿Quién decide?**: Director de Proyecto + Director de Arte.

### DT-02 — Motor de Física de Movimiento
- **Estado**: 🔶 ABIERTA
- **Decisión requerida**: ¿El movimiento del operador usa `CharacterBody3D` (Godot) con física propia, o `RigidBody3D` con físicas de motor? El VS no requiere físicas complejas — `CharacterBody3D` es suficiente y más controlable.
- **Recomendación**: `CharacterBody3D` con `move_and_slide()` para el VS. Revisar en producción.

### DT-03 — Persistencia de Sesión del VS
- **Estado**: 🟢 DECIDIDA
- **Decisión**: El VS es local cooperativo. No hay backend. Los datos de sesión (progreso del Núcleo, estado de Drones, inventario de recursos) viven únicamente en memoria durante la sesión. Sin guardado.

---

## 🏗️ Requisitos Técnicos por Sistema — Prioridad de Implementación

El orden de implementación sigue las dependencias declaradas en `vertical_slice_scope.md`.

---

### SISTEMA 1 — Input y Control del Operador [PRIORIDAD: CRÍTICA]

**Lenguaje**: GDScript 2.x con tipado estricto (ADR-0001).

| Requisito | Descripción |
| :--- | :--- |
| **R-INP-01** | Soporte de 1 a 4 mandos/joysticks simultáneos mediante el sistema de Input de Godot (`InputMap`). |
| **R-INP-02** | Soporte de teclado + ratón como cuarto jugador alternativo con mapeo de controles equivalente. |
| **R-INP-03** | El operador puede moverse en 8 direcciones, agacharse, apuntar y disparar. |
| **R-INP-04** | El operador puede interactuar con el entorno (terminal del Núcleo, nodos de recursos) mediante botón de acción contextual. |
| **R-INP-05** | El operador puede cambiar entre Modo Escolta, Estacionario y Piloto del Dron con botones dedicados. |
| **R-INP-06** | Buffer de comando: las acciones de Dron deben ser procesadas aunque el input llegue 1-2 frames antes del cambio de estado. |

---

### SISTEMA 2 — Dron Gen 1 [PRIORIDAD: CRÍTICA]

El Dron es el sistema más complejo del VS. Depende del Sistema 1 (Input) y es dependencia del Sistema 6 (Operadores Prototipo).

| Requisito | Descripción |
| :--- | :--- |
| **R-DRN-01** | El Dron es un nodo hijo del operador. Existe en la escena durante toda la sesión (nunca desaparece — solo se destruye y sintetiza). |
| **R-DRN-02** | **Modo Escolta**: El Dron sigue al operador a distancia fija, actualiza su cono de visión y detecta entidades enemigas en su rango. |
| **R-DRN-03** | **Modo Estacionario**: El Dron se ancla al punto de superficie más cercano. El feed de su cámara aparece en el HUD del operador. Permanece hasta ser destruido o retirado. |
| **R-DRN-04** | **Modo Piloto**: El operador toma control del Dron. La cámara del jugador pasa a la perspectiva del Dron. El cuerpo del operador permanece en la posición actual y es colisionable por entidades enemigas. Soltar el botón devuelve el control al operador. |
| **R-DRN-05** | **Batería Táctica**: Barra de batería compartida entre Dron y Exoesqueleto. El Modo Piloto activo drena a 2x de velocidad. La batería se recarga lentamente en Modo Escolta. |
| **R-DRN-06** | **Destrucción**: Al recibir suficiente daño, el Dron entra en estado `DESTROYED`. Aparece un `WreckSite` en la posición de destrucción. El operador pasa automáticamente a estado `DRONE_LOST`. |
| **R-DRN-07** | **Síntesis**: El operador en estado `DRONE_LOST` puede gastar `Componentes de Mantenimiento` en el `PuntoSíntesis` para restaurar el Dron. El Field Engineer puede reducir el tiempo de síntesis via reparación `Dron-a-Dron`. |
| **R-DRN-08** | **Rango de enlace de red**: El Dron en Modo Piloto o Estacionario tiene un rango máximo de operación. Si supera ese rango, entra en `DRIFT_MODE` — se vuelve incontrolable y vulnerable. |
| **R-DRN-09** | **Detección de firma**: El Dron emite una señal de audio y un indicador visual cuando escanea activamente. Los enemigos atentos (y la IA) pueden detectar esta firma. |
| **R-DRN-10** | **EMP del Dron** (exclusivo del Tech Disruptor): El operador debe tener línea de visión directa durante 1 seg antes de detonación. El EMP tiene radio de área. Inhabilita todos los Drones en el radio (aliados y enemigos). |

---

### SISTEMA 3 — Mapa SANDBOX-01 [PRIORIDAD: ALTA]

| Requisito | Descripción |
| :--- | :--- |
| **R-MAP-01** | 3 rutas navegables con propiedades tácticas distintas (ancha/cobertura, estrecha/directa, cerrada/conductos). |
| **R-MAP-02** | Coberturas de 3 alturas: baja (agacharse), media (posición firme) y alta (mezzanine/elevación con ventaja de visión). |
| **R-MAP-03** | Al menos 2 conductos de Dron (zonas solo accesibles en Modo Piloto). Dimensiones: el operador no puede entrar físicamente. |
| **R-MAP-04** | Sala del Núcleo IA: 2 entradas, terminal central, zona de perímetro de radio definido para enlace de hackeo. |
| **R-MAP-05** | 3 nodos de recursos con niveles de riesgo distintos: seguro (spawn), disputado (centro), difícil (flanco). |
| **R-MAP-06** | 1 Punto de Síntesis por equipo en zona de spawn, fuera del combate activo. |
| **R-MAP-07** | El mapa tiene colisiones correctas: el Dron en Modo Piloto puede atravesar los conductos pero no las paredes sólidas. |

---

### SISTEMA 4 — Núcleo IA: Sistema de Progreso [PRIORIDAD: ALTA]

| Requisito | Descripción |
| :--- | :--- |
| **R-NUC-01** | El Núcleo tiene una barra de hackeo de 0% a 100%. Valor inicial: 0%. |
| **R-NUC-02** | **Estado ACTIVO**: La barra avanza si al menos 1 operador tiene presencia activa en el perímetro y la IA defensora no está en estado CONTESTING. |
| **R-NUC-03** | **Estado CONTESTADO**: La barra se congela si hay presencia tanto del equipo atacante como de la IA defensora en el perímetro simultáneamente. |
| **R-NUC-04** | **Estado DEGRADACIÓN**: La barra cae a -10%/30 seg si solo la IA defensora tiene presencia en el perímetro. Al superar 50%, la tasa se reduce a -5%/30 seg. |
| **R-NUC-05** | **Alertas**: Al 25%, 50% y 75%, el Núcleo emite un tono audible y el HUD pulsa. Al 50%, la cobertura en el perímetro se reduce (EM Storm). |
| **R-NUC-06** | **Victoria**: Al 100%, la sesión termina con victoria del equipo atacante. |
| **R-NUC-07** | El progreso de la barra es visible para todos los jugadores en el HUD en todo momento. |

---

### SISTEMA 5 — Recursos Básicos [PRIORIDAD: MEDIA]

| Requisito | Descripción |
| :--- | :--- |
| **R-REC-01** | Los `Componentes de Mantenimiento` son el único tipo de recurso del VS. |
| **R-REC-02** | Los Wreck Sites aparecen al destruir un Dron. Emiten una señal visual (luz pulsante). Permanecen 90 seg antes de disiparse. |
| **R-REC-03** | El operador recoge Componentes al entrar en el radio del Wreck Site. El Field Engineer puede cosechar remotamente via Dron. |
| **R-REC-04** | Cada operador tiene un inventario de Componentes con un cap provisional (valor: ajustar en playtest). |
| **R-REC-05** | Los Componentes se gastan en el Punto de Síntesis para reducir el tiempo de restauración del Dron. |

---

### SISTEMA 6 — Los 4 Operadores Prototipo [PRIORIDAD: MEDIA]

| Requisito | Descripción |
| :--- | :--- |
| **R-OPE-01** | Todos los operadores comparten el mismo componente de movimiento, daño base e interacción con el Dron Gen 1. |
| **R-OPE-02** | **Recon**: El Dron en Modo Piloto tiene rango de escaneo +50% frente al base. Detecta firmas enemigas a través de paredes a distancia corta. |
| **R-OPE-03** | **Vanguard/Breacher**: Resistencia balística +20% base. El Dron en Modo Escolta emite una micro-barrera frontal de 1 seg al activarla (cooldown: 8 seg). |
| **R-OPE-04** | **Tech Disruptor**: El Dron puede hackear la puerta del Núcleo (enlace de 2 seg). Puede ejecutar sobrecarga EMP con requisito de línea de visión directa de 1 seg. |
| **R-OPE-05** | **Field Engineer**: El Dron puede cosechar Wreck Sites remotamente. Puede ejecutar reparación Dron-a-Dron sobre un aliado en `DRONE_LOST` reduciendo el tiempo de síntesis. |
| **R-OPE-06** | Las diferencias entre operadores son de **capacidad táctica del Dron**, no de daño. El daño base es idéntico para los 4. |

---

### SISTEMA 7 — IA Defensora del Núcleo [PRIORIDAD: BAJA — PvE básico]

La IA defensora del VS no necesita ser sofisticada. Su propósito es generar resistencia táctica suficiente para que el equipo necesite cooperar.

| Requisito | Descripción |
| :--- | :--- |
| **R-IA-01** | La IA patrulla rutas predefinidas en el mapa. Al detectar un operador o Dron en su cono de visión, entra en estado ALERTA. |
| **R-IA-02** | En estado ALERTA, la IA avanza hacia el operador detectado y aplica fuego. |
| **R-IA-03** | Si un operador entra en el perímetro del Núcleo, una IA defensora local entra en estado CONTESTING — el Núcleo pasa a Estado CONTESTADO. |
| **R-IA-04** | La IA defensora puede detectar el Dron en Modo Piloto por su firma de audio. Abre fuego sobre el Dron si lo detecta. |
| **R-IA-05** | La IA no tiene comportamiento adaptativo en el VS. Sus rutas y respuestas son deterministas y predecibles con información. |

---

### SISTEMA 8 — Sesión Cooperativa Local [PRIORIDAD: BAJA — Dependencia de 1-6]

| Requisito | Descripción |
| :--- | :--- |
| **R-SES-01** | La sesión acepta entre 2 y 4 jugadores locales. Los jugadores se asignan a un operador prototipo al inicio. |
| **R-SES-02** | Los 4 mandos/joysticks son independientes. El cuarto jugador puede usar teclado + ratón. |
| **R-SES-03** | La sesión tiene una duración máxima (provisional: 45 min). Si el tiempo expira, la sesión termina con victoria defensora si el hackeo es < 100%. |
| **R-SES-04** | Al finalizar la sesión (victoria o tiempo expirado), se muestra una pantalla de resumen con el progreso máximo de hackeo alcanzado. |

---

## 📐 Arquitectura de Módulos del VS en GDScript

```
game/
└── modules/
    ├── operator/
    │   ├── operator_base.gd        # Movimiento, disparo, colisiones
    │   ├── operator_recon.gd       # Extiende operator_base
    │   ├── operator_vanguard.gd
    │   ├── operator_disruptor.gd
    │   └── operator_engineer.gd
    ├── drone/
    │   ├── drone_base.gd           # Modos, batería, red, destrucción
    │   └── drone_emp.gd            # Lógica EMP exclusiva del Disruptor
    ├── nucleus/
    │   ├── nucleus_ai.gd           # Estados Activo/Contestado/Degradación
    │   └── nucleus_hud.gd          # Barra de progreso y alertas
    ├── resources/
    │   ├── wreck_site.gd           # Spawn, vida, señal visual
    │   └── resource_inventory.gd   # Componentes, cap, cosecha
    └── session/
        ├── session_manager.gd      # Jugadores, input, victoria/derrota
        └── session_hud.gd          # HUD global, mapa táctico básico
```

---

## 🔒 Política de Código del VS (ADR-0001 — GDScript 2.x Tipado Estricto)

Todo el código del VS debe seguir:

```gdscript
# ✅ Correcto — tipado estricto
func get_battery_level() -> float:
    return _battery_current / _battery_max

var _battery_current: float = 100.0
var _battery_max: float = 100.0

# ❌ Incorrecto — sin tipado
func get_battery_level():
    return battery_current / battery_max
```

- Ningún `var` sin tipo explícito.
- Ninguna función sin tipo de retorno declarado.
- Los `@export` usan tipos explícitos.
- Los comentarios explican el *por qué*, no el *qué*.
