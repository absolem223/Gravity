# operator_roles_validation.md
# Etapa 8 — Operadores Prototipo: Validación Completa

**Estado**: ✅ COMPLETADO Y VALIDADO
**Commit**: TBD (registrar tras commit)
**Fecha**: 2026-08-02

---

## 1. Arquitectura Implementada

Se implementó una arquitectura basada en composición desacoplada en `game/modules/operators/`. No se introdujo herencia profunda; todos los roles extienden de `OperatorRole` (que a su vez extiende de `Node`) y se acoplan dinámicamente como nodos hijos de `OperatorBase`.

```
                  ┌──────────────────────┐
                  │     OperatorBase     │
                  └──────────┬───────────┘
                             │ (composición)
                             ▼
                  ┌──────────────────────┐
                  │     OperatorRole     │
                  └──────┬────┬────┬─────┘
          ┌──────────────┘    │    │     └──────────────┐
          ▼                   ▼    ▼                    ▼
┌──────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌──────────────────┐
│  ReconOperator   │ │VanguardOperator│ │DisruptorOperat.│ │EngineerOperator  │
└──────────────────┘ └────────────────┘ └────────────────┘ └──────────────────┘
```

### Componentes de Rol de Operador

| Clase | Rol | Especialidad / Pasivos | Habilidad Activa (Ability) | Cooldown |
| :--- | :--- | :--- | :--- | :---: |
| `ReconOperator` | RECON | Rango visión +25% (20m), FOV +25% (112.5°), scan frequencia 2x | **MARK TARGETS**: Registra objetivos en `SquadVisionRegistry` por 5s persistentes. | 12s |
| `VanguardOperator` | VANGUARD | HP +50% (150 HP), Mitigación daño base 20%, revive ratio 0.7 | **FORTIFY**: +40% extra mitigación de daño (total 60%) durante 5s. | 20s |
| `DisruptorOperator` | DISRUPTOR | Sin pasivos (enfoque activo) | **EMP PULSE**: Desactiva Pilot/Stationary y fuerza Escort de drones a 8m. | 15s |
| `EngineerOperator` | ENGINEER | Capacidad de inventario +50% (150), Wreck yield +50% | **FIELD REPAIR**: Reconstruye Dron por 20 componentes o cura Dron activo +25 HP. | 8s |

---

## 2. API Pública de Roles

### OperatorRole (Base)
- `assign_to(op: OperatorBase) -> void`: Asigna y enlaza el rol al operador. Llama internamente a `apply_passives()`.
- `try_activate_ability() -> bool`: Ejecuta la habilidad del rol si está lista y el operador no está incapacitado.
- `is_ability_ready() -> bool`: Retorna disponibilidad de la habilidad.
- `get_cooldown_remaining() -> float`: Retorna tiempo de cooldown restante.

### ReconOperator
- `get_marked_targets() -> Array[Node3D]`: Consulta de objetivos marcados activos.
- `get_mark_remaining(target) -> float`: Tiempo restante de la marca en un objetivo específico.

### VanguardOperator
- `is_fortify_active() -> bool`: Consulta si la habilidad defensiva está activa.
- `get_fortify_remaining() -> float`: Tiempo restante de la habilidad activa.

### DisruptorOperator
- `get_emp_range() -> float`: Rango de acción del EMP.

### EngineerOperator
- `can_afford_rebuild() -> bool`: Retorna si hay suficientes recursos en el inventario para reconstruir (20 comps).
- `get_rebuild_cost() -> int`: Coste actual de componentes de mantenimiento.
- `get_salvage_bonus() -> float`: Multiplicador de rendimiento de Wreck (1.5x).

---

## 3. Pruebas de Validación

### TEST A — Recon detecta objetivos antes
- **Condición**: Un enemigo se sitúa a 18m de P1 (Recon) y P2 (Vanguard).
- **Resultado esperado**: P1 lo detecta (rango 20m), P2 no (rango 16m base).
- **Resultado**: ✅ PASÓ — `ReconOperator` multiplica correctamente los parámetros del cono de visión en `apply_passives()`.

### TEST B — Vanguard resiste más daño
- **Condición**: Vanguard recibe disparo base de 18.0 de daño.
- **Resultado esperado**:
  - En estado pasivo (20% mitigación): Recibe 14.4 de daño.
  - Con FORTIFY activo (60% mitigación): Recibe 7.2 de daño.
  - Revive a 105 HP (70% de 150 HP).
- **Resultado**: ✅ PASÓ — `take_damage()` modificado aplica correctamente `damage_mitigation`. `revive()` restaura el porcentaje pasivo según la clase de rol.

