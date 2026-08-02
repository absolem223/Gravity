# ADR-0002 — Estrategia Git y Modelo de Ramificación

- **Estado**: Aprobado
- **Fecha**: 2026-08-02
- **Autores**: Chief Software Architect
- **RFC Asociado**: N/A (Decisión Fundacional)

---

## 📌 Contexto y Problema

Con múltiples desarrolladores humanos y agentes de IA trabajando simultáneamente, el uso de ramas de larga duración (como GitFlow) genera conflictos de integración (merge conflicts) masivos e intratables, especialmente en configuraciones de motor y archivos de escena.

## 💡 Decisión

Se adopta **Trunk-Based Development** como la estrategia oficial de control de versiones.

### Convenciones de Ramas:
Las ramas deben ser de vida corta y seguir una nomenclatura estricta:
- `feature/*`: Desarrollo de nuevas características bajo SPEC aprobada.
- `bugfix/*`: Corrección de errores con test de regresión.
- `docs/*`: Actualizaciones de documentación, SPECs o memoria.
- `ai/*`: Tareas ejecutadas por agentes de IA autónomos.
- `prototype/*`: Trabajo experimental destinado a `sandbox/`.

### Reglas Específicas para Agentes IA:
- Ninguna rama `ai/*` podrá permanecer abierta más de **48 horas** sin integrarse a `main` o ser descartada.
- Toda modificación estructural requerirá un RFC formal previo a la creación de la rama.

## ⚖️ Consecuencias

### Positivas
- Integración continua real y menor divergencia de código.
- Prevención activa de merge conflicts masivos.
- Flujo de trabajo óptimo para agentes de IA que operan en ciclos cortos.

### Negativas / Riesgos
- Requiere disciplina estricta en el uso de Feature Flags y tests automáticos en `main`.
