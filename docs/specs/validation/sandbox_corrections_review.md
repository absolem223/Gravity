# SPEC VALIDATION: SANDBOX CORRECTIONS REVIEW — REVISIONES POST-SIMULACIÓN

- **Estado**: Decisiones Confirmadas (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/sandbox_corrections_review.md`
- **Origen**: Problemas detectados en `full_match_simulation.md`

---

## 📌 Propósito

Este documento registra formalmente las cuatro correcciones de diseño derivadas de la simulación conceptual de partida completa (`full_match_simulation.md`) y fija las nuevas decisiones arquitectónicas antes de avanzar a la Simulación de Generación 3.

---

## 🔧 CORRECCIÓN 1 — Persistencia del Hackeo del Núcleo IA

### Problema Detectado
El sistema donde la expulsión del perímetro reinicia completamente la barra de descarga al 0% es excesivamente punitivo. En la simulación, Alfa perdió el 47% acumulado de forma instantánea, lo que podría desincentivar intentos de hackeo arriesgados y alargar las partidas innecesariamente.

### Nueva Arquitectura: Progreso con Persistencia Parcial

```
┌─────────────────────────────────────────────────────────────────────┐
│                   ESTADO DEL PROGRESO DEL NÚCLEO IA                │
├──────────────────────────────┬──────────────────────────────────────┤
│ Estado ACTIVO (Avanzando)    │ Condición: Mayoría de red atacante   │
│                              │ en el perímetro sin contestación.    │
├──────────────────────────────┼──────────────────────────────────────┤
│ Estado CONTESTADO (Congelado)│ Condición: Presencia equivalente de  │
│                              │ ambas escuadras en el perímetro.     │
├──────────────────────────────┼──────────────────────────────────────┤
│ Estado DEGRADACIÓN (Cayendo) │ Condición: Mayoría de red defensora  │
│                              │ en el perímetro.                     │
│                              │ Ritmo: -10% por cada 30 seg de       │
│                              │ control defensor ininterrumpido.     │
└──────────────────────────────┴──────────────────────────────────────┘
```

### Reglas de Degradación Gradual

1. **La descarga no cae instantáneamente a 0%**. Si la escuadra atacante es expulsada del perímetro, la barra entra en Estado de Degradación a ritmo de -10% cada 30 segundos.
2. **El progreso puede recuperarse**. Si la escuadra atacante regresa al perímetro antes de que la barra llegue a 0%, retoma la descarga desde el porcentaje actual.
3. **Umbral Mínimo de Retención**: Al superar el 50% de descarga, el umbral de degradación se reduce a -5% por 30 segundos. Una operación que llega a la mitad ya representa una ventaja significativa que no desaparece rápidamente.
4. **Protección contra Reseteo Abusivo**: El defensor no puede detener indefinidamente la descarga en 0% si el atacante mantiene presencia en el perímetro. La congelación solo ocurre en Estado Contestado genuino.

### Impacto en el Diseño

- Un equipo que llegue al 80% y sea expulsado tiene entre 2 y 4 minutos para reconquistar el perímetro antes de perder ese avance.
- Genera **presión temporal dinámica** sin eliminar el riesgo de perder el control.
- Refuerza directamente el Pilar 3: *"El objetivo es controlar el Núcleo"* — el avance acumulado tiene valor real y debe ser defendido como un recurso.

---

## 🔧 CORRECCIÓN 2 — Ventana de Canalización de Generaciones Tecnológicas

### Problema Detectado
El tiempo de canalización de 4 segundos genera poca tensión real de interrupción. En la simulación, Alfa detectó la canalización de B1 pero no pudo interceptarla porque 4 segundos no es tiempo suficiente para una reacción táctica significativa.

### Nueva Arquitectura: Canalización en Tres Fases

```
┌─────────────────────────────────────────────────────────────────────┐
│              OPERACIÓN DE CANALIZACIÓN DE GENERACIÓN                │
├─────────────────────────────────────────────────────────────────────┤
│ FASE 1 — PREPARACIÓN (3 seg)                                        │
│ El Centro de Integración emite un "calentamiento energético".       │
│ Firma DÉBIL visible a corta distancia. Ventana de anticipación.     │
├─────────────────────────────────────────────────────────────────────┤
│ FASE 2 — CANALIZACIÓN ACTIVA (6 seg)                                │
│ El operador o su dron están físicamente enlazados al Centro.        │
│ Firma FUERTE visible en el radar de toda la escuadra rival.         │
│ El operador tiene movilidad reducida (puede agacharse pero no        │
│ correr). El dron puede actuar independientemente en esta fase.      │
├─────────────────────────────────────────────────────────────────────┤
│ FASE 3 — ESTABILIZACIÓN (2 seg)                                     │
│ La Generación se consolida. Ya no puede interrumpirse.              │
│ Firma se apaga. Animación de activación del nuevo módulo.           │
└─────────────────────────────────────────────────────────────────────┘
```

### Reglas de la Nueva Canalización (Total: ~11 segundos)

1. **La interrupción solo es posible durante la Fase 2** (los 6 segundos centrales).
2. El operador en canalización puede moverse lentamente, usar coberturas y disparar con penalización, pero NO puede abandonar el radio del Centro de Integración sin abortar.
3. Si el operador aborta voluntariamente antes de la Fase 3, recupera el 80% de los Recursos de Evolución invertidos.
4. Si es incapacitado durante la Fase 2, suelta el 50% de sus Recursos de Evolución en el suelo (mechanic de penalización ya confirmada).
5. **El Dron puede actuar libremente durante toda la canalización**, convirtiéndose en el guardián natural del operador vulnerado.

### Consecuencia Táctica

La ventana de ~6 segundos activos con firma fuerte permite a una escuadra coordinada organizar un flanqueo o una distracción táctica real. Evolucionar solo o sin protección del equipo es un riesgo elevado — exactamente la tensión que busca el Pilar 5 (*Cooperación > Héroe Individual*).

---

## 🔧 CORRECCIÓN 3 — Rediseño del Rol Tech Scavenger / Field Engineer

### Problema Detectado
B3 en la simulación pasó la mayor parte de la partida cosechando recursos sin interacción táctica directa con el combate. El rol puede percibirse como pasivo e invisible.

### Nueva Definición: Control Tecnológico Activo del Campo de Batalla

El **Tech Scavenger / Field Engineer** no es un recolector de ítems. Es el operador especializado en **sostener la presencia tecnológica de la escuadra en el mapa**, actuando sobre infraestructura, drones y Wreck Sites de forma dinámica.

#### 5 Funciones Tácticas Activas del Rol:

1. **Cosecha Remota mediante Dron**: Su dron puede extraer componentes de un Wreck Site sin que el operador se exponga físicamente. El operador permanece en posición de combate mientras el dron trabaja en el punto de interés.

2. **Reparación de Drones Aliados bajo Presión**: Puede sintetizar el dron destruido de un aliado a distancia de campo (en lugar de que el aliado deba retroceder a un punto de reabastecimiento). Requiere línea de red entre su dron y la posición del aliado.

3. **Activación y Sabotaje de Infraestructura Neutra**: Puede hackear nodos tecnológicos secundarios del mapa para denegar recursos al enemigo o activar bonificaciones pasivas de zona para su escuadra.

4. **Intercepción de Canalización Enemiga**: Su perfil de dron en Gen 2 (Soporte Logístico) incluye capacidad de interferir la Fase 2 de canalización de un enemigo a distancia, usando su dron para crear ruido electromagnético en el Centro de Integración rival.

5. **Consolidación de Wreck Sites Aliados**: Puede "asegurar" los restos de drones aliados destruidos en terreno controlado para protegerlos del saqueo enemigo, acumulando piezas de forma pasiva sin requerir presencia física.

#### Cuestionario Mandatory (verificación contra `operator_design_rules.md`):
- ✅ **¿Qué información aporta?** Revela ubicaciones de Wreck Sites y estado de los nodos tecnológicos del mapa.
- ✅ **¿Cómo interactúa con su Dron?** Su dron es su herramienta de trabajo principal; sin él, la mayoría de sus funciones quedan inhabilitadas.
- ✅ **¿Qué aporta al equipo?** Sostiene la economía de Mantenimiento de la escuadra y acelera la recuperación tecnológica tras combates.
- ✅ **¿Qué dependencia crea?** Depende del *Breacher* o el *Recon* para protegerlo mientras su dron trabaja en el campo.
- ✅ **¿Qué debilidad tiene?** Su dron es su único modo de actuación activa; si lo pierde, queda reducido a un combatiente estándar sin ventajas tecnológicas.

---

## 🔧 CORRECCIÓN 4 — Equilibrio de Gen 3: Poder Estratégico sin Victoria Automática

### Problema Identificado
Los Efectos de Red de Gen 3 deben ser poderosos, pero no convertirse en un modo "Easy Win" que vacíe de tensión el último tercio de la partida.

### Principio Rector Oficial

> **"Gen 3 amplía las opciones de la escuadra. No sustituye la necesidad de ejecutarlas."**

### Restricciones Permanentes sobre los Efectos de Red de Gen 3

1. **Nunca otorgan daño aumentado directo**. El daño bruto de armas es idéntico en Gen 1, Gen 2 y Gen 3. La diferencia es en capacidad de información, coordinación y eficiencia táctica.
2. **Son pasivos pero no omniscientes**. El *Radar Neuronal* de Recon Gen 3 transmite posiciones enemigas a aliados, pero solo de los enemigos que el Dron de Recon ha escaneado activamente. Un enemigo que evitó ser escaneado permanece invisible.
3. **Requieren escuadra viva para escalar**. Los Efectos de Red se debilitan o desaparecen si el operador Gen 3 es incapacitado. La escuadra rival puede "negar" el efecto atacando al operador fuente.
4. **Gen 3 no bloquea la recuperación de Gen 1**. Un equipo de Gen 1 coordinado con buena posición y terreno favorable puede derrotar a un equipo Gen 3 disperso. El terreno, la cobertura y la supresión funcionan igual para todas las Generaciones.

### Mecanismos de Contramedida para el Equipo Gen 1 vs Gen 3

- **Emboscada de Canalización**: Interrumpir el salto a Gen 3 (ahora con ventana de 6 segundos) priva al rival de esa ventaja.
- **Ataque al Operador Fuente**: Eliminar al operador Gen 3 que genera el Efecto de Red desactiva el beneficio para toda su escuadra.
- **Control del Terreno Cerrado**: En espacios de combate estrecho (conductos, salas pequeñas), el *Radar Neuronal* pierde utilidad frente a la geometría.

---

## 📋 Resumen de Decisiones Incorporadas

| Corrección | Decisión Tomada | Estado |
| :--- | :--- | :--- |
| Persistencia del Hackeo | Degradación gradual -10%/30 seg; umbral de retención al 50% | ✅ Confirmada |
| Ventana de Canalización | 3 fases: Calentamiento (3s) + Activo (6s) + Estabilización (2s) | ✅ Confirmada |
| Tech Scavenger | Rediseño a 5 funciones activas mediante dron | ✅ Confirmada |
| Gen 3 Equilibrado | Sin daño bruto; efectos de red debilitables; contramedidas claras | ✅ Confirmada |
