# SPEC VALIDATION: DESIGN VALIDATION — AUDITORÍA DE GENERACIONES Y PILARES

- **Estado**: Actualizado / Revisión 3.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/design_validation.md`

---

## 🎯 Auditoría del Sistema de Generaciones Tecnológicas

El **Sistema de Generaciones Tecnológicas** (`technology_generation_system.md`) ha sido auditado de forma estricta contra los 5 Pilares de Diseño de GRAVITY.

```
┌─────────────────────────────────────────────────────────────┐
│ 1. LA INFORMACIÓN ES EL RECURSO MÁS VALIOSO                 │
│    La elección de Doctrina en Gen 2 depende de la lectura   │
│    de la información enemiga.                               │
├─────────────────────────────────────────────────────────────┤
│ 2. EL JUGADOR NUNCA COMBATE SOLO                            │
│    Las Gen 2 y 3 potencian la Tríada Operador-Exo-Dron y la │
│    interconexión con la escuadra.                           │
├─────────────────────────────────────────────────────────────┤
│ 3. EL OBJETIVO ES CONTROLAR EL NÚCLEO IA                    │
│    Evolucionar a Gen 2/3 en los Centros Tecnológicos es el  │
│    medio para dominar el perímetro del Núcleo IA.           │
├─────────────────────────────────────────────────────────────┤
│ 4. EL TERRENO DECIDE LA BATALLA                             │
│    La progresión exige controlar físicamente los Centros de │
│    Integración Tecnológica en la geometría del mapa.        │
├─────────────────────────────────────────────────────────────┤
│ 5. LA COOPERACIÓN SUPERA AL HÉROE INDIVIDUAL                │
│    Los Efectos de Red de Gen 3 benefician a toda la escuadra│
│    y exigen sinergia dobles entre roles.                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔒 DECISIONES CONFIRMADAS (Inmutables)

1. **La Información como Recurso Principal**:
   - Disparar sin información es letal. El TTK frontal sin datos es elevado.
2. **El Dron como Extensión Permanente del Operador**:
   - Tríada Táctica: *Operador + Exoesqueleto + Dron Permanente*.
3. **Generaciones Tecnológicas Permanentes**:
   - La progresión es irreversible en la partida (Gen 1 ➔ Gen 2 ➔ Gen 3). No se pierden por morir.
4. **Infraestructura Física para Evolucionar**:
   - El avance a Gen 2 y 3 requiere acceso y canalización física en Centros de Integración Tecnológica en el mapa.
5. **Separación de Recursos**:
   - *Recursos de Mantenimiento* (reparar drones destruidos) vs *Recursos de Evolución* (subir de Generación).
6. **Objetivo Basado en Operación Tecnológica del Núcleo IA**:
   - Control del perímetro por presencia de red, no un "plantar bomba".
7. **La Cooperación es Superior al Héroe Individual**:
   - Efectos de Red en Gen 3 potencian a la escuadra completa.

---

## 🔓 DECISIONES ABIERTAS (En Proceso de Profundización)

1. **Arboles Específicos de Módulos por Rama de Gen 2**:
   - Opciones exactas de módulos por rama en `technology_generation_system.md`.
2. **Tiempo Exacto de Canalización en Centros Tecnológicos**:
   - Prototipado del tiempo de vulnerabilidad durante la síntesis en `sandbox/`.
3. **Límite de Piezas de Mantenimiento por Jugador**:
   - Prototipado del Cap de almacenamiento (actualmente estimado en 100 unidades).
