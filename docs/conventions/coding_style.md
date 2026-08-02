# CODING STYLE — GUÍA DE ESTILO GDSCRIPT 2.X ESTRICTO

## 📌 Reglas de Estilo Oficiales (ADR-0001)

### 1. Naming Conventions (Nombres)
- **Clases y Tipos**: `PascalCase` (ej. `NetworkDriver`, `PlayerComponent`).
- **Archivos de Script**: `snake_case.gd` (ej. `network_driver.gd`).
- **Variables y Funciones**: `snake_case` (ej. `current_health`, `calculate_damage()`).
- **Constantes**: `UPPER_SNAKE_CASE` (ej. `MAX_PLAYERS`, `DEFAULT_TICK_RATE`).
- **Señales**: `snake_case` en tiempo pasado o acción (ej. `health_changed`, `player_spawned`).
- **Variables Privadas/Internas**: Prefijo `_` (ej. `var _internal_buffer: Array[int]`).

### 2. Static Typing Obligatorio
```gdscript
# CORRECTO
var player_count: int = 0
var velocity: Vector2 = Vector2.ZERO

func calculate_total(damage: float, armor: float) -> float:
	return maxf(0.0, damage - armor)

# PROHIBIDO (Sin tipar)
var player_count = 0
func calculate_total(damage, armor):
	return damage - armor
```

### 3. Uso de @export y Annotation
Organizar las variables en el inspector usando `@export_group` y `@export_subgroup`.
