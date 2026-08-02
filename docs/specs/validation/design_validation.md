# SPEC VALIDATION: DESIGN VALIDATION — REVISIÓN 5.0: AUDITORÍA POST-CORRECCIONES

- **Estado**: Actualizado / Revisión 5.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/design_validation.md`

---

## 🎯 Propósito

Auditoría completa y actualizada de todas las decisiones de diseño de PROJECT GRAVITY después de incorporar las 4 correcciones derivadas de `full_match_simulation.md`.

---

## 🔒 DECISIONES CONFIRMADAS (Inmutables)

### 1. La Información como Recurso Principal
- El TTK frontal sin información de Dron es elevado y penalizador.
- Avanzar sin información de posición enemiga es un error táctico estructural.
- La Niebla de Guerra y el cono de visión son mecánicas primarias de combate.

### 2. El Dron como Extensión Permanente del Operador
- Tríada Táctica: Operador + Exoesqueleto + Dron.
- El Dron actúa como guardián natural durante la Fase 2 de Canalización.
- La pérdida del Dron exige recuperación táctica activa; la Generación alcanzada no se pierde.

### 3. Generaciones Tecnológicas Permanentes e Irreversibles
- Secuencia: Gen 1 (0–15 min) → Gen 2 (~15 min) → Gen 3 (~30 min).
- Las Generaciones no se pierden al morir.

### 4. Sistema de Canalización en Tres Fases (Corrección 2 — Confirmada)
- Fase 1: Calentamiento (3 seg) — firma débil.
- Fase 2: Activo (6 seg) — firma fuerte, ventana de interrupción real.
- Fase 3: Estabilización (2 seg) — irreversible.
- Total: ~11 segundos.

### 5. Persistencia Parcial del Progreso del Núcleo IA (Corrección 1 — Confirmada)
- Estado ACTIVO → CONTESTADO → DEGRADACIÓN (no reseteo).
- Degradación: -10%/30 seg de control defensor. Al superar 50%, -5%/30 seg.
- La descarga puede recuperarse si el atacante reconquista el perímetro.

### 6. Field Engineer como Control Tecnológico Activo (Corrección 3 — Confirmada)
- 5 funciones tácticas activas mediante Dron.
- El rol no es recolección pasiva sino administración activa de la economía tecnológica.

### 7. Gen 3 Otorga Efectos de Red, No Mayor Daño (Corrección 4 — Confirmada)
- Principio rector: *Gen 3 amplía las opciones de la escuadra. No sustituye la necesidad de ejecutarlas.*
- Los efectos de red se desactivan si el operador Gen 3 fuente es incapacitado.
- Un equipo Gen 1 con buen posicionamiento puede derrotar a un equipo Gen 3 disperso.
- Contramedidas claras para el equipo retrasado: interrumpir canalización, atacar operador fuente, usar terreno cerrado.

### 8. La Cooperación es Superior al Héroe Individual
- Ningún operador es autosuficiente en información + potencia + movilidad + supervivencia simultáneamente.
- Los Efectos de Red de Gen 3 requieren escuadra viva y coordinada para alcanzar potencial máximo.

### 9. Separación Estricta de Recursos
- Recursos de Mantenimiento ≠ Recursos de Evolución. No son intercambiables.

---

## 🔓 DECISIONES ABIERTAS (En Proceso de Profundización)

1. **Valores exactos de canalización**: Los 3 + 6 + 2 segundos son decisiones de diseño provisional. Requieren prototipado en `sandbox/`.
2. **Ritmo exacto de degradación del Núcleo**: -10%/30 seg y -5%/30 seg son estimaciones de diseño. Se ajustarán tras prototipado.
3. **Árbol de módulos específicos por Doctrina en Gen 2**: Las opciones concretas dentro de cada Doctrina están pendientes de especificación.
4. **Coste exacto de Recursos de Evolución (Gen 1→2 y Gen 2→3)**: Se definirá en el Vertical Slice.
5. **Variantes de operadores disponibles en lanzamiento**: Pendiente de definición.

---

## 📊 Auditoría de las 4 Correcciones contra los 5 Pilares

### Corrección 1 (Persistencia del Hackeo)

| Pilar | Evaluación |
| :--- | :--- |
| Pilar 1 (Información) | ✅ Saber en qué estado está la barra enemiga es información táctica crítica. El porcentaje actual del Núcleo es visible para ambos equipos. |
| Pilar 2 (Nunca solo) | ✅ Sostener el Estado ACTIVO requiere múltiples operadores y drones en el perímetro simultáneamente. |
| Pilar 3 (Núcleo es el objetivo) | ✅ El progreso acumulado tiene valor real; el equipo atacante nunca pierde todo su trabajo instantáneamente. Refuerza que controlar el Núcleo es una operación, no un momento puntual. |
| Pilar 4 (Terreno) | ✅ La arquitectura del perímetro del Núcleo determina quién puede mantener el Estado ACTIVO de forma sostenida. |
| Pilar 5 (Cooperación) | ✅ El Estado CONTESTADO es tácticamente el más tenso — requiere coordinación de los 4 operadores para romperlo. |

### Corrección 2 (Canalización en Tres Fases)

| Pilar | Evaluación |
| :--- | :--- |
| Pilar 1 (Información) | ✅ La Fase 1 emite firma débil — quien tiene Recon activo la detecta antes que el rival. La información sobre canalizaciones enemigas es ventaja táctica directa. |
| Pilar 2 (Nunca solo) | ✅ El operador en Fase 2 es vulnerado; el Dron libre y los aliados son su protección natural. Evolucionar solo es un riesgo calculado. |
| Pilar 4 (Terreno) | ✅ El operador debe estar físicamente en el Centro de Integración — no puede evolucionar desde zona segura. |
| Pilar 5 (Cooperación) | ✅ La escolta de la canalización es una operación táctica de equipo. Interrumpir la canalización del rival también requiere coordinación. |

### Corrección 3 (Field Engineer Activo)

| Pilar | Evaluación |
| :--- | :--- |
| Pilar 1 (Información) | ✅ El Field Engineer revela ubicaciones de Wreck Sites y estados de nodos en el mapa táctico. |
| Pilar 2 (Nunca solo) | ✅ El Field Engineer depende de protección armada para operar. Nunca es autosuficiente. |
| Pilar 4 (Terreno) | ✅ Sus acciones están vinculadas a posiciones físicas del mapa: Wreck Sites, nodos, Centros de Integración. |
| Pilar 5 (Cooperación) | ✅ Transfiere recursos de Evolución a los operadores prioritarios — su éxito es el éxito del equipo. |

### Corrección 4 (Gen 3 Equilibrado)

| Pilar | Evaluación |
| :--- | :--- |
| Pilar 1 (Información) | ✅ El Radar Neuronal de Recon Gen 3 solo transmite posiciones de enemigos escaneados — no es información omnisciente. Requiere trabajo activo del Dron. |
| Pilar 2 (Nunca solo) | ✅ Los efectos de red se desactivan si el operador Gen 3 fuente cae — la escuadra debe protegerlo activamente. |
| Pilar 3 (Núcleo es el objetivo) | ✅ La Estación de Gen 3 está adyacente al perímetro del Núcleo — alcanzar Gen 3 requiere presionar el mismo territorio que el objetivo principal. |
| Pilar 4 (Terreno) | ✅ En espacios cerrados el Radar Neuronal pierde utilidad. El terreno compensa parcialmente la desventaja de Generación. |
| Pilar 5 (Cooperación) | ✅ Gen 3 no reemplaza la cooperación — la amplifica. Un equipo Gen 3 descoordinado sigue siendo vulnerable a un equipo Gen 1 disciplinado. |

---

## ⚠️ Tabla de Riesgos de Diseño — Estado Post-Correcciones

| Riesgo | Prob. Previa | Prob. Post-Corrección | Mitigación Activa |
| :--- | :---: | :---: | :--- |
| Gen 1 lenta y pasiva | Media | Baja | Pulsos de Nodos desde min 5; Niebla que se disipa |
| Gen 2 snowball insuperable | Media | Baja | Firma en canalización (6 seg de ventana real); bono de flanqueo |
| Gen 3 como victoria automática | Alta | Baja | Efectos de red debilitables; sin daño bruto; contramedidas documentadas |
| Partidas >45 min | Media | Baja | Degradación activa del Núcleo; Onda de Pulso Continua a los 40 min |
| Hackeo frustrante por reset total | Alta | Eliminado | Persistencia parcial con degradación -10%/30 seg |
| Field Engineer percibido como pasivo | Alta | Eliminado | 5 funciones activas redefinidas; cosecha, reparación e interferencia via Dron |
| Canalización sin tensión táctica | Alta | Eliminado | Sistema de Tres Fases con ventana de 6 seg y firma fuerte |

---

## 📋 Estado de la Arquitectura Funcional de GRAVITY

✅ **Fase 0.5 — Game Architecture: COMPLETA**

Todos los sistemas de gameplay han sido especificados, simulados y corregidos. La arquitectura funcional está lista para avanzar hacia:

1. **Simulación Específica de Generación 3** (`full_match_simulation_gen3.md`) — Validar Efectos de Red en condiciones de partida completa.
2. **Vertical Slice Design** — Definir el subconjunto mínimo de sistemas para el primer prototipo jugable.
