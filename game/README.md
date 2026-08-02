# game/ — PROYECTO GODOT 4.X

Este directorio contiene la implementación oficial de producción del juego en Godot 4.x.

## 📂 Estructura Interna

- `core/`: Sistemas de infraestructura base (red, maquina de estados, bus de eventos, cargador de datos).
- `modules/`: Funcionalidades de juego modulares desacopladas.
- `shared/`: Constantes, enums, tipos e interfaces compartidas.
- `data/`: Tablas de datos y recursos `.tres` o `.json`.

## ⚠️ Reglas de Contribución

1. **ADR-0001**: Usar exclusivamente GDScript 2.x con tipado estricto.
2. **Cero Prototipos**: Ningún experimento temporal debe commitearse en esta carpeta (utilizar `sandbox/`).
3. **SPEC Obligatoria**: No crear ningún módulo en `modules/` sin su correspondiente `SPEC` en `docs/specs/`.
