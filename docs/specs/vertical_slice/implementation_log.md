# IMPLEMENTATION LOG — VERTICAL SLICE

- **Estado**: Activo — Fase 1: Vertical Slice Implementation
- **Ubicación**: `docs/specs/vertical_slice/implementation_log.md`
- **Versión**: 1.7

---

## 📜 REGISTRO DE IMPLEMENTACIÓN POR ETAPA

---

### 🟢 ETAPA 1 — Setup Técnico + Cámara + Movimiento Base
**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

---

### 🟢 ETAPA 2 — Input Cooperativo Local + Identidad de Escuadra
**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

---

### 🟢 ETAPA 3 — Operador Base + Combate Básico + Coberturas + Cono de Visión
**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

---

### 🟢 ETAPA 4 — Dron Gen 1 (Escorta, Estacionario, Piloto)
**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

---

### 🟢 ETAPA 5 — Mapa SANDBOX-01
**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

---

### 🟢 ETAPA 6 — Núcleo IA Funcional
**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

#### 1. Archivos Creados / Modificados
- `game/modules/ai_core/ai_core.gd` (Nuevo): Orquestador raíz que compone HackController + CoreCaptureZone + CoreStatusDisplay.
- `game/modules/ai_core/hack_controller.gd` (Nuevo): Máquina de estados (IDLE/HACKING/CONTESTED/DEGRADED/CAPTURED) y motor de progreso.
- `game/modules/ai_core/core_capture_zone.gd` (Nuevo): Area3D física para detección de operadores por equipo.
- `game/modules/ai_core/core_status_display.gd` (Nuevo): HUD del Core con parpadeo y alertas visuales.
- `game/scripts/sandbox_test_scene.gd` (Modificado): Instanciación y señales del Núcleo.
- `game/scripts/squad_hud.gd` (Modificado): Integración de CoreStrip en el HUD principal.
- `docs/specs/vertical_slice/core_system_validation.md` (Nuevo): Validación completa del Core.

#### 2. Decisiones Técnicas Ejecutadas
- **Velocidad de Hackeo Fija por Equipo**: El hackeo no aumenta su velocidad con más operadores presentes en la zona. Esto promueve el Pilar 5, haciendo que los aliados extra se concentren en cubrir las rutas.
- **Transición a DEGRADED sin reinicio instantáneo**: Si el equipo abandona la zona, el progreso decae a razón de -10% cada 30 segundos, permitiendo retomar el progreso si se regresa rápido.

---

### 🟢 ETAPA 7 — Recursos Básicos + Wreck Salvage + Economía Mínima
**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

#### 1. Archivos Creados / Modificados
- `game/modules/resources/resource_manager.gd` (Nuevo): Administrador y registry central de pickups.
- `game/modules/resources/resource_inventory.gd` (Nuevo): Inventario por operador con límite de capacidad (100).
- `game/modules/resources/resource_pickup.gd` (Nuevo): Pickup físico Area3D con mesh pulsante y label 3D.
- `game/modules/resources/wreck_salvage.gd` (Nuevo): Extiende WreckSite para generar pickups al interactuar (salvage).
- `game/modules/operator/operator_base.gd` (Modificado): Integración de inventario y API `collect_resource()`.
- `game/modules/drone/drone_base.gd` (Modificado): Spawnea WreckSalvage en lugar de WreckSite básico al destruirse.
- `game/scripts/squad_hud.gd` (Modificado): ComponentsLabel en las tarjetas del HUD de escuadra.
- `game/scripts/sandbox_test_scene.gd` (Modificado): InstanciaResourceManager y pickups/wrecks iniciales en SANDBOX-01.
- `docs/specs/vertical_slice/resource_system_validation.md` (Nuevo): Playtests A-F y auditoría de pilares.

#### 2. Decisiones Técnicas Ejecutadas
- **División de Rendimiento en 2 Pickups**: Al salvar un wreck, se generan dos pickups esparcidos para incentivar movimiento e interacción física.
- **Color de HUD Dinámico**: ComponentsLabel cambia de verde a amarillo según la capacidad ocupada del inventario.

---

### 🟢 ETAPA 8 — Operadores Prototipo (Recon, Vanguard, Disruptor, Engineer)
**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

#### 1. Archivos Creados / Modificados
- `game/modules/operators/operator_role.gd` (Nuevo): Clase base abstracta de roles tácticos (pasivos + habilidad).
- `game/modules/operators/recon_operator.gd` (Nuevo): Rol Recon (visión mejorada + ping temporal de enemigos).
- `game/modules/operators/vanguard_operator.gd` (Nuevo): Rol Vanguard (+HP, mitigación de daño y habilidad active FORTIFY).
- `game/modules/operators/disruptor_operator.gd` (Nuevo): Rol Disruptor (EMP Pulse que desactiva drones en rango).
- `game/modules/operators/engineer_operator.gd` (Nuevo): Rol Engineer ( FIELD REPAIR consumiendo componentes, cap. inventario 150 y yield bonus).
- `game/modules/operator/operator_base.gd` (Modificado): Propiedades de rol, asignación, mitigación e inputs de habilidad.
- `game/modules/resources/wreck_salvage.gd` (Modificado): Aplica el yield bonus pasivo del Engineer (1.5x) si es el recolector.
- `game/scripts/input_manager.gd` (Modificado): Mapeo de la acción de habilidad activa 'ability'.
- `game/scripts/squad_hud.gd` (Modificado): Muestra la habilidad, cooldown y estado actual de cada rol en el HUD.
- `docs/specs/vertical_slice/operator_roles_validation.md` (Nuevo): Pruebas de validación A-F y auditoría de pilares de rol.

#### 2. Decisiones Técnicas Ejecutadas
- **Composición Dinámica sobre Herencia Profunda**: Todos los roles se asocian por composición como nodos hijos de OperatorBase. Evita romper la API existente y permite reasignación en caliente.
- **Rendimiento Mejorado de Salvaje para el Ingeniero**: Engineer obtiene un 1.5x en yield de componentes, acelerando la economía del equipo.

---

## ⚠️ ANÁLISIS DE RIESGOS PARA LA ETAPA 9 (IA Defensora)

1. **VisionCone3D y SquadVisionRegistry con Múltiples Enemigos**:
   - *Riesgo*: Al introducir múltiples patrullas enemigas, la frecuencia de escaneo (0.1s base / 0.05s Recon) puede causar spikes de CPU si hay demasiados raycasts concurrentes.
   - *Mitigación*: Implementar throttling dinámico en el scan_interval de los enemigos según su distancia al operador más cercano.

2. **Drones Enemigos y EMP del Disruptor**:
   - *Riesgo*: El EMP del Disruptor actualmente desactiva drones. Con drones enemigos patrullando, el EMP debe distinguir su equipo (team_id) para no desactivar drones aliados accidentalmente, o bien ser un efecto de área total neutral.
   - *Mitigación*: En la Etapa 9, definir la lógica de team_id en el EMP del Disruptor para filtrar por equipo atacante/defensor.
