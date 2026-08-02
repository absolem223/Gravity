# LESSONS LEARNED — LECCIONES APRENDIDAS

Registro histórico de lecciones aprendidas durante la construcción de GRAVITY.

---

## 📅 Registro de Lecciones

### 2026-08-02 — Fundado del Workspace AI-Native
- **Lección**: Separar físicamente el proyecto Godot (`game/`) de los docs, tests y assets previene que el editor de Godot reindexe miles de archivos markdown o temporales en cada recarga.
- **Acción**: Se utilizaron archivos `.gdignore` en `sandbox/`, `docs/`, `memory/`, `assets/` y `tests/`.
