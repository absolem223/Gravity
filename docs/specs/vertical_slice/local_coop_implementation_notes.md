# LOCAL COOP IMPLEMENTATION NOTES — NOTAS DE IMPLEMENTACIÓN COOPERATIVA LOCAL

- **Estado**: Activo — Fase 1: Vertical Slice Implementation (Etapa 2)
- **Ubicación**: `docs/specs/vertical_slice/local_coop_implementation_notes.md`
- **Versión**: 1.0

---

## 🎯 Propósito

Este documento detalla la arquitectura de software del sistema cooperativo local para 2 a 4 jugadores de PROJECT GRAVITY, la gestión dinámica de dispositivos de entrada, la identidad visual de escuadra y los resultados de las pruebas de cámara cooperativa.

---

## 🏗️ ARQUITECTURA DE SUB-SISTEMAS

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SANDBOX TEST SCENE                            │
└───────────────┬─────────────────────┬───────────────────┬───────────────┘
                │                     │                   │
                ▼                     ▼                   ▼
     ┌────────────────────┐  ┌──────────────────┐  ┌──────────────┐
     │    INPUT MANAGER   │  │  PLAYER MANAGER  │  │  SQUAD HUD   │
     │                    │  │                  │  │              │
     │ - Auto-detect Joy  │  │ - Spawns P1-P4   │  │ - HP Cards   │
     │ - Input Profiles   │──► - Centroid Calc  │◄─┤ - Distances  │
     │ - Device Hotplug   │  │ - Managed Ops    │  │ - Statuses   │
     └────────────────────┘  └────────┬─────────┘  └──────────────┘
                                      │
                                      ▼
                             ┌──────────────────┐
                             │ CAMERA CONTROLLER│
                             │                  │
                             │ - Top-Down 65°   │
                             │ - Centroid Lerp  │
                             │ - Dynamic Zoom   │
                             └──────────────────┘
```

---

## 🎮 1. Gestión de Dispositivos y Perfiles de Jugador

### Clase `PlayerInputProfile`
Encapsula la configuración de hardware de cada jugador (1 a 4):

```gdscript
class PlayerInputProfile:
    enum DeviceType { KEYBOARD_MOUSE, GAMEPAD, UNASSIGNED }
    var player_id: int
    var device_id: int # -1 = Teclado/Mouse, 0+ = Gamepad ID
    var device_type: DeviceType
    var is_connected: bool
    var role_name_placeholder: String # "Recon", "Vanguard", "Disruptor", "Engineer"
```

### Reglas de Asignación Automática:
- **P1 (Jugador 1)**: Asignado por defecto a **Teclado & Mouse** (o Gamepad 0 si se conecta).
- **P2, P3, P4**: Asignados dinámicamente a **Gamepads 0, 1 y 2**.
- **Soporte Teclado Compartido (Fallback)**: Para pruebas de desarrollo sin mandos físicos, el sistema soporta 4 jugadores en un solo teclado:
  - **P1**: Teclas `WASD`
  - **P2**: Teclas `IJKL`
  - **P3**: Flechas de Dirección (`UP`, `DOWN`, `LEFT`, `RIGHT`)
  - **P4**: Teclado Numérico (`KP_8`, `KP_5`, `KP_4`, `KP_6`)

---

## 👥 2. Ciclo de Vida de Escuadra (`PlayerManager`)

- **Soporte Dinámico**: Permite pasar de 2 a 3 o 4 jugadores en caliente durante la ejecución mediante `set_active_player_count(count: int)` o teclas de prueba `[2]`, `[3]`, `[4]`.
- **Instanciación Modular**: Cada operador es una instancia independiente de `operator_base.gd` con su slot ID y color asignado.
- **Centroide de Escuadra**: `get_squad_centroid()` calcula el centro de masa 3D de la escuadra activa cada frame para consumo de la cámara y el HUD.

---

## 👁️ 3. Identidad Visual de Escuadra y Feedback

Para reforzar la pregunta *"¿Dónde está mi compañero?"* sin saturar la pantalla:

1. **Insignia 3D Flotante (`Label3D`)**:
   - Posicionada a +2.2m sobre cada operador.
   - `no_depth_test = true`: Visible a través de coberturas y paredes en el mapa.
   - Color codificado por slot (P1: Rojo, P2: Azul, P3: Verde, P4: Amarillo).
   - Muestra el rol placeholder: `P1 RECON`, `P2 VANGUARD`, `P3 DISRUPTOR`, `P4 ENGINEER`.

2. **Alerta de Separación Táctica (`SEPARATED`)**:
   - Cuando un operador se aleja más de 12 metros del centroide de la escuadra, su insignia 3D pulsa en tono de advertencia naranja e incluye el tag `[SEPARATED]`.
   - El HUD inferior actualiza su distancia en metros en tiempo real.

3. **Tarjetas de Estado en HUD (`SquadHUD`)**:
   - 4 tarjetas horizontales en la parte inferior de la pantalla.
   - Muestra la barra de salud (HP), estado de conexión del control, distancia al centroide y estado (`ACTIVE` / `DOWN` / `SEPARATED`).

---

## 📽️ 4. Resultados de Pruebas de Cámara Cooperativa

### TEST A — 4 Jugadores Juntos (Formación Compacta)
- **Resultado**: La cámara mantiene la vista Top-Down Isométrica a 65° con zoom mínimo (~12-14m de distancia). Lectura táctica óptima. La insignia 3D permite diferenciar a cada operador al instante.

### TEST B — 2 Jugadores Separados en Extremos Opuestos
- **Resultado**: El cálculo de bounding box expande el offset Z de la cámara hacia `max_zoom_distance` (~24-28m) de forma suave (`lerp`). Ambos jugadores permanecen encuadrados sin perder detalle del mapa.

### TEST C — Un Jugador Intenta Alejarse Demasiado (> 12m)
- **Resultado**: El zoom dinámico se estabiliza en su límite máximo (`max_zoom_distance = 28.0`). La insignia 3D del jugador apartado cambia a modo advertencia `[SEPARATED]` y su tarjeta en el HUD indica la distancia creciente en metros. El jugador reconoce que debe reagruparse sin que el sistema bloquee artificialmente su movimiento.
