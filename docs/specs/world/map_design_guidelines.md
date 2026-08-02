# SPEC: MAP DESIGN GUIDELINES — GEOMETRÍA, CONDUCTOS Y CENTROS TECNOLÓGICOS

- **Estado**: Actualizado / Revisión 3.0 (Fase 0.5 — Game Architecture)
- **Dominio**: World & Environment
- **Ubicación**: `docs/specs/world/map_design_guidelines.md`

---

## 🎯 Arquitectura de Puntos de Interés (POIs)

Los mapas de GRAVITY estructuran el terreno alrededor de **dos tipos de Puntos de Interés Primarios**:

1. **La Arena del Núcleo IA (Central)**: El área de mayor riesgo, diseñada con coberturas interactiva y conductos de drones en el perímetro de descarga.
2. **Los Centros de Integración Tecnológica (Flancos / Laterales)**: Estaciones físicas neutrales donde los jugadores canalizan su evolución a **Generación 2 y 3**.

```
                       ┌─────────────────────────┐
                       │   CENTRO TECNOLÓGICO A  │
                       │    (Flanco Izquierdo)   │
                       └────────────┬────────────┘
                                    │
                                    ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│     SPAWN ESCUADRA 1    │<─>│     ARENA DEL NÚCLEO    │<─>│  SPAWN ESCUADRA 2
└─────────────────────────┘   │        (Centro)         │   └─────────────────────────┘
                                  └────────────┬────────────┘
                                               │
                                               ▼
                       ┌─────────────────────────┐
                       │   CENTRO TECNOLÓGICO B  │
                       │     (Flanco Derecho)    │
                       └─────────────────────────┘
```

---

## 📐 Reglas de Posicionamiento de los Centros de Integración

- **Cero Estaciones en Spawn**: Ningún Centro de Integración Tecnológica puede estar dentro de la zona segura de reaparición (*Spawn Safe Zone*). La evolución a Gen 2 exige tomar terreno neutro.
- **Líneas de Visión Expuestas**: El punto de canalización del Centro de Integración posee aperturas y ventanas que permiten el escaneo por Drones enemigos, impidiendo que un equipo evolucione a Gen 2/3 de forma totalmente invisible.
- **Rutas de Conductos de Drones**: Todos los Centros de Integración cuentan con un ducto secundario de dron que permite a un Dron en modo piloto realizar la canalización de evolución de forma remota mientras el operador se cubre.
