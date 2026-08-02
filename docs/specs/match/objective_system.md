# SPEC: OBJECTIVE SYSTEM — SISTEMA DEL NÚCLEO IA Y CONTROL TERRITORIAL

- **Estado**: Propuesto (Fase 0.5 — Game Architecture)
- **Dominio**: Match & Objective
- **Ubicación**: `docs/specs/match/objective_system.md`

---

## 🎯 Filosofía del Objetivo Principal

El **Núcleo IA** es el centro neurálgico y la única razón de existir de cada partida en GRAVITY. 

No es una simple "bandera" estática ni un punto de captura pasivo. El Núcleo IA es una **entidad tecnológica reactiva** que emite datos, altera el entorno electromagnético del mapa y exige la concentración de la escuadra para su control.

---

## 🔄 Las 4 Fases de Captura del Núcleo IA

```
┌─────────────────────────────────────────────────────────────┐
│ FASE 1: RECONOCIMIENTO Y LOCALIZACIÓN                       │
│ - El Núcleo emite firmas electromagnéticas en el mapa.      │
│ - La ubicación exacta debe ser triangulada por los drones.  │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ FASE 2: ENLACE Y DESBLOQUEO DE PUERTOS                      │
│ - Un operador o dron especializado inicia el enlace físico.  │
│ - Se remueven los cortafuegos físicos/lógicos del Núcleo.   │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ FASE 3: TRANSFERENCIA AUTORITATIVA DE DATOS (0% a 100%)    │
│ - Avance continuo de la barra de descarga de la escuadra.    │
│ - Requiere presencia y control del perímetro (Control Zone).│
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│ FASE 4: SOBRECARGA Y ESTABILIZACIÓN FINAL                   │
│ - Consolidación del control del Núcleo.                     │
│ - Cierre de la ronda y otorgamiento del punto decisivo.     │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏔️ Mecánica de Control Territorial

El control del Núcleo no se mide por quién se paró encima de una plataforma fija. Se mide por el **Perímetro de Dominio de Escuadra**:

1. **Zona del Perímetro**: Cada Núcleo posee un área circular/geométrica que lo rodea (Radio de Enlace).
2. **Dominio de Red**: Si la escuadra Atacante tiene más presencia de operadores/drones activos en la zona que la escuadra Defensora, el enlace de descarga avanza.
3. **Interrupción por Enlace Contestado**: Si ambas escuadras tienen igual número de operadores/drones dentro del perímetro, el progreso se pausa (*Contested State*) y la tensión se dispara.

---

## ⚡ Generación de Tensión Dinámica durante la Partida

Para evitar partidas estáticas o aburridas, el Sistema de Objetivo introduce 3 catalizadores de tensión:

### 1. Colapso del Cono de Visión (EM Storm Event)
A medida que la descarga del Núcleo supera el 50%, el Núcleo emite pulsos electromagnéticos que reducen la visibilidad lejana, forzando a los francotiradores y exploradores a acercarse al perímetro.

### 2. Alerta Sonora y Térmica Progresiva
Con cada 25% de datos descargados, el Núcleo incrementa su tono de sirena y cambia de color, alertando a la escuadra enemiga sobre la urgencia imminente de un contraataque.

### 3. Protocolo de Sobrecarga (Overtime / Sudden Death)
Si el tiempo de ronda finaliza pero un equipo mantiene un enlace de descarga activo al Núcleo en estado no contestado, la partida entra en **Overtime** hasta que la escuadra contraria rompa el enlace o el Núcleo complete su ciclo.

---

## ⚖️ Auditoría contra los 5 Pilares de Diseño

1. **Pilar 1 (La información es el recurso más valioso)**: Cumplido. La ubicación del Núcleo y el porcentaje de descarga enemiga son la información crítica de la partida.
2. **Pilar 2 (El jugador nunca combate solo)**: Cumplido. Mantener la zona del Núcleo exige cubrir múltiples entradas de forma simultánea.
3. **Pilar 3 (El objetivo es controlar el núcleo, no eliminar enemigos)**: Cumplido. Un equipo puede perder a 3 jugadores, pero si el último jugador mantiene el enlace y completa el 100%, gana la partida.
4. **Pilar 4 (El terreno decide la batalla)**: Cumplido. El perímetro alrededor del Núcleo contiene paredes hackeables, coberturas y conductos de drones.
5. **Pilar 5 (La cooperación supera al héroe individual)**: Cumplido. Interrumpir un Núcleo contestado requiere asaltar el perímetro en coordinación de escuadra.
