# GODOT NOTES — APUNTES Y PECULIARIDADES DE GODOT 4.X

Notas de comportamiento específico del motor Godot 4.x para orientación de desarrolladores y Agentes IA.

---

## 🔍 Reglas Específicas de Godot 4.x

1. **GDScript 2.0 Static Typing**:
   - Utilizar `@export` solo cuando la propiedad necesite ser inspeccionada en el Editor.
   - El operador `as` retorna `null` si el cast falla (en lugar de arrojar crash runtime), por lo que siempre debe verificarse `if obj != null:`.
2. **Resource Uniqueness**:
   - Los recursos `.tres` son compartidos por defecto entre instancias. Si un componente Data-Driven necesita mutar su estado local, debe invocar `.duplicate()`.
3. **Headless Execution**:
   - Ejecutar la simulación autoritativa usando la bandera `--headless` en CLI.
