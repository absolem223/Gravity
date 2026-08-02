# SPEC: VERTICAL SLICE IMPLEMENTATION PLAN — PLAN DE IMPLEMENTACIÓN

- **Estado**: Activo — Alcance CONGELADO ✅
- **Ubicación**: `docs/specs/vertical_slice/vertical_slice_implementation_plan.md`
- **Versión**: 1.0

---

## 🎯 Propósito

Este documento define el orden exacto de implementación del Vertical Slice, las dependencias entre sistemas, los criterios de Done de cada etapa y las restricciones de alcance que no pueden ampliarse sin una decisión explícita de diseño.

---

## 🔒 FREEZE DE ALCANCE — ALCANCE CONGELADO

El alcance del Vertical Slice está **oficialmente congelado**. Las siguientes listas son exhaustivas.

### Lo que ENTRA en el VS:
- ✅ Cámara Top-Down Isométrica con zoom dinámico.
- ✅ Movimiento de operador en 8 direcciones.
- ✅ Input cooperativo local: 3 mandos + 1 teclado.
- ✅ Dron Gen 1 con 3 modos: Escolta, Estacionario, Piloto.
- ✅ 4 operadores prototipo (1 por rol táctico).
- ✅ Mapa SANDBOX-01 con 3 rutas, elevación y conductos.
- ✅ Núcleo IA: progreso con estados Activo / Contestado / Degradación.
- ✅ Recursos básicos: Componentes de Mantenimiento + Wreck Sites.
- ✅ IA defensora básica (patrulla + respuesta a intrusión).
- ✅ Sesión cooperativa local 2-4 jugadores.

### Lo que QUEDA FUERA del VS (no negociable):
- ❌ Generaciones Tecnológicas Gen 2 y Gen 3.
- ❌ Doctrinas tecnológicas y ramas de evolución.
- ❌ Más de 4 operadores.
- ❌ Más de 1 mapa.
- ❌ Multiplayer online / networking.
- ❌ Sistema de matchmaking.
- ❌ Progresión permanente entre sesiones.
- ❌ Arte definitivo o animaciones de producción.
- ❌ Balance final de números.
- ❌ Sonido definitivo.

### Regla de validación de alcance:
> **"¿Este sistema demuestra uno de los 5 pilares de GRAVITY?"**
> Si la respuesta es no, queda fuera del Vertical Slice.

| Sistema | Pilar que demuestra |
| :--- | :--- |
| Cámara + movimiento | Pilar 4 — El terreno decide la batalla |
| Dron Gen 1 | Pilar 1 — La información es el recurso más valioso |
| Dron Gen 1 | Pilar 2 — El jugador nunca combate solo |
| 4 operadores prototipo | Pilar 5 — La cooperación supera al héroe individual |
| Núcleo IA con persistencia | Pilar 3 — El objetivo es controlar el Núcleo IA |
| Mapa SANDBOX-01 | Pilar 4 — El terreno decide la batalla |
| Recursos + Wreck Sites | Pilar 2 — El jugador nunca combate solo |

---

## 📋 DECISIONES TÉCNICAS CERRADAS (DTs)

| ID | Decisión | Estado |
| :- | :--- | :---: |
| **DT-01** | Cámara Top-Down Isométrica (`Camera3D`, ángulo 60-70°, zoom dinámico centrado en el grupo) | ✅ |
| **DT-02** | Movimiento del operador: `CharacterBody3D` + `move_and_slide()` | ✅ |
| **DT-03** | Sin persistencia entre sesiones. Todo en memoria. Sin guardado. | ✅ |

---

## 🗓️ ORDEN DE IMPLEMENTACIÓN — 9 ETAPAS

Las etapas están ordenadas por dependencias. **Ninguna etapa puede comenzar sin que la anterior haya pasado su criterio de Done.**

---

### ETAPA 1 — Cámara y Movimiento Base
**Pilar que valida**: Pilar 4 (El terreno decide).
**Dependencias**: Ninguna. Es el punto de partida de todo.

