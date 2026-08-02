# CONTRATO DE VALIDACIÓN — VERTICAL SLICE SUCCESS CRITERIA

- **Estado**: Activo — Contrato de Evaluación Previo a Implementación
- **Ubicación**: `docs/specs/vertical_slice/vertical_slice_success_criteria.md`
- **Versión**: 1.0

---

> **Este documento es un contrato.**
> Define cómo sabremos si el Vertical Slice valida la identidad de GRAVITY antes de continuar con producción.
> No puede modificarse sin aprobación explícita del Director de Proyecto.

---

## 🎯 1. CRITERIO PRINCIPAL DE ÉXITO

### La Pregunta

> **"Después de jugar 15-30 minutos, ¿los jugadores sienten que están coordinando información, drones y territorio en lugar de simplemente disparando enemigos?"**

### Cómo se Evalúa

La pregunta se responde observando el comportamiento espontáneo de los jugadores durante el playtest — no lo que dicen que hacen, sino **lo que realmente hacen**. Las verbalizaciones espontáneas son la evidencia más valiosa.

**El VS ha aprobado si**:
- Los jugadores hablan sobre el Dron, las rutas y la posición del Núcleo durante la partida.
- Los jugadores esperan o solicitan información antes de avanzar.
- Al fallar, los jugadores atribuyen la causa a una mala decisión táctica, no a la puntería.

**El VS ha fallado si**:
- Los jugadores corren directamente al objetivo sin coordinación.
- La comunicación del equipo es exclusivamente sobre disparar.
- Al ganar o perder, nadie menciona el Dron, la información o el terreno.

---

## 📊 2. MATRIZ DE VALIDACIÓN POR PILARES

Cada pilar necesita evidencia observable, no solo que los sistemas funcionen técnicamente.

---

### PILAR 1 — La Información es el Recurso más Valioso

| Aspecto | Evidencia Observable en Gameplay | Método de Prueba |
| :--- | :--- | :--- |
| Los jugadores esperan información antes de avanzar | El Recon envía el Dron antes del avance del Vanguard. El equipo detiene su movimiento esperando el feed. | Observación directa de secuencias de acción durante el playtest. |
| Las decisiones cambian según lo revelado | El equipo cambia de ruta después de que el Dron detecta una posición enemiga. | Registrar cuántas veces el equipo cambia de ruta o táctica después de recibir información de Dron. |
| Avanzar sin información es peligroso | Cuando un jugador avanza sin usar el Dron, es incapacitado con mayor frecuencia que cuando avanza con información previa. | Comparar tasa de incapacitación entre avances con Dron activo vs. avances sin Dron activo. |

**Indicador clave**: Los jugadores verbalizan *"¿qué ves?"* o *"manda el dron antes"* de forma espontánea.

**Umbral de aprobación**: Al menos el 60% de los avances al sector del Núcleo son precedidos por un escaneo deliberado de Dron.

---

### PILAR 2 — El Jugador Nunca Combate Solo

| Aspecto | Evidencia Observable en Gameplay | Método de Prueba |
| :--- | :--- | :--- |
| Operador + Dron funcionando como unidad | Los jugadores cambian el modo del Dron de forma activa y deliberada durante el combate, no solo al inicio. | Contar cuántas veces se cambia el modo del Dron durante una sesión completa por jugador. |
| Los jugadores se ayudan mediante información o soporte | El Field Engineer repara el Dron de un aliado durante el combate. El Recon transmite posiciones a su equipo. | Observar si hay comunicación de soporte entre jugadores (no solo ataques individuales). |
| La pérdida del Dron cambia el comportamiento | Cuando un jugador pierde su Dron, retrocede a zona más segura o solicita ayuda al Field Engineer. | Registrar el comportamiento del jugador durante los primeros 30 segundos tras la destrucción del Dron. |

**Indicador clave**: Los jugadores dicen *"me destruyeron el dron"* como un evento importante — no lo ignoran.

**Umbral de aprobación**: El Dron es utilizado en al menos 2 de sus 3 modos por cada jugador durante una sesión.

---

### PILAR 3 — El Objetivo es Controlar el Núcleo IA

