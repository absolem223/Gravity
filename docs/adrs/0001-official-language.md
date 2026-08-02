# ADR-0001 — Lenguaje Oficial del Proyecto (GDScript 2.x Estricto)

- **Estado**: Aprobado
- **Fecha**: 2026-08-02
- **Autores**: Chief Software Architect
- **RFC Asociado**: N/A (Decisión Fundacional)

---

## 📌 Contexto y Problema

Se requiere definir el lenguaje de programación principal para el desarrollo del proyecto **GRAVITY**. El lenguaje debe permitir una alta velocidad de iteración, integración nativa con Godot 4.x, legibilidad clara para agentes de IA y facilidad de tipado estricto.

## 💡 Decisión

Se adopta **GDScript 2.x con tipado estricto** como el lenguaje oficial y obligatorio para todo el proyecto (`game/`).

### Políticas de Aplicación Obligatorias:
1. Todo sistema nuevo debe implementarse inicialmente en GDScript.
2. Ningún sistema podrá implementarse directamente en C++ o C#.
3. La migración de un módulo a GDExtension (C++) requerirá un RFC específico acompañado de benchmarks cuantitativos que demuestren objetivamente la necesidad del cambio.
4. No se realizarán optimizaciones prematuras. El objetivo del MVP es validar arquitectura y gameplay, no maximizar el rendimiento sintético.

## ⚖️ Consecuencias

### Positivas
- Máxima velocidad de iteración y prototipado.
- Compatibilidad perfecta con agentes de IA y herramientas de análisis estático de GDScript.
- Menor complejidad de compilación y CI/CD en comparación con C++.

### Negativas / Riesgos
- Posible menor rendimiento absoluto en bucles intensivos de CPU en comparación con C++. (Mitigado por la posibilidad de migrar cuellos de botella aislados vía RFC en el futuro).