#### Tareas:
- [ ] Configurar proyecto Godot en `game/` con estructura de carpetas de módulos.
- [ ] Implementar `Camera3D` con ángulo fijo de 60-70° sobre el plano XZ.
- [ ] Implementar zoom dinámico: el encuadre agranda cuando los jugadores se separan.
- [ ] Implementar `operator_base.gd` con `CharacterBody3D`: movimiento en 8 direcciones, colisiones con el entorno.
- [ ] Placeholder visual del operador (capsula + color diferenciador por jugador).

#### Criterio de Done:
> Un operador se mueve por el espacio 3D y la cámara le sigue con ángulo isométrico correcto. El zoom se adapta si hay 2 operadores separados en el mapa.

---

### ETAPA 2 — Input Cooperativo Local 2-4 Jugadores
**Pilar que valida**: Pilar 5 (La cooperación supera al héroe individual).
**Dependencias**: Etapa 1 completada.

#### Tareas:
- [ ] Configurar `InputMap` en Godot para 3 perfiles de mando (Jugador 1, 2, 3) con ejes y botones mapeados.
- [ ] Configurar perfil de teclado + ratón (Jugador 4).
- [ ] Implementar `session_manager.gd`: detecta cuántos controladores están conectados al inicio y asigna un operador a cada uno.
- [ ] Verificar que los 4 jugadores se mueven de forma independiente en la misma escena.
- [ ] El `session_manager` debe funcionar con 2, 3 o 4 jugadores sin cambios de código.

#### Criterio de Done:
> 4 operadores se mueven de forma independiente en la misma escena, cada uno controlado por su input asignado. Al desconectar un mando, la sesión no crashea.

---

### ETAPA 3 — Operador Base con Disparo
**Pilar que valida**: Pilar 1 (La información), Pilar 4 (El terreno).
**Dependencias**: Etapas 1 y 2 completadas.

#### Tareas:
- [ ] Añadir sistema de disparo a `operator_base.gd`: raycast o projectile según perspectiva isométrica.
- [ ] Implementar sistema de salud (HP) con estado `INCAPACITATED`.
- [ ] Al ser incapacitado: el operador suelta el 50% de sus Componentes en la posición actual.
- [ ] Implementar TTK (Time-to-Kill) provisional — ajustar en playtest, no ahora.
- [ ] Implementar cobertura básica: el operador detrás de un objeto de geometría recibe reducción de daño.
- [ ] Cono de visión del operador: área visible en el HUD. Fuera del cono es Niebla de Guerra.

#### Criterio de Done:
> Un operador puede disparar a otro. Si recibe suficiente daño, queda incapacitado. La cobertura reduce el daño recibido. El cono de visión funciona — lo que está fuera no es visible en el HUD.

---

### ETAPA 4 — Dron Gen 1: Modos Escolta, Estacionario y Piloto
**Pilar que valida**: Pilar 1 (La información), Pilar 2 (Nunca solo).
**Dependencias**: Etapas 1, 2 y 3 completadas.
**Nota**: Esta es la etapa más compleja del VS. Requiere la mayor inversión de tiempo.

#### Tareas:
- [ ] Implementar `drone_base.gd` como nodo hijo del operador.
- [ ] **Modo Escolta**: El Dron orbita el hombro del operador a distancia fija. Actualiza su cono de visión secundario. Detecta entidades en su rango.
- [ ] **Modo Estacionario**: El Dron se ancla a la superficie más cercana. El feed de su cámara aparece en el HUD como ventana pequeña. Puede ser destruido en ese estado.
- [ ] **Modo Piloto**: La cámara del jugador pasa a la perspectiva del Dron. El cuerpo del operador queda inmóvil y con `is_piloting = true`. Soltar el botón devuelve el control.
- [ ] **Batería Táctica**: Barra compartida. Modo Piloto drena 2x. Se recarga lentamente en Modo Escolta.
- [ ] **Estado DESTROYED**: Al recibir daño máximo, el Dron pasa a `DESTROYED`. El operador pasa a `DRONE_LOST`. El Wreck Site aparece en la posición de destrucción.
- [ ] **Estado DRIFT**: Si el Dron supera el rango de enlace de red, entra en `DRIFT_MODE` y queda incontrolable.
- [ ] **Firma de audio y luz**: El Dron emite señal audible y visual cuando escanea activamente.
- [ ] **EMP del Dron** (solo para Tech Disruptor — puede implementarse como flag en `drone_base.gd`): requiere línea de visión del operador 1 seg antes de detonación. Radio de área al detonar.