| Aspecto | Evidencia Observable en Gameplay | Método de Prueba |
| :--- | :--- | :--- |
| Los jugadores priorizan el hackeo y el control territorial | Los jugadores se mueven hacia el Núcleo incluso si hay enemigos en otras zonas del mapa. | Observar si el equipo abandona combates periféricos para priorizar el perímetro del Núcleo. |
| Eliminar enemigos es un medio, no la victoria | Al terminar la sesión, los jugadores mencionan el progreso del Núcleo, no la cantidad de bajas. | Pregunta directa post-sesión: *"¿Qué fue el momento decisivo de la partida?"* |
| El Estado Contestado genera el pico de tensión | Los jugadores reaccionan visualmente y vocalmente al entrar en Estado Contestado. | Observar reacciones durante el Estado Contestado. El silencio tenso o las exclamaciones son métricas de tensión. |

**Indicador clave**: La barra de hackeo del Núcleo es mencionada espontáneamente durante la partida.

**Umbral de aprobación**: Al menos el 50% de los comentarios durante el playtest se refieren al Núcleo, al perímetro o al porcentaje de descarga — no a bajas de enemigos.

---

### PILAR 4 — El Terreno Decide la Batalla

| Aspecto | Evidencia Observable en Gameplay | Método de Prueba |
| :--- | :--- | :--- |
| Rutas diferentes generan estrategias diferentes | Los jugadores debaten activamente qué ruta tomar. No todos van por la misma. | Registrar las rutas utilizadas en cada intento de hackeo. Si siempre van por la misma, el mapa falla. |
| Las coberturas tienen valor real | Los jugadores buscan cobertura activamente antes de avanzar o durante el fuego. | Observar si los jugadores avanzan en campo abierto o buscan coberturas. |
| La elevación otorga ventaja perceptible | El jugador en posición elevada tiene mayor efectividad de supresión que en posición baja. | Comparar la tasa de impactos del jugador elevado vs. los jugadores en el corredor central. |
| Los conductos del Dron se usan estratégicamente | Al menos un jugador usa los conductos en Modo Piloto para explorar sin exponer su cuerpo. | Registrar el uso de los conductos durante la sesión. Si no se usan nunca, la señalización es insuficiente. |

**Indicador clave**: Los jugadores mencionan posiciones específicas del mapa por referencia propia (*"voy por abajo"*, *"hay uno en el piso de arriba"*).

**Umbral de aprobación**: Se utilizan al menos 2 rutas distintas durante una sesión completa. Los conductos se usan en al menos 1 de cada 3 sesiones.

---

### PILAR 5 — La Cooperación Supera al Héroe Individual

| Aspecto | Evidencia Observable en Gameplay | Método de Prueba |
| :--- | :--- | :--- |
| Un jugador solo tiene limitaciones claras | Si un jugador intenta hackear el Núcleo solo (sin el equipo), es rechazado por la IA defensora consistentemente. | Diseñar 1 sesión de prueba donde 1 jugador intenta el hackeo solo vs. el equipo completo coordinado. |
| La coordinación aumenta las posibilidades | Los intentos de hackeo exitosos ocurren cuando múltiples jugadores coordinan roles distintos (Recon escanea, Vanguard avanza, Disruptor abre puerta). | Comparar la tasa de éxito de hackeo en intentos coordinados vs. no coordinados. |
| Cada rol es percibido como necesario | Los jugadores defienden su rol: *"sin el Recon no podemos saber dónde están"*, *"necesitamos que el Engineer repare el dron"*. | Observar si los jugadores reconocen la contribución única de cada rol durante el juego. |

**Indicador clave**: Cuando cae un jugador de un rol específico, sus compañeros reaccionan a la pérdida de ese rol, no solo a la pérdida del jugador.

**Umbral de aprobación**: El equipo de 4 jugadores coordinados completa el hackeo con mayor frecuencia que el mismo equipo cuando cada jugador actúa de forma autónoma.

---

## 🧪 3. MÉTRICAS DEL PRIMER PLAYTEST

### Configuración de Sesión

| Parámetro | Valor |
| :--- | :--- |
| **Cantidad de jugadores** | 4 jugadores. Los primeros playtests siempre deben ser con el máximo de jugadores para validar la experiencia de cooperación completa. |
| **Perfil de jugadores** | Jugadores con experiencia en shooters tácticos pero sin conocimiento previo del diseño de GRAVITY. |
| **Duración de sesión** | 15-30 minutos por sesión. Máximo 2 sesiones consecutivas por grupo. |
| **Briefing previo** | Mínimo: explicar los controles básicos y el objetivo del Núcleo. No explicar la importancia del Dron — debe descubrirse durante el juego. |
| **Observadores** | Al menos 1 persona del equipo de desarrollo observa sin participar ni intervenir. |

