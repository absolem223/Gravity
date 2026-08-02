# PROJECT_CONTEXT.md — CONTEXTO DEL PROYECTO GRAVITY

## 📌 Resumen Ejecutivo

**PROJECT GRAVITY** es un proyecto de desarrollo multiplayer a largo plazo.

Este documento establece el marco conceptual del proyecto, definiendo sus antecedentes, dominio de problema y contexto tecnológico, **sin fijar prematuramente mecánicas de juego ni contenido artístico específico**.

---

## 🎯 Contexto de Dominio

### 1. El Desafío de los Juegos Multiplayer Modernos
Los proyectos de juegos multiplayer frecuentemente sufren de:
- Acoplamiento tóxico entre la simulación y la representación visual.
- Desincronización de estado entre cliente y servidor.
- Dificultad extrema para mantener tests automatizados.
- Merge conflicts masivos producidos por archivos binarios de motores de juego.
- Falta de contratos claros para la asistencia mediante herramientas de Inteligencia Artificial.

### 2. La Solución GRAVITY
GRAVITY responde a estos desafíos mediante:
- **Separación tajante de responsabilidades**: La lógica de simulación pura es 100% independiente del renderizado y el motor.
- **Enfoque Data-Driven**: Los parámetros de entidades no se hardcodean en scripts.
- **Workspace AI-Native**: Documentación hiper-estructurada como interfaz para modelos de lenguaje y agentes autónomos.

---

## 🔬 Ecosistema Tecnológico Fundacional

- **Motor Principal de Juego**: Godot Engine 4.x (ubicado en `game/`).
- **Lenguaje Core**: GDScript 2.0 estricto (ADR-0001).
- **Control de Versiones**: Git + Git LFS (Trunk-Based Development, ADR-0002).
- **Testing**: Framework de tests unitarios e integración en Godot (ubicados en `tests/`).
- **Servidor Autoritativo**: Desacoplado (ADR-0003), preparado para Godot Headless o simulación dedicada.

---

## 🧭 Fases del Proyecto

1. **Fase 0 — Fundacional (ACTUAL)**: Creación del Workspace AI-Native, directivas, roles, ADRs, SPECs y templates. Cero código de gameplay.
2. **Fase 1 — Core Network & ECS Primitives**: Implementación de la simulación autoritativa básica, replicación de estado y contratos de componentes.
3. **Fase 2 — Prototipado en Sandbox**: Experimentos de mecánicas y físicas en `sandbox/`.
4. **Fase 3 — Módulos de Gameplay Primarios**: Construcción modular en `game/modules/`.