#### Criterio de Done:
> El jugador puede cambiar entre los 3 modos del Dron. En Modo Piloto, el cuerpo del operador permanece inmóvil y puede recibir daño. El Dron puede ser destruido y el Wreck Site aparece en su posición. La batería se drena en Modo Piloto y se recarga en Escolta.

---

### ETAPA 5 — Mapa SANDBOX-01
**Pilar que valida**: Pilar 4 (El terreno decide).
**Dependencias**: Etapas 1, 2, 3 completadas. La Etapa 4 puede estar en paralelo.

#### Tareas:
- [ ] Construir geometría base de SANDBOX-01 en Godot: 3 rutas + 1 sala del Núcleo.
- [ ] Añadir coberturas de 3 alturas: baja, media, alta/mezzanine.
- [ ] Añadir elevación: al menos 1 posición elevada con ventaja de visión sobre el corredor central.
- [ ] Añadir 2 conductos de Dron: solo accesibles en Modo Piloto. El operador no puede entrar.
- [ ] Añadir 3 nodos de recursos en zonas de distinto riesgo.
- [ ] Añadir 1 Punto de Síntesis por equipo en zona de spawn.
- [ ] Verificar que las colisiones son correctas: el Dron en Modo Piloto puede atravesar los conductos pero no las paredes sólidas.

#### Criterio de Done:
> Un jugador puede navegar las 3 rutas del mapa. Puede usar coberturas para reducir daño. Puede enviar su Dron por los conductos en Modo Piloto. La sala del Núcleo tiene 2 entradas navegables.

---

### ETAPA 6 — Núcleo IA: Sistema de Progreso
**Pilar que valida**: Pilar 3 (El objetivo es el Núcleo IA).
**Dependencias**: Etapas 3 y 5 completadas.

#### Tareas:
- [ ] Implementar `nucleus_ai.gd`: barra de progreso de 0% a 100%.
- [ ] Estado **ACTIVO**: la barra avanza si al menos 1 operador atacante está en el perímetro del Núcleo sin presencia defensora.
- [ ] Estado **CONTESTADO**: la barra se congela si hay presencia de ambas facciones en el perímetro.
- [ ] Estado **DEGRADACIÓN**: la barra cae -10%/30 seg si solo la IA defensora tiene presencia en el perímetro. Al superar 50%, cae -5%/30 seg.
- [ ] Alertas al 25%, 50% y 75%: tono audible + pulso de HUD.
- [ ] EM Storm al 50%: reducir el tamaño de las coberturas del perímetro del Núcleo ligeramente.
- [ ] Victoria al 100%: pantalla de victoria, sesión termina.
- [ ] Implementar `nucleus_hud.gd`: barra de hackeo visible para todos los jugadores en todo momento.

#### Criterio de Done:
> La barra del Núcleo avanza, se congela y se degrada correctamente según las condiciones de presencia. Los jugadores ven la barra en su HUD. Al llegar al 100%, aparece la pantalla de victoria.

---

### ETAPA 7 — Recursos Básicos: Wreck Sites y Componentes
**Pilar que valida**: Pilar 2 (El jugador nunca combate solo).
**Dependencias**: Etapas 3 y 4 completadas.

#### Tareas:
- [ ] Implementar `wreck_site.gd`: aparece al destruir un Dron. Emite señal visual (luz pulsante). Se disipa en 90 seg.
- [ ] Implementar recogida de `Componentes de Mantenimiento` al entrar en el radio del Wreck Site.
- [ ] Implementar `resource_inventory.gd`: cada operador tiene un inventario con cap provisional.
- [ ] Implementar Punto de Síntesis: gastar Componentes reduce el tiempo de restauración del Dron destruido.
- [ ] Implementar cosecha remota del Field Engineer: su Dron puede cosechar el Wreck Site sin que el operador se exponga.
- [ ] Al ser incapacitado un operador, suelta el 50% de sus Componentes en el suelo (Wreck de recursos).

