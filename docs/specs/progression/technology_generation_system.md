# SPEC: TECHNOLOGY GENERATION SYSTEM — REVISIÓN 5.0: CANALIZACIÓN EN TRES FASES

- **Estado**: Actualizado / Revisión 5.0 (Fase 0.5 — Game Architecture)
- **Dominio**: Progression & Tech Tree
- **Ubicación**: `docs/specs/progression/technology_generation_system.md`

---

## 🎯 Filosofía de la Progresión en Partida

GRAVITY rechaza los sistemas de niveles de experiencia (XP) tradicionales. La progresión dentro de una partida ocurre mediante **Generaciones Tecnológicas Permanentes**:

> **"La escuadra consiguió suficiente dominio tecnológico del campo de batalla para evolucionar."**

La Generación no se siente como "subir de nivel". Se siente como una consecuencia natural del control territorial y la recolección de inteligencia técnica en el campo de batalla.

### Principios Fundamentales:
1. **Permanencia e Inmutabilidad**: Una vez alcanzada una Generación, **no puede perderse ni revertirse**.
2. **Evolución Conjunta**: La Generación eleva simultáneamente al Exoesqueleto y al Dron.
3. **Decisión Doctrinaria Irreversible**: La elección de rama en Gen 2 exige compromiso estratégico para toda la partida.
4. **No es Daño, es Capacidad**: Cada Generación amplía la capacidad de información, soporte y red de la escuadra — no el daño bruto.

---

## 🏛️ Las 3 Generaciones Tecnológicas

### GENERACIÓN 1 — Tecnología Base (0:00 a ~15:00 min)
**Objetivo**: Crear la base estratégica de la escuadra.
- Estado inicial al comenzar la partida.
- Exploración de Niebla de Guerra, cosecha inicial de recursos.
- **Sensación**: Incertidumbre, sigilo, reconocimiento y preparación.

### GENERACIÓN 2 — Especialización Tecnológica (~15:00 min en adelante)
**Objetivo**: Convertir la doctrina elegida en ventaja estratégica para la escuadra.
- Selección permanente de 1 Doctrina Tecnológica.
- El Dron adopta el perfil especializado.
- **Sensación**: Especialización, fricción territorial intensa, choque de doctrinas.

#### Las 5 Doctrinas de Gen 2:
1. **Reconocimiento**: Sonar de alta frecuencia, filtrado térmico.
2. **Defensa**: Proyección de micro-escudos, atenuación balística.
3. **Soporte Logístico**: Recarga de batería para drones aliados, reparación remota.
4. **Asistencia Ofensiva**: *Smart Vectoring*, marcado de puntos débiles.
5. **Manipulación Tecnológica**: Hackeo remoto de terminales e inhabilitación de visores.

### GENERACIÓN 3 — Evolución Avanzada (~30:00 min en adelante)
**Objetivo**: Representar superioridad tecnológica de escuadra — no mayor daño.
- La Doctrina elegida en Gen 2 se profundiza.
- Desbloqueo de **Efectos de Red** pasivos para toda la escuadra.
- **Principio rector**: *Gen 3 amplía las opciones de la escuadra. No sustituye la necesidad de ejecutarlas.*

#### Restricciones Permanentes de Gen 3:
- Nunca otorga daño aumentado directo.
- Los efectos de red se desactivan si el operador Gen 3 fuente es incapacitado.
- Un equipo Gen 1 coordinado con buen terreno puede derrotar a un equipo Gen 3 disperso.

#### Efectos de Red por Doctrina en Gen 3:
- **Recon Gen 3** → *Radar Neuronal*: Posiciones escaneadas por el Dron se transmiten en tiempo real a todos los aliados. Solo afecta a enemigos que el Dron ha escaneado activamente.
- **Defensa Gen 3** → *Perímetro Fortificado*: Aliados a menos de 10 metros reciben resistencia balística adicional.
- **Logística Gen 3** → *Overclock Energético*: Drones de la escuadra consumen 30% menos de batería.
- **Ofensiva Gen 3** → *Supresión Sincronizada*: El marcado de A4 amplía el cono de supresión de toda la escuadra.
- **Manipulación Gen 3** → *Reducción de Hackeo*: El tiempo de descarga del Núcleo IA se reduce para toda la escuadra.

---

## 🏢 Infraestructura Física: Centros de Integración Tecnológica

La progresión tecnológica **no ocurre automáticamente**. Exige acceso físico y canalización en **Centros de Integración Tecnológica**.

### Sistema de Canalización en Tres Fases (Corrección 2 Post-Simulación)

```
┌─────────────────────────────────────────────────────────────────────┐
│ FASE 1 — PREPARACIÓN / CALENTAMIENTO (3 segundos)                  │
│ El Centro emite firma DÉBIL de energía. Detectable a corta         │
│ distancia. Sin movilidad reducida. El operador puede abortar.      │
├─────────────────────────────────────────────────────────────────────┤
│ FASE 2 — CANALIZACIÓN ACTIVA (6 segundos)                          │
│ Firma FUERTE visible en el radar de toda la escuadra rival.        │
│ Movilidad reducida (puede cubrirse, no correr). El Dron puede      │
│ actuar libremente como guardián. ÚNICA VENTANA DE INTERRUPCIÓN.    │
├─────────────────────────────────────────────────────────────────────┤
│ FASE 3 — ESTABILIZACIÓN (2 segundos)                               │
│ Generación consolidada. Ya no puede interrumpirse.                 │
│ Firma se apaga. Módulo activado.                                   │
└─────────────────────────────────────────────────────────────────────┘
                             TOTAL: ~11 segundos
```

### Reglas de la Canalización:
- La interrupción solo es posible durante la **Fase 2** (los 6 segundos centrales).
- Abortar voluntariamente antes de Fase 3 devuelve el 80% de los Recursos de Evolución.
- Ser incapacitado durante Fase 2 provoca la pérdida del 50% de recursos.
- El Dron actúa libremente durante toda la canalización — es el guardián natural del operador vulnerable.

### Posicionamiento Estratégico en el Mapa:
- Centros de Gen 2: Ubicados en flancos medios (requieren abandonar el spawn).
- Estación de Gen 3: En sector de alto riesgo, adyacente al perímetro del Núcleo IA.

---

## 💰 Separación de Recursos: Evolución vs Mantenimiento

| Flujo | Destino | Dónde se Usa |
| :--- | :--- | :--- |
| **Recursos de Mantenimiento** | Reparar drones destruidos, sustituir módulos | Campo / Puntos de reabastecimiento ligeros |
| **Recursos de Evolución** | Pagar el salto de Generación (1→2, 2→3) | Centros de Integración Tecnológica |

---

## ⚖️ Auditoría contra los 5 Pilares

1. **Pilar 1 (Información)**: La Fase 1 de canalización emite firma débil — quien tiene Recon activo la detecta antes que el rival.
2. **Pilar 2 (Nunca solo)**: El operador en Fase 2 es vulnerable; el Dron libre y los aliados son su protección natural.
3. **Pilar 3 (Núcleo IA)**: La Estación de Gen 3 está cerca del Núcleo — evolucionar exige presionar el mismo territorio que el objetivo principal.
4. **Pilar 4 (Terreno)**: Controlar físicamente los Centros Tecnológicos es el requisito para evolucionar.
5. **Pilar 5 (Cooperación)**: La canalización vulnerable exige escolta de escuadra — es una operación táctica de equipo, no individual.
