# Sistema Oficial de Configuración de Gravity — Arquitectura UX

> Documento de diseño **previo a la implementación**. Define el sistema de
> configuración definitivo (navegación, componentes, perfiles de entrada y
> persistencia) que será la base del resto del desarrollo. El arte posterior
> evolucionará; la arquitectura y su organización, no.

---

## 1. Contexto y decisión de base

El código actual concentra en `main_menu.gd` (una única clase con un enum `MenuPage`)
el estado de navegación, el armado de la UI, la configuración de slots y parte de la
persistencia. `SessionConfig` es un autoload con `SlotConfig` (enabled/team/control)
persistido a `settings.cfg`. `InputManager` genera acciones `p*_action` en el
`InputMap` en tiempo de ejecución.

**Problemas que este sprint resuelve de raíz:**
1. Navegación acoplada al armado de UI: una sola pantalla monolítica, no escalable.
2. El gameplay lee entrada vía `InputMap` (`p1_fire`, …) o directamente `Input.*`:
   dependencia textual/hardcodeada que el brief pide eliminar por completo.
3. Persistencia parcial: los *perfiles* de entrada no se guardan, solo los slots.

### Arquitectura en una frase
Separar tres capas interconectadas por contrato, nunca por clases acopladas:

```
[ Capa UI ]      ──escribe/lee──▶  [ CAPA CONFIG (autoload GameConfig)   ]
                                       (datos puros + persistencia)
[ Capa Gameplay ]─consulta──▶  [ CAPA INPUT (InputManager -> InputProfile) ]
                                       (consulta acciones, NUNCA teclas)
```

- **UI** no conoce internos de Godot ni del gameplay: solo muta `GameConfig` y la
  capa de input. Es recambiable (el arte puede mejorar luego sin tocar datos).
- **Gameplay** no conoce la UI: solo consulta acciones por `player_id`.
- **Config/Input** son las dos únicas capas que saben de teclas y dispositivos.

---

## 2. Flujo completo de navegación

Cada pantalla es un **control/escena independiente** gestionada por un **router de
pila** (`UIScreenStack`). Esta es la mejora estructural clave frente al enum
monolítico: agregar o quitar pantallas no afecta a las demás.

```
                ┌─────────────────────────────┐
                │        MENÚ PRINCIPAL       │   (MC_MAIN)
                │  Jugar · Ajustes · Salir    │
                └──────────────┬──────────────┘
                               ▼
                ┌─────────────────────────────┐
                │   CONFIGURACIÓN DE PARTIDA  │   (MC_MATCH_CONFIG)
                │  reglas de la partida       │
                │  [ Continuar ]              │
                └──────────────┬──────────────┘
                               ▼
                ┌─────────────────────────────┐
                │  CONFIGURACIÓN DE JUGADORES │   (MC_PLAYERS)
                │  Slot1..4 · Humano|IA ·     │
                │  Dispositivo · [Reasignar]  │
                │  [ Iniciar Partida ]        │
                └──────┬──────────────┬───────┘
                       ▼              ▼
        ┌──────────────────────┐   ┌────────────────────────┐
        │  REASIGNAR ACCIONES  │   │  JOYSTICK LAYOUT       │  modal
        │  (lista de teclas /  │   │  (Xbox/PS/Nintdo/      │  sobre
        │   botones)           │   │   genérico)            │  MC_PLAYERS
        └──────────────────────┘   └────────────────────────┘
                       └────────────┬────────────────┘
                                    ▼
                       ┌──────────────────────┐
                       │   INICIAR PARTIDA    │  push match.tscn
                       └──────────────────────┘
```

- **Ajustes** es un branch aparte de `Jugar` que reutiliza los mismos componentes
  (selector, toggle, fila de opciones) y se define como otra pantalla del stack.
- **Back integral**: `Esc` en PC / botón de vuelta en mando SIEMPRE regresa a la
  pantalla anterior (estándar, no excepción).

---

## 3. Jerarquía de pantallas (nombres definitivos)

| Escena | Pantalla | Contenido | Rol |
|---|---|---|---|
| `menus/main_menu.tscn` | **MC_MAIN** | Jugar / Ajustes / Salir | raíz |
| `menus/match_config.tscn` | **MC_MATCH_CONFIG** | reglas de la partida, tiempos, aliados | un paso |
| `menus/players_config.tscn` | **MC_PLAYERS** | 4 slots → configuración | **núcleo del sprint** |
| `menus/keyboard_bindings.tscn` | **MC_BINDINGS_KB** | lista de acciones para reasignar | modal |
| `menus/joypad_bindings.tscn` | **MC_BINDINGS_JOY** | layout visual del mando | modal |
| `components/key_capture.tscn` | **KEY_CAPTURE** | overlay "Presione una tecla/botón…" | capa |

