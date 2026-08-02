# SPEC VALIDATION: TECHNICAL REQUIREMENTS PREVIEW — REQUISITOS TÉCNICOS FUTUROS

- **Estado**: Aprobado (Fase 0.5 — Validación y Profundización)
- **Ubicación**: `docs/specs/validation/technical_requirements_preview.md`

---

## 📌 Propósito

Este documento establece un **vista previa funcional de los subsistemas técnicos** que la ingeniería de software deberá construir en fases posteriores (Fase 1 en adelante).

**Nota de Inviolabilidad**: Este documento NO define clases, código, patrones ni esquemas de software aún. Su objetivo es listar los *módulos de responsabilidad funcional* necesarios para dar servicio al diseño de juego de GRAVITY.

---

## 📋 Lista de Subsistemas Requeridos a Futuro

### 1. Sistema de Visión y Niebla de Guerra (Vision & Fog System)
- **Responsabilidad**: Calcular la Línea de Visión (Line of Sight) 2D/3D en tiempo real, generar el sombreado de Niebla de Guerra y gestionar la triangulación de firmas electromagnéticas.

### 2. Sistema de Drones de Asistencia (Drone Subsystem)
- **Responsabilidad**: Gestionar el estado del Dron (Escolta, Estacionario, Piloto Directo), la autonomía de batería, el rango de enlace de red con el operador y las entradas a conductos pequeños del mapa.

### 3. Sistema de Operadores y Exoesqueletos (Operator Subsystem)
- **Responsabilidad**: Controlar la física de locomoción, inercia, supresión de fuego, absorción de impacto del exoesqueleto y la reserva energética compartida con el dron.

### 4. Sistema de Hackeo e Interacción (Hack & Interaction System)
- **Responsabilidad**: Manejar las secuencias de canalización de hackeo sobre terminales, puertas, visores enemigos y la transferencia autoritativa de datos del Núcleo IA.

### 5. Sistema de Mapas y Entorno Interactivo (Map & Environment System)
- **Responsabilidad**: Administrar las 3 capas de movilidad (operador, flanqueo, conductos de dron), el estado de destructibilidad de coberturas y el cálculo del Perímetro de Control del Núcleo.

### 6. Sistema Multijugador Autoritativo (Multiplayer & Netcode System)
- **Responsabilidad**: Ejecutar la simulación autoritativa del servidor, la predicción de cliente con reconciliación y la filtración de red por relevancia de información (*Interest Management / Anti-Wallhack*).

### 7. Sistema de Composición de Escuadra (Squad & Role System)
- **Responsabilidad**: Validar la combinación de módulos de los 4 operadores de la escuadra y gestionar el bus de eventos de información compartida en tiempo real.

---

## ⚖️ Recordatorio Fundacional de Ingeniería

> **"GRAVITY no debe convertirse en un shooter con habilidades. Debe ser un juego táctico donde la información, el posicionamiento y la coordinación sean las principales armas."**
