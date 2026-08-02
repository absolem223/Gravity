# SPEC VALIDATION: DRONE RESOURCE ECONOMY — ECONOMÍA DE PIEZAS Y EVOLUCIÓN TECNOLÓGICA

- **Estado**: Actualizado / Revisión 3.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/drone_resource_economy.md`

---

## 🎯 Separación Clave: Recursos de Evolución vs Recursos de Mantenimiento

La economía de GRAVITY se articula en torno a dos flujos de recursos diferenciados para prevenir confusiones de diseño:

```
                               ┌─────────────────────────────┐
                               │  RECURSOS TECNOLÓGICOS     │
                               └──────────────┬──────────────┘
                                              │
                    ┌─────────────────────────┴─────────────────────────┐
                    ▼                                                   ▼
┌──────────────────────────────────────┐            ┌──────────────────────────────────────┐
│  1. RECURSOS DE MANTENIMIENTO        │            │  2. RECURSOS DE EVOLUCIÓN            │
├──────────────────────────────────────┤            ├──────────────────────────────────────┤
│ - Destino: Reparar Drones destruidos │            │ - Destino: Inversión para avanzar    │
│   y sustituir módulos dañados.       │            │   de Generación 1 ➔ 2 ➔ 3.           │
│ - Dónde: En el campo / Puntos de     │            │ - Dónde: Exclusivamente en Centros   │
│   reabastecimiento ligeros.          │            │   de Integración Tecnológica.        │
│ - Dinámica: Consumo táctico rápido.  │            │ - Dinámica: Consolidación permanente.│
└──────────────────────────────────────┘            └──────────────────────────────────────┘
```

---

## 🏢 Puntos de conflicto: Centros de Integración Tecnológica

Los **Centros de Integración Tecnológica** son infraestructuras neutras ubicadas en la geometría del mapa.

- Para invertir *Recursos de Evolución* y saltar de Generación 1 a Generación 2 (o de Gen 2 a Gen 3), el operador o su dron deben canalizar el proceso físicamente en una de estas estaciones.
- **Riesgo Táctico**: La canalización emite firmas de energía detectables por los sensores enemigos. Detener un salto de Generación enemiga en un Centro de Integración es un objetivo de alta prioridad para la escuadra adversaria.

---

## 🛑 Anti-Snowballing y Rendimientos Decrecientes

1. **Límite de Almacenamiento**: Cap de componentes portados por operador (100 unidades max).
2. **Costo Escalado de Generaciones**: El salto de Gen 1 a Gen 2 requiere una inversión moderada; el salto a Gen 3 requiere una inversión masiva que exige controlar múltiples nodos del mapa.
3. **Inmutabilidad del Avance**: La Generación alcanzada es permanente (no se pierde al morir). Esto garantiza que el equipo golpeado conserve su avance tecnológico y pueda reconstruir su presencia sin caer en una espiral de atraso insuperable.
