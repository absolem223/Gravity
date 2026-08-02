# PRINCIPLES.md — PRINCIPIOS DE INGENIERÍA DE SOFTWARE

## 💡 Filosofía de Desarrollo

Este documento especifica los principios de ingeniería que rigen la escritura de código, arquitectura de componentes y flujo de trabajo en **PROJECT GRAVITY**.

---

## 📐 Principios Fundamentales

### 1. Single Source of Truth (SSOT)
La documentación del repositorio (`docs/`) es la única fuente oficial de verdad. Ninguna funcionalidad se implementa sin una especificación formal previa en `docs/specs/`.

### 2. Desacoplamiento Estricto (Loose Coupling)
- Los módulos deben comunicarse exclusivamente a través de interfaces, eventos/señales tipadas o buffers de datos serializables.
- Ningún módulo debe conocer los detalles de implementación interna de otro módulo.

### 3. Inmutabilidad y Cero Estado Global Descontrolado
- Los datos de estado deben transmitirse mediante objetos o diccionarios inmutables/recursos tipados.
- Se prohíben las variables globales mutables sin control de acceso o eventos de cambio.

### 4. Simulación Separada de la Presentación
- La simulación lógica (movimiento, cálculo de atributos, reglas de red) no debe depender de nodos visuales (`Node2D`, `Node3D`, `Sprite`, `AudioStreamPlayer`).
- La capa visual únicamente "escucha" o "lee" el estado de la simulación para renderizarlo.

### 5. Tipado Estricto Obligatorio (GDScript 2.x)
- Todo parámetro de función, retorno y variable debe estar estrictamente tipado.
- `void`, `int`, `float`, `StringName`, `Array[Type]`, `Dictionary` estructurado.
- El uso de `Variant` indocumentado está estrictamente prohibido a menos que el patrón de datos lo requiera explícitamente y esté documentado.

### 6. Cero Deuda Técnica Acumulada
- Todo `TODO` o `FIXME` en el código debe estar asociado a una Issue o RFC registrada.
- Todo bug resuelto debe incorporar un test de regresión en `tests/` para garantizar que no vuelva a reproducirse.

### 7. Respeto por la Memoria Institucional
- Antes de abordar un problema complejo, es obligatorio consultar `memory/lessons_learned.md` y `memory/godot_notes.md`.
