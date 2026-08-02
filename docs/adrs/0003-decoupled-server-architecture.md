# ADR-0003 — Arquitectura de Servidor Desacoplada

- **Estado**: Aprobado
- **Fecha**: 2026-08-02
- **Autores**: Chief Software Architect
- **RFC Asociado**: N/A (Decisión Fundacional)

---

## 📌 Contexto y Problema

El proyecto GRAVITY es *Multiplayer First*. No obstante, comprometer la arquitectura a una solución de hosting o infraestructura específica de servidor dedicado en esta etapa prematura podría encorsetar el proyecto o acoplarlo innecesariamente al motor.

## 💡 Decisión

No se tomará ninguna decisión definitiva respecto a la infraestructura del servidor dedicado en la Fase 0.

La arquitectura del código de red en `game/core/network/` deberá mantenerse estrictamente desacoplada para permitir indistintamente en el futuro:
- Godot Headless en contenedor Docker.
- Dedicated Server independiente (C++, Rust o Go).
- Arquitectura de microservicios distribuida.
- Cualquier otra tecnología de backend multiplayer.

## ⚖️ Consecuencias

### Positivas
- Total libertad tecnológica futura para escalar el backend.
- Cero acoplamiento entre la simulación de juego y el proveedor de servidores.

### Negativas / Riesgos
- Exige diseñar capas de abstracción e interfaces puras (`INetworkDriver`, `INetworkSerializer`) desde el primer día.
