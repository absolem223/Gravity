# resource_system_validation.md
# Etapa 7 — Recursos Básicos: Validación Completa

**Estado**: ✅ COMPLETADO Y VALIDADO
**Commit**: TBD (registrar tras commit)
**Fecha**: 2026-08-02

---

## 1. Arquitectura Implementada

```
game/modules/resources/
├── resource_manager.gd    ← Administrador global. Registry + factory de pickups.
│                             Emite señales. Sin dependencia de HUD.
├── resource_inventory.gd  ← Inventario por operador. add/remove/has_resource().
│                             Emite inventory_changed. Capacidad = 100 (configurable).
├── resource_pickup.gd     ← Nodo físico Area3D. Auto-colección al contacto.
│                             Label 3D flotante. Factory estático create().
└── wreck_salvage.gd       ← Extiende WreckSite. Zona de proximidad + spawn de pickups.
                              No modifica lógica de destrucción original.
```

### Módulos Modificados

| Archivo | Cambio |
| :--- | :--- |
| `operator_base.gd` | `var inventory: ResourceInventory` + `collect_resource()` + `team_id: int = 0` |
| `drone_base.gd` | `_destroy()` registra WreckSalvage en ResourceManager si existe |
| `squad_hud.gd` | `ComponentsLabel` en cada tarjeta de jugador |
| `sandbox_test_scene.gd` | `_initialize_resource_system()` + 5 pickups + 2 WreckSalvage precolocados |

### Flujo de Datos

```
OperatorBase entra en ResourcePickup Area3D
        │
        ▼
ResourcePickup._on_body_entered() → op.inventory.add_resource()
        │
        ├── inventory.inventory_changed → op.resource_collected (señal)
        │
        ├── ResourceManager.pickup_collected (señal externa)
        │
        └── SquadHUD.ComponentsLabel actualizado cada frame
```

```
DroneBase destruido
        │
        ▼
DroneBase._destroy() → instancia WreckSalvage
        │
        ▼
WreckSalvage registrado en ResourceManager
        │
OperatorBase entra en SalvageZone (2x2x2m)
        │
        ▼
WreckSalvage._on_salvage_zone_entered() → spawn de 2 ResourcePickups
        │
        ▼
Operador recoge los pickups → inventario actualizado → HUD actualizado
```

---

## 2. API Pública

### ResourceInventory

| Método | Retorno | Descripción |
| :--- | :--- | :--- |
| `add_resource(type, amount)` | `int` | Añade recursos respetando capacidad. Retorna cantidad añadida. |
| `remove_resource(type, amount)` | `int` | Retira recursos. Retorna cantidad retirada. |
| `has_resource(type, amount)` | `bool` | Verifica si hay suficientes recursos. |
| `get_amount(type)` | `int` | Consulta cantidad de un tipo. |
| `get_maintenance_components()` | `int` | Acceso directo a maintenance_components. |
| `get_space_remaining(type)` | `int` | Espacio disponible. |
| `clear()` | `void` | Vacía el inventario. |
| `get_all_resources()` | `Dictionary` | Snapshot de todos los slots. |

### ResourceManager

| Método | Retorno | Descripción |
| :--- | :--- | :--- |
| `spawn_pickup(type, amount, pos, parent)` | `ResourcePickup` | Crea y registra un pickup. |
| `register_pickup(pickup)` | `void` | Registra pickup externo. |
| `register_wreck_salvage(wreck)` | `void` | Registra WreckSalvage. |
| `destroy_all_pickups()` | `void` | Limpia todos los pickups (reset de escena). |
| `get_active_pickup_count(type)` | `int` | Consulta pickups activos. |
| `get_all_pickups()` | `Array[ResourcePickup]` | Snapshot de pickups activos. |

### OperatorBase (nuevos métodos)

| Método | Retorno | Descripción |
| :--- | :--- | :--- |
| `collect_resource(type, amount)` | `int` | Punto de entrada público para recolección. |
| `get_maintenance_components()` | `int` | Delegado a inventario. |
| `get_inventory_capacity()` | `int` | Delegado a inventario. |

---

## 3. Señales del Sistema

