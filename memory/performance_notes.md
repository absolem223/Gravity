# PERFORMANCE NOTES — NOTAS DE RENDIMIENTO DE GODOT 4.X

Notas empíricas sobre perfilado de memoria, asignación de objetos y ticks en Godot.

---

## ⚡ Directrices de Performance

1. **Evitar instanciación masiva de Nodos en Loop**: Para componentes puros de simulación de datos, preferir Diccionarios tipados o `RefCounted` en lugar de instanciar `Node` o `Node2D`/`Node3D`.
2. **Signal Overhead**: Las señales en GDScript son eficientes, pero desenganchar listeners en nodos destruidos previene leaks de memoria.
3. **Array/Dictionary Pre-allocation**: Al crear arrays o diccionarios grandes en ticks de red, especificar o reservar tamaño para evitar reubicaciones de memoria en heap.