#### Criterio de Done:
> Cuando un Dron es destruido, aparece un Wreck Site. El operador puede acercarse y recoger Componentes. El Field Engineer puede cosechar remotamente. Los Componentes en el Punto de Síntesis reducen el tiempo de restauración del Dron.

---

### ETAPA 8 — Los 4 Operadores Prototipo
**Pilar que valida**: Pilar 5 (La cooperación supera al héroe individual).
**Dependencias**: Etapas 1–7 completadas.

#### Tareas:
- [ ] Implementar `operator_recon.gd` extendiendo `operator_base.gd`: cono de escaneo del Dron +50%. Detección de firmas a través de paredes en rango corto.
- [ ] Implementar `operator_vanguard.gd`: resistencia balística +20% base. Micro-barrera frontal del Dron en Modo Escolta (1 seg, cooldown 8 seg).
- [ ] Implementar `operator_disruptor.gd`: Dron puede hackear la puerta del Núcleo (enlace 2 seg). EMP disponible con requisito de línea de visión.
- [ ] Implementar `operator_engineer.gd`: cosecha remota de Wreck Sites. Reparación Dron-a-Dron sobre aliados en `DRONE_LOST`.
- [ ] Verificar que todos los operadores tienen el mismo daño base.
- [ ] Asignar un color visual distinto por operador (placeholder de arte).

#### Criterio de Done:
> Cada operador tiene una capacidad táctica diferenciada y demostrable. Un equipo de 4 operadores distintos puede ejecutar maniobras que un equipo de 4 operadores iguales no puede.

---

### ETAPA 9 — IA Defensora del Núcleo
**Pilar que valida**: Pilar 1 (La información), Pilar 4 (El terreno).
**Dependencias**: Etapas 3, 5 y 6 completadas.

#### Tareas:
- [ ] Implementar patrulla por rutas predefinidas en el mapa.
- [ ] Al detectar un operador o Dron en su cono de visión: estado ALERTA → avanzar y abrir fuego.
- [ ] Al detectar un operador en el perímetro del Núcleo: estado CONTESTING → el Núcleo pasa a Estado CONTESTADO.
- [ ] La IA puede detectar el Dron en Modo Piloto por su firma de audio. Abre fuego sobre él.
- [ ] La IA no tiene comportamiento adaptativo: sus rutas y respuestas son deterministas.
- [ ] Escalar la cantidad de IAs defensoras según el número de jugadores de la sesión (2j → 2 IAs, 4j → 4 IAs).

#### Criterio de Done:
> La IA patrulla. Detecta y ataca operadores. Cuando hay IA en el perímetro del Núcleo, el Estado cambia a CONTESTADO. Un equipo de 4 jugadores necesita coordinar información y drones para superar la IA.

---

## ✅ Criterio de Done Global del Vertical Slice

El VS está listo para el Ciclo 1 de Playtest cuando:

1. Las 9 etapas han pasado sus criterios de Done individuales.
2. Una sesión de 2-4 jugadores puede iniciarse, jugar hasta victoriar al Núcleo (o agotar el tiempo), y terminar sin crash.
3. Los 4 operadores prototipo son funcionales y diferenciados.
4. El Dron puede ser destruido, los Wreck Sites aparecen, y los Componentes se recogen y gastan en el Punto de Síntesis.
5. El mapa SANDBOX-01 es navegable en todas sus rutas y conductos.

---

## 🚫 Restricciones Adicionales de Implementación

- **Sin deuda técnica de arquitectura**: Si un sistema requiere un hack o un workaround para funcionar, documentarlo inmediatamente en `memory/decisions/` y planificar su refactor antes de la siguiente etapa.
- **GDScript tipado estricto siempre**: Ver política en `technical_requirements_preview.md`. Sin excepciones en el VS.
- **Sin optimizaciones prematuras**: Si el VS corre a 30fps en SANDBOX-01, es suficiente. No optimizar hasta después del Ciclo 1 de Playtest.
- **Sin arte que no sea placeholder**: Los operadores son cápsulas de colores. El mapa es geometría gris. El Dron es una esfera. Hasta que el Ciclo 1 de Playtest apruebe las mecánicas, el arte no existe.