Cada escena es un `Control` con su propio `.gd`; todas comparten el router y los
componentes. Los modales (bindings, key_capture) se apilan sobre MC_PLAYERS sin
cambiar el flujo global.

---

## 4. Wireframes (esquema ASCII)

### MC_PLAYERS (núcleo) — un slot por fila, mismo componente reutilizable

```
 GRVITY — Configuración de Jugadores                  ◀ Volver
 ┌───────────────────────────────────────────────────────────┐
 │ Jugador 1  [Tipo: Humano ▾]   Dispositivo [Teclado ▾]     │  [Reasignar…]
 ├───────────────────────────────────────────────────────────┤
 │ Jugador 2  [Tipo: Humano ▾]   Dispositivo [Joystick 1 ▾]  │  [Reasignar…]
 │   (fila habilitada según dispositivo/ocupación)           │
 ├───────────────────────────────────────────────────────────┤
 │ Jugador 3  [Tipo: IA ▾]      (IA: sin controles)          │
 ├───────────────────────────────────────────────────────────┤
 │ Jugador 4  [Tipo: IA ▾]      (IA: sin controles)          │
 └───────────────────────────────────────────────────────────┘
 [ ◀ Volver ]                                    [ Iniciar Partida ➤ ]
```

### MC_BINDINGS_KB (teclado = lista simple, sin dibujo de teclado)

```
 Reasignar — Teclado (Jugador 1)
 Mover arriba ............. W             (clic → captura)
 Mover abajo .............. S
 Disparar ................. Click. Izq.
 Dash ...................... B
 …                               [clic sobre fila inicia captura]
```

### MC_BINDINGS_JOY (mando = diagrama esquemático del layout detectado)

```
 Joystick 1 (Xbox)               Presione un botón…
 ╭─────────────────╮    (la acción activa resalta su botón)
 │  ▲  ⍱  ⚇  ⊕     │
 ╰─────────────────╯
```

`KEY_CAPTURE` se superpone al modal mientras se reasigna y resalta el botón/tecla
presionado.

---

## 5. Componentes reutilizables (librería UI)

Todos bajo `ui/components/`, sin lógica de partida.

| Componente | Script | Responsabilidad |
|---|---|---|
| `UIScreen` | `ui_screen.gd` | base de todas las pantallas: `title`, `on_back()`, acceso al stack |
| `UIScreenStack` | `ui_screen_stack.gd` | router: `push`, `pop`, `replace`, arranque de partida |
| `MenuOptionRow` | fila: etiqueta + control (OptionButton/Toggle) | reusable en jugadores y ajustes |
| `PlayerSlotRow` | fila de slot (tipo + dispositivo + reasignar) | en MC_PLAYERS |
| `ActionRow` | etiqueta + binding + botón de captura | en MC_BINDINGS_* |
| `KeyCaptureOverlay` | captura de `InputEvent`, validación, timeout | overlay |
| `JoystickVisualizer` | dibuja mando y resalta botón activo | en MC_BINDINGS_JOY |
| `DeviceIndicator` | icono/color del estado del dispositivo (ocupado/ausente) | en slot row |

La captura (recibir evento → validar → escribir perfil) vive en `KeyCaptureOverlay`
y usa la capa de input (nunca teclas directas).

---

## 6. Arquitectura del sistema de Input Profiles

Lo central del sprint: el gameplay NUNCA vuelve a leer teclas/dispositivos, consulta
acciones por `player_id`. Toda lectura pasa por el perfil de entrada.

### Modelo de datos (ya existe y se conserva)
`InputProfile` (`modules/input/input_profile.gd`) — ya creado:
- `ACTION_NAMES`/`ACTION_LABELS`: lista canónica de acciones.
- `device_kind` (KEYBOARD/JOYSTICK), `joystick_index` (slot de menú 1..N).
- `_bindings: action -> Array[InputEvent]`, con `bind_action`, `get_events`,
  `has_binding`.
- `get_movement_vector()`, `get_action_strength()`, `is_action_pressed(action)`.
- `serialize()`/`deserialize()` → JSON-friendly → persistencia.
- Referencia `InputProfiles.resolve_joy_device(...)` (aún no existe el registro).

### Piezas nuevas propuestas (4)

| Pieza | Archivo | Responsabilidad |
|---|---|---|
| **Registro** | `modules/input/input_registry.gd` (`class_name InputProfiles`) | acceso global a los 4 perfiles; `resolve_joy_device(slot)`; `save()/load()`; defaults; detección de ocupación |
| **DeviceManager** | `modules/input/device_manager.gd` | `detect_joypads()`; mapeo slot→device_id; layout (Xbox/PS/Nintendo/genérico); eventos conexión/desconexión |
| **InputManager (refactor)** | `scripts/input_manager.gd` | delega queries al `InputProfile`; conserva la firma que ya usa el gameplay (`is_action_pressed(player, action)`, `get_movement_vector`) |
| **GameConfig** | `autoload game_config.gd` | autoridad runtime única: `PlayerSlot` (enabled/team/control) + `InputProfile` por slot; persiste todo; reemplaza el uso directo de SessionConfig en la partida |

