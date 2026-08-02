# PROJECT_CONTEXT.md — CONTEXTO DEL PROYECTO GRAVITY

## 📌 Resumen Ejecutivo

**PROJECT GRAVITY** es un proyecto de desarrollo multiplayer a largo plazo.

Este documento establece el marco conceptual del proyecto, definiendo sus antecedentes, dominio de problema y contexto tecnológico.

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
- **Diseño Orientado al Juego**: El software sirve al diseño del juego; las especificaciones funcionales (SPECs) preceden a la infraestructura técnica.

---

## 🔬 Ecosistema Tecnológico Fundacional

- **Motor Principal de Juego**: Godot Engine 4.x (ubicado en `game/`).
- **Lenguaje Core**: GDScript 2.0 estricto (ADR-0001).
- **Control de Versiones**: Git + Git LFS (Trunk-Based Development, ADR-0002).
- **Testing**: Framework de tests unitarios e integración en Godot (ubicados en `tests/`).
- **Servidor Autoritativo**: Desacoplado (ADR-0003), preparado para Godot Headless o simulación dedicada.

---

## 🧭 Fases del Proyecto

1. **Fase 0 — Fundacional (COMPLETADA)**: Creación del Workspace AI-Native, directivas, roles, ADRs y templates.
2. **Fase 0.5 — Game Architecture (ACTUAL)**: Diseño funcional del videojuego mediante SPECs formales de gameplay (`movement`, `camera`, `vision`, `combat`, `drone`, `hack`, `exoskeleton`, `matchmaking`, `map`, `main_loop`).
3. **Fase 1 — Infrastructure & Technical Architecture**: Implementación del `INetworkDriver`, ECS y Event Bus basados en las SPECs de la Fase 0.5.
4. **Fase 2 — Prototipado en Sandbox**: Experimentos de mecánicas y físicas en `sandbox/`.
5. **Fase 3 — Módulos de Gameplay Primarios**: Construcción modular en `game/modules/`.
