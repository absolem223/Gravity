# docs/specs/vertical_slice/ — VERTICAL SLICE DESIGN

Esta carpeta contiene la documentación de **Fase 1: Vertical Slice Design** de PROJECT GRAVITY.

La Fase 1 comienza oficialmente después del cierre de la Fase 0.5 — Game Architecture.

---

## 🎯 Objetivo de esta Fase

Construir el primer prototipo jugable que responda la pregunta:

> **"¿El núcleo táctico de GRAVITY es divertido?"**

---

## 📄 Documentos

### [vertical_slice_scope.md](file:///E:/GRAVITY/docs/specs/vertical_slice/vertical_slice_scope.md)
Define el alcance completo del primer prototipo jugable:
- 2 a 4 jugadores cooperativo local.
- 4 operadores prototipo (1 por rol: Recon, Vanguard, Tech Disruptor, Field Engineer).
- Dron Gen 1 con 3 modos: Escolta, Estacionario, Piloto.
- Sistema de recursos simplificado (solo Mantenimiento).
- Núcleo IA con estados Activo / Contestado / Degradación.
- Mapa de prueba SANDBOX-01 con 3 rutas, elevación y conductos.

### [vertical_slice_validation_plan.md](file:///E:/GRAVITY/docs/specs/vertical_slice/vertical_slice_validation_plan.md)
Define las 12 preguntas concretas que el prototipo debe ser capaz de responder, organizadas en 5 bloques:
- **Bloque A** — Sistema de Información (A1, A2).
- **Bloque B** — Sistema del Dron (B1, B2, B3).
- **Bloque C** — Objetivo del Núcleo IA (C1, C2, C3).
- **Bloque D** — Cooperación y Roles (D1, D2, D3).
- **Bloque E** — Experiencia General (E1).

Incluye criterios de aprobación y fallo, y plantilla de registro de sesión de playtest.

---

## 🔴 Decisión Técnica Prioritaria

La perspectiva de cámara del Vertical Slice está **sin decidir**. Es la primera decisión del equipo de desarrollo antes de construir el mapa SANDBOX-01.

Ver: [technical_requirements_preview.md → DT-01](file:///E:/GRAVITY/docs/specs/validation/technical_requirements_preview.md)
