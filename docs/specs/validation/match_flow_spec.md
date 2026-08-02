# SPEC VALIDATION: MATCH FLOW SPEC — FLUJO Y RITMO DE PARTIDA

- **Estado**: Aprobado (Fase 0.5 — Validación y Profundización)
- **Ubicación**: `docs/specs/validation/match_flow_spec.md`

---

## 🎯 Control del Ritmo Táctico (Pacing)

Una partida de GRAVITY dura entre **8 a 12 minutos** estructurada en 5 etapas continuas.

El diseño del flujo debe prevenir dos extremos indeseables:
1. **Partidas Lentas / Pasivas**: Que los equipos se escondan en esquinas sin avanzar (*camping estático*).
2. **Snowballing / Aplastamiento Rápido**: Que el equipo que toma la primera baja aplaste de forma imparable al rival en 30 segundos.

---

## 🔄 Flujo Detallado de una Partida Completa

```
[ 0:00 - 1:30 ] INICIO & FASE DE RASTREO
                - Drones mapean Niebla de Guerra.
                - Triangulación del Núcleo IA.
                      │
                      ▼
[ 1:30 - 3:30 ] PRIMER CONTACTO Y CHOKEPOINTS
                - Batalla por zonas elevadas y accesos.
                - Intercambio de supresión y recursos.
                      │
                      ▼
[ 3:30 - 6:30 ] ESCALADA Y PRIMER INTENTO DE HACKEO
                - Inserción en la sala del Núcleo.
                - Inicio de descarga de datos.
                      │
                      ▼
[ 6:30 - 9:00 ] DEFENSA / CONTRAATAQUE DESESPERADO
                - Evento de Tormenta EM del Núcleo.
                - Enlace en estado Contestado.
                      │
                      ▼
[ 9:00 +     ] RESOLUCIÓN O OVERTIME
                - Consolidación del 100% o denegación de tiempo.
```

---

## 🛑 Mecanismos para Evitar Partidas Lentas (Anti-Camping)

1. **Degradación de Batería de Dron en Reposo**: Si un dron permanece 45 segundos inmóvil en el mismo lugar, su batería se agota el doble de rápido, forzando al operador a mover la posición.
2. **Pulsos de Rastreo del Núcleo IA**: Si a los 3 minutos de partida ningún equipo ha ingresado al sector medio, el Núcleo emite un pulso electromagnético que revela temporalmente el mapa a ambas escuadras, rompiendo la pasividad.
3. **Economía de Recursos Limitada**: Las cargas de escudo y granadas térmicas no se regeneran solas; acampar en la base consume el tiempo de partida sin generar ventaja territorial.

---

## 🛡️ Mecanismos Anti-Snowball / Anti-Stomp (Recuperación Táctica)

1. **Ventaja Defensiva de Posición**: El equipo que pierde un operador obtiene mayor ancho de banda de red en sus drones restantes, permitiendo recargar sensores de información un 15% más rápido.
2. **Protocolo de Enlace Contestado**: Si un equipo dominante intenta acelerar la victoria sin asegurar los flancos, un solo operador enemigo agazapado en el perímetro del Núcleo puede congelar el progreso del 99% al instante.
3. **Sin Acumulación de Armamento Permanente**: En GRAVITY no existen "compras de armas entre rondas" que dejen al equipo perdedor en desventaja económica. Todos los operadores ingresan a cada ronda con su equipamiento completo.

---

## ⚡ Mantención de la Tensión Creciente

- **Feedback Progresivo del Núcleo**: Con cada 25% de datos descargados, el Núcleo incrementa su intensidad visual y sonora, alertando a toda la arena.
- **Reducción de Coberturas Seguras**: Las coberturas cercanas al Núcleo se van deteriorando bajo fuego, obligando a los jugadores a reubicarse constantemente.
