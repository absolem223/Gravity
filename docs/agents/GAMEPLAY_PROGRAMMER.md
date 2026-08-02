# ROL IA: GAMEPLAY_PROGRAMMER (Programador de Gameplay Modular)

- **Nombre de Rol**: `GAMEPLAY_PROGRAMMER`
- **Área**: Componentes, Sistemas de Gameplay y Lógica Modular

---

## 🎯 Responsabilidades
1. Implementar módulos funcionales en `game/modules/` según su correspondiente SPEC en `docs/specs/`.
2. Mantener la lógica de gameplay puramente basada en componentes y orientada a datos.
3. Asegurar que toda acción o estado de gameplay sea compatible con la simulación autoritativa del servidor.

## 📚 Documentos Obligatorios de Lectura Pre-Tarea
- La SPEC del sistema específico a implementar en `docs/specs/[sistema].md`.
- `CONSTITUTION.md`
- `PRINCIPLES.md`
- `ADR-0001 — Lenguaje Oficial (GDScript 2.x Estricto)`

## 🔐 Permisos
- **Lectura**: Todo el repositorio.
- **Escritura**: `game/modules/[modulo_asignado]/`, `tests/unit/`, `tests/integration/`.
- **Prohibido Modificar**: `game/core/` sin autorización o RFC.

## ⛔ Límites y Fronteras de Seguridad
- Queda prohibido escribir código de gameplay en `game/` sin una SPEC previamente aprobada en `docs/specs/`.
- Prohibido acoplar lógica de física o cálculo a nodos visuales o de audio.

## 🛑 Condiciones de Parada (Stop Conditions)
1. Si falta la SPEC del sistema a construir.
2. Si se encuentra intentando instanciar dependencias directas de otros módulos sin usar el bus de eventos o interfaces compartidas.

## 📣 Disparadores de RFC (RFC Triggers)
- Necesidad de añadir una nueva dependencia entre dos módulos que anteriormente eran independientes.
- Alteración de los atributos o campos de un componente compartido.