### Comportamientos a Observar (Checklist del Observador)

```
INFORMACIÓN Y DRON:
[ ] ¿Los jugadores usan el Dron para explorar antes de avanzar?
[ ] ¿El Recon comparte información con su equipo activamente?
[ ] ¿Los jugadores cambian de decisión después de recibir información del Dron?
[ ] ¿La pérdida del Dron provoca un cambio de comportamiento observable?
[ ] ¿El Modo Piloto se usa deliberadamente, no accidentalmente?

OBJETIVO:
[ ] ¿Los jugadores se mueven hacia el Núcleo sin instrucción explícita?
[ ] ¿Los jugadores mencionan la barra de hackeo espontáneamente?
[ ] ¿El Estado Contestado provoca reacciones visibles (tensión, exclamaciones)?
[ ] ¿Los jugadores priorizan el perímetro del Núcleo sobre los combates periféricos?

TERRENO:
[ ] ¿Los jugadores usan más de 1 ruta del mapa en la sesión?
[ ] ¿Los jugadores buscan coberturas activamente?
[ ] ¿Los conductos del Dron son utilizados al menos 1 vez?
[ ] ¿Se menciona alguna posición del mapa por referencia propia?

COOPERACIÓN:
[ ] ¿Los jugadores comunican su posición o intención antes de actuar?
[ ] ¿Los jugadores reaccionan a la caída de un compañero como pérdida de rol?
[ ] ¿El Field Engineer es solicitado o mencionado durante la sesión?
[ ] ¿Se produce alguna maniobra que requirió 3 o más roles coordinados?
```

### Preguntas Posteriores al Jugador (Entrevista Post-Sesión)

Estas preguntas se hacen individualmente, no en grupo, para evitar influencia entre respuestas:

1. *"¿Qué fue el momento más tenso de la partida?"*
   → Respuesta esperada: algo relacionado con el Núcleo, el Estado Contestado o la pérdida del Dron.

2. *"¿Hubo un momento donde necesitaste a tus compañeros para avanzar?"*
   → Respuesta esperada: sí, y que describan una situación concreta con roles.

3. *"¿El Dron fue útil, o podías hacer lo mismo sin él?"*
   → Respuesta esperada: fue útil y lo explican concretamente.

4. *"¿El mapa influyó en tus decisiones de movimiento?"*
   → Respuesta esperada: sí, mencionan rutas o posiciones específicas.

5. *"¿Sentiste en algún momento que ganar dependía solo de tu puntería?"*
   → Respuesta esperada: no. Si la respuesta es sí, es señal de alerta.

6. *"¿Qué fue lo primero que hiciste al empezar la partida?"*
   → Respuesta esperada: enviar el Dron a explorar o pedir información al Recon.

---

## 🔴 4. FALLOS CRÍTICOS — BLOQUEAN EL AVANCE

Si cualquiera de las siguientes situaciones se confirma durante el playtest, el desarrollo del VS **se detiene** hasta corregir el sistema responsable. No es un ajuste de balance — es una corrección de diseño.

| # | Fallo Crítico | Sistema Responsable | Acción |
| :- | :--- | :--- | :--- |
| **FC-01** | Los jugadores ignoran el Dron durante toda la sesión. Lo activan al inicio y lo dejan en Modo Escolta sin volver a interactuar con él. | Sistema del Dron + TTK sin información | Revisar penalización por avanzar sin información. El Modo Piloto debe ser necesario para llegar al Núcleo. |
| **FC-02** | Todos los jugadores actúan de forma independiente. No hay comunicación ni coordinación observable en 2 sesiones consecutivas. | Diseño de roles + dependencias entre operadores | Revisar si las dependencias entre roles son realmente necesarias o si cada operador puede ser autosuficiente. |
| **FC-03** | Ganar depende principalmente de puntería. El equipo con más bajas gana consistentemente, independientemente de la coordinación táctica. | TTK, sistema de disparo, diseño de IA defensora | Revisar el TTK y la IA defensora. El combate debe requerir información y posicionamiento para ser efectivo. |
| **FC-04** | El Núcleo IA no genera tensión observable. La barra de hackeo es ignorada durante el combate. No hay reacciones al Estado Contestado. | Sistema de progreso del Núcleo + HUD | Revisar la señalización del Estado Contestado. Revisar si la tasa de degradación genera urgencia real. |
| **FC-05** | El mapa no importa. Los jugadores siempre usan la misma ruta y nunca mencionan posiciones. | Diseño del mapa SANDBOX-01 | Revisar el valor de las rutas alternativas. Las rutas deben tener ventajas y desventajas claras y percibibles. |
| **FC-06** | El Field Engineer es ignorado o percibido como prescindible en ambas sesiones. | Rol Field Engineer | Revisar si la pérdida del Dron es suficientemente impactante para crear necesidad del Engineer. |
| **FC-07** | Los jugadores pueden completar el hackeo del Núcleo consistentemente sin coordinación de roles. | Dificultad de la IA defensora + diseño del perímetro | Aumentar la cantidad o efectividad de la IA defensora hasta que el hackeo requiera coordinación explícita. |