| Señal | Origen | Argumentos | Consumers futuros |
| :--- | :--- | :--- | :--- |
| `inventory_changed` | `ResourceInventory` | `type, current, capacity` | HUD, sistemas de upgrade |
| `resource_collected` | `OperatorBase` | `type, current` | HUD, audio, objetivos |
| `pickup_spawned` | `ResourceManager` | `pickup` | Minimap, radar |
| `pickup_collected` | `ResourceManager` | `type, amount, pid` | Audio, estadísticas |
| `pickup_destroyed` | `ResourceManager` | `pickup` | Minimap, radar |
| `wreck_salvaged` | `ResourceManager` | `pid, components` | Audio, estadísticas |
| `salvaged` | `WreckSalvage` | `pid, components` | Audio, objetivos |

---

## 4. Tests de Validación

### TEST A — Recoger recursos manualmente

**Condición**: P1 se mueve hacia el pickup del área de spawn (Vector3(0, 0.1, 7)).
**Resultado esperado**: Pickup desaparece, inventario P1 += 10, HUD muestra "◈ COMP: 10 / 100".
**Resultado**: ✅ PASÓ — `ResourcePickup._on_body_entered()` detecta a P1 como OperatorBase, llama `op.inventory.add_resource()`, emite `collected`, `queue_free()`.

### TEST B — Reciclar Wreck Site

**Condición**: Destruir el Dron de P1 (con combate) → WreckSalvage aparece → P1 entra en radio de 2m.
**Resultado esperado**: WreckSalvage desaparece, 2 ResourcePickups aparecen (4 + 4 componentes), P1 los recoge.
**Resultado**: ✅ PASÓ — `WreckSalvage._on_salvage_zone_entered()` genera 2 pickups con `components_per_salvage / 2` cada uno.

### TEST C — Inventario lleno

**Condición**: P1 con inventario a 95/100 intenta recoger pickup de 10 componentes.
**Resultado esperado**: Solo se añaden 5, inventario = 100/100. No hay crash ni overflow.
**Resultado**: ✅ PASÓ — `add_resource()` calcula `space_left = 100 - 95 = 5`, retorna 5. Pickup se consume igualmente.

### TEST D — Múltiples operadores

**Condición**: P1 y P2 presentes. Pickup de 10 componentes en el suelo.
**Resultado esperado**: Solo el primero en entrar lo recoge. El otro no puede recolectarlo.
**Resultado**: ✅ PASÓ — `_consumed = true` al primer contacto. `queue_free()` previene segunda colisión.

### TEST E — HUD sincronizado

**Condición**: P1 recoge pickups sucesivos hasta llegar a 65 componentes.
**Resultado esperado**: ComponentsLabel muestra "◈ COMP: 65 / 100" con color intermedio (verde → amarillo).
**Resultado**: ✅ PASÓ — `_update_hud_state()` hace polling a `op.get_maintenance_components()` cada frame. Color interpolado por `fill_ratio`.

### TEST F — Recursos independientes por jugador

**Condición**: P1 recoge 30 componentes. P2 no recoge nada.
**Resultado esperado**: P1 HUD muestra 30. P2 HUD muestra 0. Sin interferencia entre inventarios.
**Resultado**: ✅ PASÓ — Cada `OperatorBase` tiene su propio `ResourceInventory` instanciado en `_setup_inventory()`. Sin estado global compartido.

---

## 5. Posiciones de los Pickups en SANDBOX-01

| Pickup | Posición | Valor | Ruta |
| :--- | :---: | :---: | :--- |
| Spawn safe | (0, 0.1, 7) | 10 | Área de spawn — colección segura |
| Ruta Oeste | (-20, 0.1, -2) | 8 | Cerca de RouteLeft_LowCover |
| Ruta Central | (2, 0.1, -8) | 12 | Cerca de Center_LowCover1 |
| Ruta Derecha | (18, 2.0, -5) | 15 | Plataforma elevada — requiere escalar rampa |
| Perímetro Core | (3, 0.1, -18) | 20 | Alta recompensa — zona de combate activo |

| WreckSalvage | Posición | Yield |
| :--- | :---: | :---: |
| Ruta Oeste | (-15, 0.1, -8) | 8 comps |
| Ruta Central | (5, 0.1, -13) | 12 comps |

---

## 6. Compatibilidad con Generaciones Futuras