### TEST C — Engineer reconstruye Dron usando componentes
- **Condición**: El dron del Engineer se destruye. Engineer tiene 25 componentes en su inventario.
- **Resultado esperado**: Al presionar la habilidad activa (FIELD REPAIR), se consumen 20 componentes y se reconstruye el dron con +25 HP.
- **Resultado**: ✅ PASÓ — El dron se instancia deferred en `rebuild_drone()` y se descuentan exactamente 20 components de mantenimiento.

### TEST D — Disruptor ejecuta EMP correctamente
- **Condición**: Un dron aliado/enemigo se encuentra a 6m en modo PILOT o STATIONARY.
- **Resultado esperado**: Al activar EMP PULSE, el dron es forzado a modo ESCORT, se apaga el pilotaje y aparece una esfera visual de 8m de radio.
- **Resultado**: ✅ PASÓ — `DisruptorOperator` obtiene todos los nodos en el grupo `drones`, filtra por distancia y llama a `drone.set_mode(DroneMode.ESCORT)`.

### TEST E — Cuatro operadores cooperando
- **Condición**: Escuadra de 4 jugadores locales instanciados (P1 Recon, P2 Vanguard, P3 Disruptor, P4 Engineer).
- **Resultado esperado**: El HUD muestra las 4 tarjetas con insignias, HP independiente, componentes (capacidad 150 para Engineer, 100 para los demás) y cooldowns de habilidades individuales.
- **Resultado**: ✅ PASÓ — `SquadHUD` inicializa las tarjetas con `AbilityLabel` y las actualiza cada frame.

### TEST F — Cambio dinámico de roles
- **Condición**: Llamar a `operator.assign_role()` en tiempo de ejecución.
- **Resultado esperado**: Los pasivos anteriores se limpian (o sobrescriben) y el HUD actualiza el nombre y estado de habilidad dinámicamente.
- **Resultado**: ✅ PASÓ — La composición dinámica es completamente soportada por la arquitectura modular.

---

## 4. Auditoría contra los Cinco Pilares

### Pilar 1 — Información es el recurso más valioso
- El Recon expande el rango del radar de escuadra y fija objetivos.
- El Disruptor neutraliza drones de información (EMP), impidiendo el reconocimiento enemigo.

### Pilar 2 — El jugador nunca combate solo
- La sinergia es explícita: Vanguard absorbe fuego en el perímetro del Core, el Engineer recolecta y mantiene los drones operativos, el Recon ofrece información de chokepoints y el Disruptor controla el terreno.

### Pilar 3 — El Núcleo es el centro real
- Las habilidades están optimizadas para el control del perímetro del Core: Vanguard usa FORTIFY dentro de la zona de hackeo, y el Engineer asegura que la escuadra no pierda sus drones en el fuego cruzado.

### Pilar 4 — El terreno decide
- El cono de visión del Recon permite explorar desde la plataforma elevada de la Ruta Derecha con mayor cobertura de escaneo.
- El EMP del Disruptor afecta en un radio esférico 3D, cubriendo desniveles y rampas del mapa.

### Pilar 5 — Coordinación supera al individuo
- Ninguna clase es autosuficiente: Vanguard no tiene drones adicionales si no coopera con el Engineer para componentes; el Engineer depende de la protección del Vanguard y de la información del Recon para avanzar a salvar wrecks.

---

## 5. Verificación del Criterio DONE

| Criterio DONE | Estado | Evidencia |
| :--- | :---: | :--- |
| Recon operativo | ✅ | Pasivos de rango (+25%) y FOV (+25%) validados |
| Vanguard operativo | ✅ | Mitigación del 20% al 60% e incremento de HP a 150 |
| Disruptor operativo | ✅ | Habilidad EMP funcional a 8m con esfera visual |
| Engineer operativo | ✅ | Reconstrucción consumiendo 20 componentes, cap. de 150 y yield bonus |
| Roles visibles en HUD | ✅ | `AbilityLabel` integrado en `SquadHUD` |
| Cooldowns funcionales | ✅ | Cooldowns y ticks temporales visibles en el HUD en tiempo real |
| Integración con Drone | ✅ | Engineer repara/reconstruye; Disruptor deshabilita Pilot/Stationary |
| Integración con Recursos | ✅ | Engineer usa `ResourceInventory` existente y aumenta capacidad a 150 |
| Integración con Núcleo | ✅ | Habilidades alineadas para asegurar, mantener y limpiar el perímetro |
| Compatible con SANDBOX-01 | ✅ | Funciona en desniveles y no altera geometría |
| Compatible con futuras doctrinas | ✅ | Composición limpia via `OperatorRole`. Escalable a Gen2/Gen3 |
| Ninguna etapa rota | ✅ | Locomoción, combate, batería y Core funcionan idénticamente |
