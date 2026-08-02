# SPEC: VERTICAL SLICE VALIDATION PLAN — PLAN DE VALIDACIÓN DEL PROTOTIPO

- **Estado**: Activo — Fase 1: Vertical Slice Design
- **Ubicación**: `docs/specs/vertical_slice/vertical_slice_validation_plan.md`
- **Versión**: 1.0

---

## 🎯 Propósito

Definir las preguntas concretas que el Vertical Slice debe ser capaz de responder al finalizar su ciclo de playtest. Cada pregunta se asocia a un **sistema evaluado**, una **métrica de observación** y un **criterio de aprobación o fallo**.

Si el prototipo no puede responder estas preguntas de forma inequívoca, el Vertical Slice no ha cumplido su propósito.

---

## 📋 Las 12 Preguntas de Validación

---

### BLOQUE A — Sistema de Información

#### A1. ¿La información del Dron cambia las decisiones del equipo?
- **Sistema evaluado**: Modos de Dron (Escolta / Estacionario / Piloto) + Dron del Recon.
- **Cómo observar**: Durante el playtest, ¿los jugadores cambian su ruta de avance después de que el Recon comparte información? ¿Hay momentos donde el equipo espera información antes de actuar?
- **Criterio de aprobación**: Al menos el 75% de los movimientos de ataque al Núcleo son precedidos por un escaneo deliberado de Dron.
- **Criterio de fallo**: Los jugadores avanzan directamente al Núcleo sin usar el Dron para explorar. La información no influye en la táctica.
- **Corrección si falla**: La penalización por avanzar sin información (TTK elevado, supresión) no es suficiente. Revisar la visibilidad del cono de visión enemigo en el HUD.

#### A2. ¿El combate sin información es suficientemente castigado?
- **Sistema evaluado**: TTK frontal, supresión, Niebla de Guerra básica.
- **Cómo observar**: Cuando un jugador avanza sin información previa, ¿pierde la confrontación de forma consistente? ¿Siente que fue su error y no mala suerte?
- **Criterio de aprobación**: Los jugadores verbalizan *"debí haber mandado el dron antes"* — la derrota se atribuye a falta de información, no a estadísticas de daño.
- **Criterio de fallo**: Los jugadores avanzan a ciegas y tienen éxito regularmente. La información se vuelve opcional.
- **Corrección si falla**: Aumentar el cono de visión enemigo o reducir el margen de reacción sin información previa.

---

### BLOQUE B — Sistema del Dron

#### B1. ¿Es divertido coordinar drones?
- **Sistema evaluado**: Los 3 Modos de Dron en sesión cooperativa.
- **Cómo observar**: ¿Los jugadores coordinan activamente los roles de sus Drones? ¿Un jugador anuncia *"pongo mi Dron estacionario en la esquina"* y otro responde a esa información?
- **Criterio de aprobación**: En cada intento de hackeo del Núcleo, al menos 2 de los 4 jugadores tienen sus Drones en posiciones coordinadas (uno escaneando, uno estacionario en la entrada, etc.).
- **Criterio de fallo**: Los Drones se usan de forma individual y no coordinada. Cada jugador trata su Dron como una herramienta personal sin comunicarlo.

#### B2. ¿La pérdida del Dron genera tensión real?
- **Sistema evaluado**: Síntesis del Dron, Wreck Sites, reparación del Field Engineer.
- **Cómo observar**: Cuando un Dron es destruido, ¿el jugador afectado cambia su comportamiento? ¿Retrocede a posición más segura? ¿Solicita ayuda al Field Engineer?
- **Criterio de aprobación**: La pérdida del Dron es un evento notable en la sesión — los jugadores lo comentan y ajustan su táctica.
- **Criterio de fallo**: La pérdida del Dron es ignorada. El jugador continúa avanzando como si nada.
- **Corrección si falla**: El tiempo de síntesis es demasiado corto. Aumentar la penalización temporal.

