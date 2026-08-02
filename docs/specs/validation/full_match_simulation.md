# SPEC VALIDATION: FULL MATCH SIMULATION — SIMULACIÓN COMPLETA DE PARTIDA

- **Estado**: Validación Conceptual (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/full_match_simulation.md`
- **Propósito**: Probar si la experiencia completa de GRAVITY funciona como juego antes del Vertical Slice Design.

---

## 📌 Configuración de la Partida Simulada

| Parámetro | Valor |
| :--- | :--- |
| **Formato** | 4 vs 4 (Escuadra Alfa vs Escuadra Bravo) |
| **Mapa** | Complejo Industrial Abandonado (3 rutas + conductos de drones) |
| **Objetivo** | Operación Tecnológica sobre el Núcleo IA |
| **Duración estimada** | 38 minutos |

### Composición de Escuadras

**ESCUADRA ALFA** (Equipo simulado desde perspectiva analítica):
- **A1 — Recon**: Jugador experimentado. Prioriza información.
- **A2 — Vanguard/Breacher**: Jugador agresivo. Presiona los chokepoints.
- **A3 — Tech Disruptor**: Jugador táctico. Enfocado en hackeo e interrupción.
- **A4 — Overwatch**: Jugador de retaguardia. Fuego de supresión y soporte.

**ESCUADRA BRAVO** (Equipo adversario):
- **B1 — Recon**: Muy defensivo. Construye líneas seguras.
- **B2 — Vanguard**: Prioriza el control del Centro de Integración del flanco izquierdo.
- **B3 — Tech Scavenger**: Orientado a la economía de recursos.
- **B4 — Overwatch**: Posición elevada, cubre la sala del Núcleo IA.

---

## ⏱️ NARRATIVA MINUTO A MINUTO

---

### [ 0:00 - 2:00 ] DESPLIEGUE Y PRIMER ESCANEO

**Escuadra Alfa** despliega desde su zona de spawn sur. **A1 (Recon)** activa inmediatamente su Dron en Modo Piloto y lo envía por el conducto central del techo para limpiar la Niebla de Guerra del sector medio.

**Escuadra Bravo** adopta una estrategia diferente: **B1 (Recon)** mantiene su Dron en Modo Escolta —priorizando protección— y avanza cauteloso por el flanco izquierdo para asegurar el Centro de Integración Tecnológica de ese sector antes que Alfa.

> 🔍 **Decisión táctica observable**: Alfa invierte agresivamente en información temprana (dron expuesto en conducto). Bravo invierte en asegurar infraestructura. Ambas estrategias son válidas y crean una asimetría interesante desde el primer minuto.

---

### [ 2:00 - 5:00 ] PRIMERA INFORMACIÓN Y PRIMERAS DECISIONES

El Dron de **A1** completa el escaneo del sector medio y detecta la firma de movimiento de **B2** avanzando hacia el Centro de Integración del flanco izquierdo.

**A1** transmite la posición a su escuadra: *"Bravo tiene un operador en el Centro de Integración izquierdo. Posiblemente acumulando recursos ya."*

**A2 (Vanguard)** propone interceptar. **A4 (Overwatch)** señala que es demasiado temprano para dividirse. La escuadra decide priorizar asegurar el nodo tecnológico central antes de presionar los flancos.

Mientras tanto, **B3 (Tech Scavenger)** ya está cosechando un Nodo de Recursos ligero en el corredor este, sin ninguna oposición. Bravo acumula componentes de Mantenimiento silenciosamente.

> 🔍 **Decisión táctica observable**: La información de Alfa sobre B2 generó un debate de escuadra genuino. El Pilar 1 (Información) ya está generando tensión estratégica. El Pilar 5 (Cooperación) se manifiesta en la negociación interna de Alfa sobre cómo responder.

---

### [ 5:00 - 8:00 ] PRIMER CONTACTO EN EL CORREDOR CENTRAL

**A2 (Vanguard)** avanza por el pasillo central con su Dron en Modo Escolta. Al doblar una esquina en L, la Niebla de Guerra aún no fue limpiada en ese ángulo. Sin información previa del flanco, A2 recibe fuego de **B4 (Overwatch)** que había anticipado el movimiento desde una posición elevada en la mezzanine central.

**A2 es suprimido** — su visor se distorsiona, su puntería se degrada. No cae, pero debe retroceder a cobertura.

**A1** dirige inmediatamente su Dron hacia la posición de B4 para confirmar el ángulo exacto. El Dron tarda 4 segundos en llegar por el conducto. En ese intervalo, A2 permanece en cobertura.

Cuando el Dron confirma la posición de B4, **A4 (Overwatch)** aplica fuego de supresión coordinado desde el flanco sur. **B4** debe reposicionarse.

> 🔍 **Decisión táctica observable**: A2 avanzó sin información y fue suprimido — confirma que el TTK frontal sin datos es penalizador. La cadena Información → Supresión → Reposicionamiento funciona correctamente. El terreno elevado de B4 tuvo valor estratégico claro (Pilar 4).

---

### [ 8:00 - 12:00 ] DISPUTA POR EL NODO CENTRAL Y PRIMER WRECK SITE

La Escuadra Alfa, con mejor información ahora, presiona coordinadamente el nodo tecnológico central. **A3 (Tech Disruptor)** envía su Dron por el conducto del techo para inhabilitar la terminal de red que refuerza la visibilidad de Bravo en el sector.

**B2 (Vanguard)** retrocede del flanco izquierdo para defender el nodo central. En el enfrentamiento, el Dron de **A3** es detectado y destruido por B2 que dispara al zumbido del escaneo.

El Dron de A3 cae en el sector central, generando un **Wreck Site** con componentes de Mantenimiento.

**B3 (Tech Scavenger)** intenta cosechar los componentes del Wreck Site. **A4** lo detecta y lo suprime, forzando a B3 a retirarse. Alfa controla el Wreck Site y cosecha sus propias piezas.

> ⚠️ **Problema detectado**: El Dron de A3 fue destruido en el minuto 10. A3 queda sin capacidad de hackeo remoto hasta que sintetice un nuevo dron. Esto lo deja tácticamente mermado durante aproximadamente 90 segundos de síntesis. ¿Es este tiempo adecuado? *Decisión abierta para sandbox.*

> 🔍 **Decisión táctica observable**: El Wreck Site del Dron de A3 generó un objetivo secundario disputado. El Pilar 4 (Terreno) se manifestó — controlar el sector del Wreck Site tuvo valor inmediato.

---

### [ 12:00 - 16:00 ] ACUMULACIÓN Y PREPARACIÓN PARA GEN 2

Ambas escuadras consolidan sus rutas de cosecha. Bravo, con B3 enfocado en economía desde el inicio, acumula Recursos de Evolución más rápido que Alfa.

A los **14:30**, **B1 (Recon de Bravo)** llega primero al Centro de Integración del flanco izquierdo y comienza la canalización para Gen 2. La firma de energía se detecta en el mapa de Alfa.

**A1** alerta a su escuadra. A2 quiere interceptar, pero está a 15 segundos de distancia del flanco izquierdo. La escuadra calcula que no llega a tiempo.

**B1** completa la canalización a Gen 2. **Elige Doctrina: Reconocimiento.**

Su Dron adopta capacidades de Sonar de Alta Frecuencia. En los próximos 30 segundos, B1 escanea el mapa con mayor precisión y transmite la posición de dos operadores de Alfa a toda la Escuadra Bravo.

> ⚠️ **Problema potencial detectado**: Bravo llegó a Gen 2 sin oposición porque Alfa no tenía tiempo para interceptar desde su posición. ¿Debería la canalización ser más larga (6-8 segundos) para crear una ventana de interrupción real? *Decisión abierta para sandbox.*

> 🔍 **Decisión táctica observable**: Bravo invirtió en economía de Recursos de Evolución desde el inicio (B3 Scavenger). Esta decisión estratégica temprana tiene consecuencias reales en el minuto 14. Pilar 1 — Bravo ahora tiene una ventaja de información significativa.

---

### [ 16:00 - 20:00 ] ALFA ALCANZA GEN 2 — ELECCIÓN DE DOCTRINAS

Con las posiciones reveladas por el nuevo Sonar de B1, Bravo presiona con mayor agresividad el sector central. Alfa es empujado defensivamente.

**A4 (Overwatch)** acumula sus propios Recursos de Evolución y canaliza Gen 2 en el Centro de Integración del flanco derecho (que Alfa controla).

**A4 elige Doctrina: Asistencia Ofensiva.** Su Dron activa *Smart Vectoring* — el fuego de supresión de A4 ahora marca puntos débiles en las armaduras enemigas, visibles para toda la escuadra.

Poco después, **A1 (Recon)** canaliza Gen 2 en el mismo Centro de Integración derecho.

**A1 elige Doctrina: Reconocimiento.** Esta es la misma Doctrina que B1 de Bravo.

> 🔍 **Decisión táctica observable**: Dos operadores Recon Gen 2 enfrentados. La guerra de información se intensifica. El mapa ahora es más legible para ambas escuadras simultáneamente. Las decisiones de movimiento valen más que la puntería. Pilar 1 dominante.

---

### [ 20:00 - 26:00 ] DOCTRINAS EN CONFLICTO — COMBATE ESPECIALIZADO

La partida entra en su fase más densa. Con cuatro operadores en Gen 2 distribuidos entre ambas escuadras (Bravo lidera en número de Gen 2 pero Alfa tiene posición territorial más sólida), el combate cambia de naturaleza.

**A3 (Tech Disruptor)** alcanza Gen 2 y elige **Manipulación Tecnológica**. Su Dron puede ahora inhabilitar los visores de exoesqueleto enemigos mediante un enlace de red sostenido de 1.5 segundos. Esta es una herramienta de apertura de brecha poderosa.

**B2 (Vanguard)** intenta ingresar a la sala del Núcleo IA por el pasillo norte. **A3** detecta el movimiento mediante el Sonar de A1 y dirige su Dron para establecer enlace de hackeo sobre el visor de B2.

El visor de B2 se interrumpe por 3 segundos. En ese intervalo, **A2 (Vanguard)** avanza y aplica fuego de supresión desde la esquina. B2 se retira.

> 🔍 **Sinergia de escuadra confirmada**: A1 (Recon Gen 2) detecta → A3 (Manipulación Gen 2) interrumpe → A2 (Vanguard) presiona. Esta cadena de tres roles funcionó con coherencia táctica. Pilar 2 y Pilar 5 confirmados en acción.

---

### [ 26:00 - 30:00 ] PRIMER INTENTO SERIO DE HACKEO DEL NÚCLEO IA

Alfa, con control del pasillo norte y la sala perimetral del Núcleo, intenta el primer hackeo.

**A3** inicia el enlace de descarga del Núcleo IA con su Dron anclado en el techo de la sala. La barra de transferencia comienza: **0%**.

Bravo detecta la firma del hackeo (el Núcleo IA emite un tono de alerta a ambos equipos al iniciar la descarga). Los cuatro operadores de Bravo convergen en el sector del Núcleo.

**B4 (Overwatch)** mantiene la posición elevada exterior y suprime la entrada sur de la sala. **A2** intenta entrar para reforzar el perímetro y es suprimido, obligado a retroceder.

Con solo **A3** y **A1** dentro del perímetro del Núcleo, la descarga llega al **47%** antes de que **B2** irrumpa por el conducto del techo (modo piloto de su Dron que hackea la puerta de acceso).

El perímetro entra en **Estado Contestado** — la descarga se congela al 47%.

Bravo expulsa a Alfa de la sala. La descarga cae lentamente de vuelta a 0%.

> 🔍 **Mecánica de Objetivo confirmada**: El Estado Contestado funciona. La sala del Núcleo generó el pico de tensión emocional más alto de la partida. Pilar 3 dominante — nadie pensó en bajas; todos pensaron en el perímetro.

> ⚠️ **Problema detectado**: La caída del progreso de vuelta a 0% al ser expulsados puede sentirse excesivamente punitiva. ¿Debería el progreso caer más lentamente (por ejemplo, 10% por minuto de control enemigo) en lugar de resetear completamente? *Decisión abierta prioritaria para sandbox.*

---

### [ 30:00 - 34:00 ] LA CARRERA HACIA GEN 3

Tras el rechazo del primer hackeo, Alfa reagrupa. **B3 (Tech Scavenger)** de Bravo, que acumuló recursos durante toda la partida, entrega a **B1** los Recursos de Evolución necesarios para canalizar Gen 3.

**B1** avanza hacia la Estación de Gen 3 — ubicada en el sector de alto riesgo adyacente al perímetro del Núcleo. Esto requiere que B1 cruce una zona expuesta.

**A1 (Recon Gen 2)** detecta el movimiento de B1 con su Sonar. Alfa decide interrumpir la canalización de Gen 3 de Bravo como prioridad máxima.

**A2** flanquea por la ruta secundaria oeste. **A4** suprime el pasillo de entrada a la Estación de Gen 3.

**B1** inicia la canalización: su firma energética es visible. La canalización tarda 4 segundos.

**A2** llega en el segundo 3. Abre fuego. **B1** es incapacitado a 1 segundo de completar Gen 3.

**B1 suelta el 50% de sus Recursos de Evolución no procesados** en el suelo de la Estación. Alfa cosecha las piezas.

> 🔍 **Mecánica anti-snowball confirmada**: La carrera de B1 hacia Gen 3 fue interrumpida con trabajo coordinado de escuadra (Pilar 5). La penalización de pérdida de recursos al morir es satisfactoria y estratégicamente relevante.

---

### [ 34:00 - 38:00 ] SEGUNDO INTENTO DE HACKEO — RESOLUCIÓN

Con Bravo temporalmente en desventaja (B1 incapacitado y en proceso de reincorporación), Alfa presiona.

**A3 (Tech Disruptor Gen 2)** usa su Dron para hackear la puerta norte de la sala del Núcleo. **A2** avanza bajo cobertura de **A4**.

**B4** intenta mantener la posición elevada, pero el *Smart Vectoring* de A4 marca los puntos débiles de la armadura de B4. En 4 disparos coordinados con A2, **B4 es incapacitado**.

Alfa toma el control del perímetro. **A1** inicia el enlace de descarga del Núcleo desde el flanco norte.

La barra sube: **0% → 25% → 50%...**

A los **36:20**, B1 se reincorpora. Bravo intenta un contraataque desesperado.

**B2** carga por el conducto de drones con su Dron intentando llegar al perímetro. El Sonar de **A1** lo detecta a 8 segundos de distancia.

**A3** lanza el Dron de A3 en modo sacrificio — sobrecarga EMP en el conducto. B2 queda temporalmente cegado y su Dron pierde señal.

La barra del Núcleo llega a **87% → 95% → 100%.**

**ALFA COMPLETA LA OPERACIÓN TECNOLÓGICA DEL NÚCLEO IA.**

**Resultado: Victoria de Escuadra Alfa — 38 minutos.**

---

## 🔍 VALIDACIÓN CONTRA LOS 5 PILARES

### Pilar 1 — ¿La Información Realmente Gana Enfrentamientos? ✅ VALIDADO
**Evidencia en la simulación**: El avance sin información de A2 en el minuto 6 resultó en supresión y retroceso. La detección de B1 canalizando Gen 3 en el minuto 30 permitió su interrupción. La ventaja informativa de B1 con Recon Gen 2 (minutos 14-20) dio a Bravo la presión táctica que casi les da la victoria. La información fue determinante en al menos 4 momentos de inflexión críticos.

### Pilar 2 — ¿Los Drones Generan Decisiones Interesantes? ✅ VALIDADO
**Evidencia en la simulación**: El sacrificio del Dron de A3 en el conducto para inhabilitar el contraataque de B2 fue la jugada decisiva de la partida. El Dron de B2 como herramienta de hackeo de puerta (minuto 28), el Sonar de A1 detectando movimientos clave, el Dron de A3 como antena repetidora del Núcleo — los drones aparecieron en cada momento de alta tensión. El Trilema (Proteger / Usar / Sacrificar) tuvo impacto real.

### Pilar 3 — ¿El Núcleo IA Siguió siendo el Objetivo Principal? ✅ VALIDADO
**Evidencia en la simulación**: En ningún momento alguno de los equipos intentó ganar por kills. El primer intento de hackeo (minuto 26) fue la cumbre emocional de la partida. El esfuerzo de B1 para llegar a Gen 3 estaba explícitamente orientado a mejorar las capacidades de descarga del Núcleo. La victoria se decidió sobre el perímetro del Núcleo, no en un pasillo.

### Pilar 4 — ¿El Terreno Tuvo Valor Estratégico? ✅ VALIDADO
**Evidencia en la simulación**: La posición elevada de B4 dominó el pasillo central durante 20 minutos. La Estación de Gen 3 creó un punto de conflicto decisivo. El Wreck Site del Dron de A3 generó una disputa territorial secundaria en el minuto 10. El conducto del techo fue utilizado como ruta táctica alternativa tanto por Drones como para intentar interrumpir el hackeo.

### Pilar 5 — ¿El Equipo Importó más que el Jugador Individual? ✅ VALIDADO
**Evidencia en la simulación**: La victoria de Alfa en el segundo hackeo requirió la cadena de 4 operadores actuando en secuencia perfecta (A1 Sonar → A4 Vectoring → A2 fuego → A3 sacrificio EMP). Ninguno de los 4 pudo haber logrado la victoria solo. B1 falló en Gen 3 precisamente porque intentó canalizar con apoyo de escuadra insuficiente.

---

## ⚠️ PROBLEMAS DETECTADOS Y PROPUESTAS DE MITIGACIÓN

### Problema 1: Reseteo Total del Progreso del Núcleo al ser Expulsado
- **Impacto**: Puede sentirse excesivamente punitivo y desincentivar intentos de hackeo arriesgados.
- **Propuesta A**: El progreso cae a una tasa lenta (ej. 10% por cada 30 segundos de control enemigo) en lugar de resetear instantáneamente.
- **Propuesta B**: El progreso se "bloquea" en el último porcentaje alcanzado y solo decae si el rival mantiene control del perímetro durante más de 15 segundos continuos.
- **Decisión**: Pendiente de prototipado en `sandbox/`.

### Problema 2: Ventana de Interrupción de Gen 2 Demasiado Corta
- **Impacto**: B1 canalizó Gen 2 sin que Alfa pudiera interceptar aunque lo detectó. 4 segundos puede ser insuficiente para generar dramas reales de interrupción.
- **Propuesta A**: Aumentar el tiempo de canalización a 6-8 segundos. El riesgo de interrumpir aumenta, pero la ventana táctica se vuelve más significativa.
- **Propuesta B**: La firma de canalización se detecta 3 segundos *antes* de que comience (fase de "calentamiento" del Centro de Integración), dando al rival una ventana más amplia de reacción.
- **Decisión**: Pendiente de prototipado en `sandbox/`.

### Problema 3: El Rol Tech Scavenger Puede Quedar Fuera del Combate
- **Impacto**: B3 pasó la mayor parte de la partida cosechando sin participar directamente en los combates de alta tensión. Puede sentirse como un rol aburrido o pasivo.
- **Propuesta A**: El Scavenger tiene un alcance de extracción de recursos remoto (vía Dron) para que pueda cosechar sin dejar de participar en la presión territorial.
- **Propuesta B**: Rebalancear para que el rol Logístico sea siempre compartido entre dos operadores en lugar de ser la responsabilidad exclusiva de uno.
- **Decisión**: Pendiente de profundización en `operator_design_rules.md`.

### Problema 4: Gen 3 No Apareció en Esta Partida
- **Observación**: La partida se resolvió en Gen 2 sin que ningún equipo completara Gen 3. Esto es conceptualmente correcto (Gen 3 es excepcional), pero significa que los Efectos de Red de Gen 3 son actualmente no testeados en condiciones reales.
- **Propuesta**: Generar una segunda simulación donde ambas escuadras lleguen a Gen 3 y analizar si los Efectos de Red crean una ventaja insuperable o una superioridad estratégica manejable.
- **Decisión**: Se recomienda crear `full_match_simulation_gen3.md` en la próxima fase de validación.