### Query del gameplay (ejemplos)
```
operator_base.gd → _input_manager.is_action_pressed(player_id, "fire")
operator_base.gd → _input_manager.get_movement_vector(player_id)
squad_hud        → _input_manager.InputProfiles.get_profile(1).get_device_label()
```
Esto NO toca Combat / IA / Dash / Vision / Fow / Arena / HUD / Captura / Puntuación
(pila fuera de alcance). Solo cambia el *origen* de la función ya usada, no su
contrato.

### `just_pressed` y captura de eventos
El gameplay usa eventos como "habilidad" que requieren detección de borde
(`is_action_just_pressed`). Se resuelve en el registro con **edge-tracking**:
mantiene el estado previo de cada acción por perfil y re-emite el frame del cambio.
Así el gameplay queda 100% independiente del `InputMap`.

### Prevención de duplicados
`DeviceManager` expone `is_device_occupied(slot)` para que la UI marque slots
duplicados con advertencia:
- Teclado → un solo humano por teclado (el resto: joystick/IA).
- Joystick 1..N → un solo humano por slot (los ocupados se marcan).

---

## 7. Persistencia

Se guarda TODO automáticamente, sin intervención: dispositivos, perfiles, teclas,
botones y preferencias. Se carga al arranque (en `_ready` del autoload, antes del
menú).

| Dato | Estado | Archivo (`user://`) | Guardado |
|---|---|---|---|
| Slots (enabled/team/control) + **perfiles de entrada** | `GameConfig` | `gravity_config.cfg` (via `ConfigFile`) | on-change |
| Preferencias de interfaz | `GameConfig` | mismo archivo | on-change |

- `InputProfile.serialize()` → sección `input:<player>` (JSON).
- Al cargar se revalida contra `ACTION_NAMES`; se descartan ligaduras huérfanas.

---

## 8. Extensibilidad futura

| Necesidad | Qué agregar | Quién cambia |
|---|---|---|
| Nuevo dispositivo | `DeviceKind` + capa en `InputRegistry` | solo input |
| Nueva acción | entrada en `ACTION_NAMES` + default por layout | las pantallas se generan desde ahí |
| Nueva pantalla | derivar de `UIScreen` + `stack.push()` | nada más |
| Nuevo layout de mando | patrón en `DeviceManager.name_of(...)` | solo DeviceManager (si no, genérico) |

---

## 9. Estrategia de implementación (fases)

No se toca el arte hasta que el flujo rota. Fases:
1. Capa **config**: `PlayerSlot`, `GameConfig` + persistencia + carga al boot.
2. Capa **input**: `InputRegistry` (completa `InputProfile`), `DeviceManager`,
   refactor `InputManager` a delegar en perfiles.
3. **UI base**: `ui_screen.gd`, `ui_screen_stack.gd`, componentes.
4. Escenas del flujo completo (MC_MAIN → … → INICIAR).
5. **Botones/joystick**: `KeyCaptureOverlay` + layouts.
6. Pruebas automáticas + validación del checklist (§10).

---

## 10. Pruebas y validación

- Se conservan VERDE (no se toca Combat/IA/HUD): `test_match_flow` (66),
  `test_arena_reconstruction` (83), `test_terminal_hack` (35), `test_action_system`,
  `test_ai_controller` (5).
- **Pruebas nuevas** (capa input/config):
  - perfil: roundtrip `serialize/deserialize`; reemplazo con `bind_action`; defaults
    por player.
  - registro: `resolve_joy_device` y hotplug; persistencia después de reload.
  - gameplay-lee-perfil: `is_action_pressed("fire")` true solo si el evento del perfil
    está emitido (con `InputEvent` inyectado), sin InputMap.

- **Checklist de sprint** (validación manual final) 1:1.

---

## 11. Decisiones para confirmar antes de implementar

1. **Navegación:** ¿escena-por-pantalla + router (`UIScreenStack`) es la arquitectura
   definitiva, o preferís mantener un único enum `MenuPage` en una escena? (Recomiendo
   escena + router.)
2. **`GameConfig`:** ¿nuevo autoload que reemplaza a `SessionConfig` (misma firma usada
   por player_manager) o solo lo extendemos? (Recomiendo GameConfig nuevo + migrar.)
3. **`just_pressed`:** ¿edge-tracking propio del registro (sin InputMap) para 100% de
   independencia? (Recomendado.)
4. **`resolve_joy_device`:** slot de menú 1..N → el N-ésimo mando conectado. ¿OK?
5. **Detección de layout:** por nombre (`Xbox`, `Dual*`, `DualSense`, `Switch/Pro`),
   con genérico por defecto. ¿Aplica (impacta MC_BINDINGS_JOY)?
```