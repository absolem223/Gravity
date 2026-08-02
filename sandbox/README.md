# SANDBOX — ESPACIO DE EXPERIMENTACIÓN Y PROTOTIPADO

Este directorio está destinado **exclusivamente a prototipos, experimentos, benchmarks y pruebas temporales**.

## 📜 Reglas de Sandbox

1. **Aislamiento**: Nada de lo desarrollado aquí afecta el código de producción en `game/`.
2. **Cero Garantía de Calidad**: El código en `sandbox/` no requiere cumplimiento estricto de ADRs ni SPECs.
3. **Limpieza Periódica**: Todo prototipo completado debe ser promovido a `game/` mediante un RFC/PR limpio, o descartado.
4. **Prohibición de Importación Directa**: `game/` NO puede importar ni depender de archivos dentro de `sandbox/`.