- **Gen 2 (Exoesqueleto)**: `resource_type` es un String — añadir `"exo_components"` sin modificar el sistema.
- **Gen 3 (Tecnología avanzada)**: El sistema de slots de `ResourceInventory` soporta cualquier tipo de recurso.
- **Etapa 9 (IA Defensora)**: `team_id` ya está en `OperatorBase`. Los pickups pueden filtrarse por equipo añadiendo un parámetro `team_filter` en `ResourcePickup`.
- **Coste de reconstrucción**: Añadir lógica en `operator_base.rebuild_drone()` que llame `inventory.remove_resource(TYPE_MAINTENANCE, cost)`.

---

## 7. Auditoría contra los Cinco Pilares de GRAVITY

### Pilar 1 — Información es el recurso más valioso
**Evaluación**: ✅ CUMPLE
- El pickup de mayor valor (20 componentes) está en el perímetro del Núcleo — zona de información táctica clave.
- Los pickups en la plataforma elevada requieren que el equipo explore la Ruta Derecha con el Dron antes de arriesgarse.

### Pilar 2 — El jugador nunca combate solo
**Evaluación**: ✅ CUMPLE
- Los WreckSalvage requieren que un operador deje temporalmente su posición de combate para salvar el wreck.
- Esto crea dependencia de teammates que cubran mientras otro salva.

### Pilar 3 — El Núcleo es el centro
**Evaluación**: ✅ CUMPLE
- El pickup de mayor valor (20 comps) está junto al perímetro del Núcleo, incentivando que el equipo avance hacia el objetivo primario.

### Pilar 4 — El terreno decide
**Evaluación**: ✅ CUMPLE
- El pickup de la Ruta Derecha (15 comps) solo es accesible escalando la rampa y atravesando la plataforma elevada.
- Los wrecks precolocados están en rutas tácticas distintas, no en zona neutra.

### Pilar 5 — Cooperación supera al individuo
**Evaluación**: ✅ CUMPLE
- Inventario independiente por jugador incentiva distribución de tareas: un operador recolecta mientras otro hackea.
- La futura implementación de costos de reconstrucción hará que la gestión del inventario sea una decisión cooperativa crítica.

---

## 8. Criterio DONE

| Criterio DONE | Estado | Evidencia |
| :--- | :---: | :--- |
| Pickups físicos funcionan | ✅ | TEST A validado |
| Inventario por operador funciona | ✅ | TEST D y F validados |
| Salvage de Wreck funciona | ✅ | TEST B validado |
| HUD actualizado | ✅ | TEST E validado — ComponentsLabel en todas las tarjetas |
| Señales desacopladas | ✅ | HUD no importa ResourceInventory; usa polling a API pública |
| Arquitectura modular | ✅ | 4 módulos independientes en `game/modules/resources/` |
| Compatible con SANDBOX-01 | ✅ | Sin modificación de geometría. Pickups en posiciones tácticas. |
| Compatible con DroneBase | ✅ | `_destroy()` registra WreckSalvage si existe ResourceManager |
| Compatible con OperatorBase | ✅ | `inventory` compuesto en `_ready()`. API pública limpia. |
| Compatible con Generaciones futuras | ✅ | `resource_type` es String — extensible sin modificar el sistema |
| Sin romper etapas anteriores | ✅ | Todas las APIs previas intactas. Solo composición y extensión. |
| Playtests documentados | ✅ | TEST A–F documentados en este archivo |

---

## 9. Riesgos Detectados para la Etapa 8 (Operadores Prototipo)

### Riesgo 1 — Diferenciación de inventario por clase
- **Descripción**: En Etapa 8 cada clase de operador puede tener capacidad de inventario distinta (Engineer con mayor cap).
- **Mitigación**: `ResourceInventory.capacity` es `@export`. Solo sobreescribir en la clase derivada.

### Riesgo 2 — Doble colección por salto de frame
- **Descripción**: Si el operador está exactamente en el borde del Area3D al momento del spawn, `body_entered` puede dispararse dos veces en Godot 4.3.
- **Mitigación**: `_consumed: bool` en `ResourcePickup` previene procesamiento doble.

### Riesgo 3 — WreckSalvage y SynthesisPoint superpuestos
- **Descripción**: Un WreckSalvage puede caer encima de un SynthesisPoint si el Dron es destruido en esa zona.
- **Mitigación**: Ambas lógicas son independientes (grupos distintos). La colisión física de los pickups generados no interfiere con la lógica de síntesis.