---

## 📋 5. SEPARACIÓN ENTRE PROTOTIPO Y PRODUCTO FINAL

### Aceptable en el Vertical Slice

Estas deficiencias son esperadas y **no constituyen fallos**. El playtest las evalúa como contexto, no como criterio de valoración.

| Elemento | Por qué es Aceptable |
| :--- | :--- |
| **Arte temporal (placeholders)** | Los jugadores de playtest entienden que están evaluando mecánicas, no el producto terminado. |
| **Balance de números incorrecto** | El TTK, el tiempo de síntesis del Dron y la velocidad de degradación del Núcleo se ajustan con datos de playtest. No antes. |
| **IA defensora simple y predecible** | La IA del VS no necesita ser sofisticada. Solo necesita crear resistencia suficiente para que el equipo deba coordinarse. |
| **Números provisionales de recursos** | El cap de inventario, la tasa de cosecha y el coste de síntesis son estimaciones. Se calibran en playtest. |
| **Sin sonido definitivo** | Efectos de sonido de placeholder son suficientes para validar la tensión del Estado Contestado. |
| **Sin animaciones de producción** | Los operadores como cápsulas de color funcionan para validar las mecánicas tácticas. |
| **Un solo mapa** | SANDBOX-01 es suficiente para validar todas las preguntas del Validation Plan. |

---

### NO Aceptable en el Vertical Slice

Estas deficiencias **sí constituyen fallos** y obligan a detener el avance. Si aparecen durante la implementación o el playtest, deben corregirse antes de continuar.

| Elemento | Por qué NO es Aceptable | Consecuencia |
| :--- | :--- | :--- |
| **Romper cualquiera de los 5 pilares** | Los pilares son la identidad irrenunciable de GRAVITY. Una mecánica que los contradiga no pertenece al VS. | Eliminar o rediseñar la mecánica en cuestión. |
| **Eliminar la importancia del Dron** | El Dron es la extensión permanente del operador. Si puede ignorarse sin consecuencias tácticas, la Tríada Táctica no existe. | Revisar el sistema de Dron y la penalización por no usarlo. |
| **Convertirlo en un shooter tradicional** | Si la información y el territorio son irrelevantes y ganar depende solo de la puntería, GRAVITY no existe — es un TPS genérico. | FC-03 activado. Detener desarrollo. |
| **Que el Núcleo sea un MacGuffin pasivo** | El Núcleo debe ser el foco activo de todas las decisiones tácticas, no un objetivo que se ignora hasta que alguien recuerda que existe. | FC-04 activado. Detener desarrollo. |
| **Que los roles sean intercambiables** | Si jugar Recon, Vanguard, Disruptor o Engineer produce la misma experiencia táctica, el diseño de roles ha fallado. | FC-02 y FC-06 activados. Revisar dependencias entre roles. |

---

## ✍️ Firma del Contrato

Este documento fue redactado y aprobado antes del inicio de la **Etapa 1 — Cámara y Movimiento Base** del Vertical Slice Implementation Plan.

Cualquier modificación posterior al inicio de implementación requiere:
1. Una justificación escrita en `memory/decisions/`.
2. Revisión de si la modificación invalida alguna pregunta del `vertical_slice_validation_plan.md`.
3. Aprobación del Director de Proyecto.

**El Vertical Slice puede comenzar a construirse.**
