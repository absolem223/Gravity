# SPEC: COMBAT SYSTEM — ARQUITECTURA DEL SISTEMA DE COMBATE TÁCTICO

- **Estado**: Propuesto (Fase 0.5 — Game Architecture)
- **Dominio**: Combat
- **Ubicación**: `docs/specs/combat/combat_system.md`

---

## 🎯 Filosofía del Combate en GRAVITY

En la mayoría de los shooters multijugador, el combate se reduce a reflejos de milisegundos (*twitch reflex*) y precisión de puntería individual (*headshot clicker*).

**En GRAVITY, el combate es una ecuación de 5 variables**:

$$\text{Efectividad de Combate} = \text{Información} + \text{Posicionamiento} + \text{Estado del Dron} + \text{Hackeo} + \text{Puntería}$$

Si un equipo posee 0% de información sobre la posición enemiga, incluso el jugador con la mejor puntería del mundo estará en clara desventaja funcional.

---

## ⚔️ La Interacción de las 5 Variables de Combate

```
┌─────────────────────────────────────────────────────────────┐
│                      INFORMACIÓN PREVIA                     │
│      (Dron detecta firma térmica / Niebla despejada)       │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│                    CONTROL DE POSICIÓN                      │
│      (Flanqueo, Altura, Cobertura Superior)                │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│                 INTERRUPCIÓN Y HACKEO                       │
│      (Dron EMP ciega visor o inhabilita cobertura)          │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│                  EJECUCIÓN CINÉTICA (Arma)                  │
│      (Supresión de fuego, daño coordinado de escuadra)       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛡️ Mecánicas Principales de Combate Táctico

### 1. Sistema de Supresión por Fuego (Fuerza de Detención)
- Cuando las balas pasan cerca de un operador, su visor de exoesqueleto experimenta interferencia visual y se distorsiona su cono de visión.
- La supresión impide que un jugador sorprendido en una mala posición pueda simplemente "darse la vuelta y hacer un headshot de 180 grados".

### 2. Cobertura Dinámica y Destrucción Funcional
- Las coberturas del mapa atenúan o bloquean el daño balístico.
- El fuego sostenido o las granadas tácticas pueden destruir coberturas ligeras, alterando la topología del enfrentamiento durante la partida.

### 3. Fuego Asistido por Dron (Smart Vectoring)
- Si un dron tiene marcada la posición de un enemigo detrás de una cobertura sutil, la retícula del operador recibe asistencia de trayectoria (*vectoring*), reduciendo la penalización de fuego a ciegas.

### 4. Interrupción Hack-to-Shoot
- Los operadores pueden hackear los visores o armas de los enemigos mediante sus drones si logran un enlace de red sostenido de 1.5 segundos.
- Un enemigo hackeado sufre de bloqueo de armas o desalineación de miras tácticas, convirtiéndolo en un objetivo fácil para la escuadra.

---

## 🚫 Cómo Evitar el "Twitch Shooter"

Para garantizar que GRAVITY mantenga su identidad táctica y no se degenere en un shooter de velocidad desenfrenada:
1. **Tiempo para Matar (TTK - Time to Kill) Medio/Alto en Combate Frontal**: Disparar a un enemigo cubierto de frente sin asistencia de información requiere mucho tiempo para romper su exoesqueleto.
2. **TTK Extremadamente Bajo en Emboscadas Coordinadas**: Si un enemigo es flanqueado por dos operadores con información de dron previa, caerá casi de inmediato.
3. **Penalización por Movimiento Errático**: Saltar repetidamente (*bunny hopping*) o agacharse frenéticamente (*crouch spamming*) incrementa drásticamente la dispersión de armas y agota la energía del exoesqueleto.

---

## ⚖️ Auditoría contra los 5 Pilares de Diseño

1. **Pilar 1 (La información es el recurso más valioso)**: Cumplido. Disparar sin información genera alta dispersión y revela la posición propia en el radar enemigo.
2. **Pilar 2 (El jugador nunca combate solo)**: Cumplido. La supresión y el fuego cruzado requieren que dos operadores coordinen sus ángulos.
3. **Pilar 3 (El objetivo es controlar el núcleo, no eliminar enemigos)**: Cumplido. El combate se utiliza para expulsar al enemigo de las zonas de cobertura que rodean al Núcleo IA.
4. **Pilar 4 (El terreno decide la batalla)**: Cumplido. El uso de la cobertura y la altura determina quién aplica supresión efectiva.
5. **Pilar 5 (La cooperación supera al héroe individual)**: Cumplido. Un único jugador no puede superar la combinación de supresión de un operador y hackeo de un dron aliado.