#### B3. ¿El Modo Piloto es una decisión de riesgo real?
- **Sistema evaluado**: Vulnerabilidad del cuerpo del operador durante el Modo Piloto.
- **Cómo observar**: ¿Los jugadores dudan antes de usar el Modo Piloto? ¿Piden cobertura a sus aliados? ¿Los cuerpos inmóviles son atacados por la IA defensora?
- **Criterio de aprobación**: El Modo Piloto se usa estratégicamente, no automáticamente. Los jugadores evalúan el riesgo antes de activarlo.
- **Criterio de fallo**: Los jugadores siempre usan el Modo Piloto o nunca lo usan. No hay decisión.

---

### BLOQUE C — Objetivo del Núcleo IA

#### C1. ¿El Núcleo IA genera tensión sostenida?
- **Sistema evaluado**: Sistema de progreso con Estados Activo / Contestado / Degradación.
- **Cómo observar**: ¿El equipo celebra cuando la barra sube? ¿Se frustra (constructivamente) cuando entra en Degradación? ¿Hay momentos de silencio tenso durante el Estado Contestado?
- **Criterio de aprobación**: Los jugadores verbalizan la barra de hackeo espontáneamente — *"ya llegamos al 60%"*, *"no la suelten"*, *"están revertiéndola"*.
- **Criterio de fallo**: Los jugadores ignoran la barra durante el combate. El hackeo se siente como un indicador pasivo, no como un objetivo activo.

#### C2. ¿El Estado Contestado genera el pico de tensión de la partida?
- **Sistema evaluado**: Barra congelada, combate en el perímetro del Núcleo.
- **Cómo observar**: Durante el Estado Contestado, ¿todos los jugadores convergen en el perímetro? ¿Sube el nivel de comunicación verbal del equipo?
- **Criterio de aprobación**: El Estado Contestado es el momento más recordado de cada sesión. Los jugadores lo mencionan al terminar.
- **Criterio de fallo**: El Estado Contestado pasa desapercibido o los jugadores no comprenden por qué la barra está congelada.
- **Corrección si falla**: El feedback visual/auditivo del Estado Contestado es insuficiente. Reforzar señal de UI.

#### C3. ¿La Degradación gradual (no el reseteo) se siente justa?
- **Sistema evaluado**: Tasa de degradación -10%/30 seg, umbral al 50%.
- **Cómo observar**: Cuando el equipo pierde el perímetro y la barra empieza a caer, ¿los jugadores sienten que tienen tiempo para recuperar? ¿O sienten que la caída es demasiado lenta (sin urgencia) o demasiado rápida (injusta)?
- **Criterio de aprobación**: Los jugadores reconquistan el perímetro con urgencia pero sin pánico. La tasa de degradación crea presión sin desesperación.
- **Criterio de fallo A**: La degradación es tan lenta que el equipo no siente urgencia por recuperar. Se toman su tiempo.
- **Criterio de fallo B**: La degradación es tan rápida que el equipo siente que el esfuerzo previo fue en vano.

---

### BLOQUE D — Cooperación y Roles

#### D1. ¿4 jugadores coordinados sienten una ventaja real sobre el caos?
- **Sistema evaluado**: Sinergia de los 4 roles tácticos en sesión cooperativa.
- **Cómo observar**: Comparar sesiones donde el equipo se coordina verbalmente vs. sesiones donde cada uno actúa por su cuenta. ¿La diferencia en efectividad es notable?
- **Criterio de aprobación**: Las sesiones coordinadas llegan consistentemente más lejos en la barra de hackeo que las sesiones descoordinadas.
- **Criterio de fallo**: El hackeo puede completarse con individuos actuando de forma autónoma sin comunicación. La cooperación no aporta ventaja medible.

#### D2. ¿El Field Engineer se siente necesario y activo?
- **Sistema evaluado**: Cosecha remota, reparación Dron-a-Dron, consolidación de Wreck Sites.
- **Cómo observar**: ¿El equipo nota cuando el Field Engineer cae? ¿Los demás jugadores reclaman su ausencia? ¿El Field Engineer siente que está participando en el combate, no solo recolectando?
- **Criterio de aprobación**: Cuando el Field Engineer cae, al menos 1 jugador del equipo reacciona verbalmente a su pérdida.
- **Criterio de fallo**: Ningún jugador nota la ausencia del Field Engineer. El rol se percibe como prescindible.

