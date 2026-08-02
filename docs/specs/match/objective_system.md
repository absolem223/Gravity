# SPEC: OBJECTIVE SYSTEM — SISTEMA DEL NÚCLEO IA Y CENTROS TECNOLÓGICOS

- **Estado**: Actualizado / Revisión 3.0 (Fase 0.5 — Game Architecture)
- **Dominio**: Match & Objective
- **Ubicación**: `docs/specs/match/objective_system.md`

---

## 🎯 El Ecosistema de Objetivos del Mapa

En GRAVITY, la partida no es una trayectoria recta hacia un único punto. El mapa contiene un **Ecosistema de Objetivos Interconectados**:

1. **El Objetivo Primario (Núcleo IA)**: Otorga la condición de victoria mediante la Operación Tecnológica de descarga y control de perímetro.
2. **Los Objetivos Secundarios (Centros de Integración Tecnológica)**: Otorgan el avance a **Generaciones 2 y 3**, proporcionando las capacidades tácticas necesarias para ganar la batalla del Núcleo.

```
┌─────────────────────────────────────────────────────────────┐
│             CENTROS DE INTEGRACIÓN TECNOLÓGICA              │
│       (Evolución a Gen 2 y Gen 3 / Efectos de Red)          │
└──────────────┬──────────────────────────────┬───────────────┘
               │ Potencia capacidades         │ Aumenta ancho de banda
               ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     EL NÚCLEO IA (SSOT)                     │
│       (Operación Tecnológica de Descarga y Perímetro)       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Dinámica de Dominio Territorial Dual

- **Fase Inicial / Media**: Las escuadras luchan por el control de los Centros de Integración Tecnológica neutros para evolucionar sus operadores y drones a Gen 2 antes de la primera incursión al Núcleo.
- **Fase Avanzada**: Una escuadra que logra alcanzar Gen 3 mediante la inversión de recursos consolidados adquiere *Efectos de Red* (compartición de radar, overclocking de escuadra) que le otorgan una ventaja crítica para sostener el Perímetro del Núcleo IA en el clímax de la partida.
