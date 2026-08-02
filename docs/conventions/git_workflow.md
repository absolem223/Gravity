# GIT WORKFLOW — FLUJO DE TRABAJO Y CONVENCIONES GIT

## 📌 Trunk-Based Development (ADR-0002)

### 1. Prefijos de Ramas
- `feature/[nombre_breve]`: Nueva funcionalidad bajo SPEC.
- `bugfix/[issue_id]`: Corrección de bug.
- `docs/[tema]`: Cambios puramente de documentación.
- `ai/[agente]-[tarea]`: Ramas creadas por asistentes de IA (Vida máx. 48h).
- `prototype/[nombre]`: Pruebas en `sandbox/`.

### 2. Mensajes de Commit Convencionales (Conventional Commits)
Sintaxis: `<tipo>(<alcance>): <descripción_corta>`

Tipos permitidos:
- `feat`: Nueva característica.
- `fix`: Corrección de error.
- `docs`: Cambios en documentación.
- `refactor`: Refactorización de código sin cambio de comportamiento.
- `test`: Añadir o corregir pruebas.
- `chore`: Tareas de mantenimiento o configuración.

Ejemplo: `feat(network): implement INetworkDriver interface abstraction`
