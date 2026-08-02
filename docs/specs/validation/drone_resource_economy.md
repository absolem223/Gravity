# SPEC VALIDATION: DRONE RESOURCE ECONOMY — REVISIÓN 4.0

- **Estado**: Actualizado / Revisión 4.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/drone_resource_economy.md`

---

## 🎯 El Principio de la Economía de Recursos

La economía tecnológica de GRAVITY está diseñada para hacer que **el dominio del campo de batalla** — y no el conteo de bajas — sea la fuente principal de prosperidad tecnológica.

---

## 💰 Los Dos Flujos de Recursos

La economía se articula en torno a dos flujos completamente distintos e incompatibles entre sí:

```
┌───────────────────────────────────────────────────────────────────┐
│                    RECURSOS TECNOLÓGICOS DEL CAMPO               │
└─────────────────────────────┬─────────────────────────────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          ▼                                       ▼
┌──────────────────────────┐         ┌──────────────────────────────┐
│  RECURSOS DE MANTENIMIENTO│         │  RECURSOS DE EVOLUCIÓN       │
├──────────────────────────┤         ├──────────────────────────────┤
│ Propósito:               │         │ Propósito:                   │
│ Reparar drones destruidos │         │ Pagar el salto de Generación  │
│ y reemplazar módulos.    │         │ (Gen 1→2 y Gen 2→3).         │
│                          │         │                              │
│ Fuentes:                 │         │ Fuentes:                     │
│ - Chatarra de Wreck Sites │         │ - Nodos Tecnológicos del mapa│
│ - Nodos ligeros del mapa  │         │ - Tecnología abandonada en   │
│ - Infraestructura neutral │         │   sectores de alto riesgo    │
│                          │         │                              │
│ Dónde se usa:            │         │ Dónde se usa:                │
│ Campo / Puntos ligeros    │         │ Exclusivamente en Centros de │
│                          │         │ Integración Tecnológica      │
│ Dinámica:                │         │                              │
│ Consumo táctico rápido    │         │ Dinámica:                    │
│ (emergencia inmediata)    │         │ Consolidación permanente     │
└──────────────────────────┘         └──────────────────────────────┘
```

---

## ⏳ Economía por Fase de Partida

### Fase Gen 1 (0:00 - 15:00 min): Economía de Supervivencia
- **Recursos dominantes**: Chatarra ligera de Wreck Sites y nodos de acceso fácil.
- **Prioridad de gasto**: Mantener los drones reparados y los módulos básicos activos.
- **Conflicto principal**: Disputas por los primeros nodos de recursos entre escuadras que establecen rutas de cosecha.

### Fase Gen 2 (~15:00 - 30:00 min): Economía de Especialización
- **Recursos dominantes**: Nodos tecnológicos de riesgo medio (ubicados en flancos del mapa).
- **Prioridad de gasto**: Acumular *Recursos de Evolución* para canalizar en el Centro de Integración y activar la Doctrina.
- **Conflicto principal**: Interceptar al equipo enemigo mientras canaliza en el Centro de Integración.

### Fase Gen 3 (~30:00 min en adelante): Economía de Dominio
- **Recursos dominantes**: Nodos avanzados en sectores de alto riesgo cerca del Núcleo IA.
- **Prioridad de gasto**: Mantener la estación de Gen 3 bajo control y financiar la Operación del Núcleo.
- **Conflicto principal**: La escuadra que controla la Estación de Gen 3 y el perímetro del Núcleo dicta el clímax de la partida.

---

## 🛡️ Mecanismos Anti-Snowballing

1. **Límite de Inventario (Cap)**: Cada operador porta un máximo de 100 unidades de componentes. Las piezas sobrantes se descartan, impidiendo que un equipo dominante acapare el mapa entero.
2. **Rendimientos Decrecientes**: El coste de mejoras de módulo escala exponencialmente. La diferencia tecnológica entre un módulo de nivel 2 y uno de nivel 3 es marginal frente al enorme costo de recursos.
3. **Pérdida por Incapacitación**: Un operador abatido suelta el 50% de sus componentes no procesados en el mapa. El equipo rival puede recuperarlos si controla el terreno.
4. **Inmutabilidad de la Generación Alcanzada**: El equipo perdedor conserva su Generación aunque pierda operadores. Esto garantiza que la brecha no se vuelva insalvable.

---

## 🚫 Prevención del Kill Farming

- Los kills de operadores enemigos otorgan una cantidad **mínima** de chatarra.
- La **mayor fuente de recursos** proviene de los Nodos Tecnológicos del mapa.
- Esto obliga a las escuadras a expandirse y disputar sectores del nivel en lugar de acampar en un pasillo buscando bajas.