#### D3. ¿Cada rol táctico aporta algo único e insustituible en el VS?
- **Sistema evaluado**: Los 4 operadores prototipo.
- **Cómo observar**: Sesiones con distintas composiciones (3 Vanguard + 1 Recon vs. 1 de cada rol). ¿La composición diversa es claramente superior?
- **Criterio de aprobación**: Los jugadores defienden espontáneamente su rol — *"necesitamos al Recon aquí"* — reconociendo la contribución única de cada función.
- **Criterio de fallo**: Todos los operadores se sienten intercambiables. Los jugadores eligen rol por preferencia estética, no táctica.

---

### BLOQUE E — Experiencia General

#### E1. ¿El equipo quiere jugar otra ronda al terminar?
- **Sistema evaluado**: El loop completo de sesión (exploración → combate → hackeo → victoria/derrota).
- **Cómo observar**: Pregunta directa después de la primera sesión: *"¿quieren repetir?"*.
- **Criterio de aprobación**: 3 de 4 jugadores quieren otra sesión inmediatamente.
- **Criterio de fallo**: Los jugadores se sienten satisfechos con una sola sesión o expresan confusión sobre el loop.

---

## 🔴 Criterios de Fallo Crítico (Bloquean el Avance)

Si alguno de los siguientes fallos se confirma en playtest, **el Vertical Slice no puede avanzar a producción** sin rediseño del sistema afectado:

| Fallo Crítico | Sistema Afectado | Acción |
| :--- | :--- | :--- |
| La información del Dron es ignorada sistemáticamente | Sistema de Dron e Información | Rediseñar penalización por avanzar sin información |
| El Núcleo IA no genera tensión observable | Sistema de Objetivo | Rediseñar la señalización y la tasa de progreso |
| La cooperación no produce ventaja medible | Diseño de Roles | Revisar las dependencias entre roles |
| El Field Engineer se percibe como innecesario | Rol Field Engineer | Ampliar funciones activas; reducir pasividad de cosecha |

---

## 📅 Estructura de Sesiones de Playtest

El Vertical Slice se valida en 3 ciclos de playtest:

### Ciclo 1 — Alpha Interna (semana 1 de testing)
- Participantes: El equipo de desarrollo.
- Objetivo: Verificar que los sistemas básicos son funcionales y jugables.
- Preguntas a responder: B1, B2, B3, C1.

### Ciclo 2 — Playtest Externo (semana 2-3)
- Participantes: Jugadores sin conocimiento previo del diseño.
- Objetivo: Validar la curva de aprendizaje y la claridad del loop.
- Preguntas a responder: A1, A2, C2, C3, D1, D2, D3.

### Ciclo 3 — Validación Final (semana 4)
- Participantes: Combinación de internos y externos.
- Objetivo: Confirmar E1 y decidir si el VS ha aprobado.
- Preguntas a responder: E1 + revisión de todos los criterios de fallo.

---

## 📊 Plantilla de Registro de Sesión de Playtest

```
Fecha: ___________
Jugadores: ___________
Duración de la sesión: ___________
Versión del VS: ___________

OBSERVACIONES POR BLOQUE:
[ ] A1 — ¿Usaron el Dron para explorar antes de atacar?
[ ] A2 — ¿Mencionaron falta de información cuando fallaron?
[ ] B1 — ¿Coordinaron los modos de Dron?
[ ] B2 — ¿Reaccionaron a la pérdida del Dron?
[ ] B3 — ¿El Modo Piloto fue una decisión, no un reflejo?
[ ] C1 — ¿Mencionaron la barra de hackeo espontáneamente?
[ ] C2 — ¿El Estado Contestado fue el pico de tensión?
[ ] C3 — ¿La Degradación se sintió justa?
[ ] D1 — ¿La coordinación produjo ventaja observable?
[ ] D2 — ¿Notaron la ausencia del Field Engineer?
[ ] D3 — ¿Cada rol fue percibido como único?
[ ] E1 — ¿Quisieron jugar otra ronda?

FALLOS CRÍTICOS DETECTADOS:
___________________________________________

AJUSTES PROPUESTOS:
___________________________________________
```
