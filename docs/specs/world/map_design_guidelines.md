# SPEC: MAP DESIGN GUIDELINES — PRINCIPIOS DE DISEÑO DE MAPAS

- **Estado**: Propuesto (Fase 0.5 — Game Architecture)
- **Dominio**: World & Environment
- **Ubicación**: `docs/specs/world/map_design_guidelines.md`

---

## 🎯 Filosofía del Espacio en GRAVITY

En GRAVITY, el mapa no es una simple "escenografía visual" ni una arena abierta. 

**El mapa es un tablero táctico tridimensional**. La geometría, la elevación, las líneas de visión y la arquitectura del nivel son los factores principales que determinan qué equipo logra dominar la información y el combate.

---

## 📐 Los 5 Principios del Diseño de Niveles

```
┌─────────────────────────────────────────────────────────────┐
│ 1. TRES RUTAS PRINCIPALES CON CONEXIONES TRANSVERSALES      │
│    (Ruta Izquierda, Centro/Núcleo, Ruta Derecha + Conductos)│
├─────────────────────────────────────────────────────────────┤
│ 2. CONTROL ESTRICTO DE LÍNEAS DE VISIÓN (LoS)               │
│    (Cero líneas de visión infinitas de spawn a spawn)       │
├─────────────────────────────────────────────────────────────┤
│ 3. DUPLICIDAD DE ACCESOS (Humano vs Dron)                   │
│    (Conductos ventilados para Drones, puertas para Ops)     │
├─────────────────────────────────────────────────────────────┤
│ 4. ZONAS DE CONTROL ASIMÉTRICAS                             │
│    (Ventajas de elevación balancedas por vulnerabilidad EMP)│
├─────────────────────────────────────────────────────────────┤
│ 5. ENTORNO INTERACTIVO Y RECONFIGURABLE                     │
│    (Puertas hackeables, paredes destruibles, luz/niebla)   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛤️ 1. Rutas Alternativas y Conductos de Drones

Cada mapa de GRAVITY debe incorporar **tres capas de movilidad**:

1. **Capa Primaria (Pasillos de Operadores)**: Corredores principales diseñados para el avance de la escuadra utilizando coberturas intermedias.
2. **Capa Secundaria (Rutas de Flanqueo)**: Flancos de riesgo moderado que permiten el acceso por la espalda de las posiciones defensivas.
3. **Capa Terciaria (Conductos de Drones)**: Pequeñas aperturas, tuberías y ductos en techos/paredes transitables **exclusivamente por drones en modo piloto o autónomo**. Esto permite que los drones se infiltren en salas cerradas sin exponer al cuerpo del operador.

---

## 👁️ 2. Líneas de Visión (Line of Sight) y Oclusión

- **Prohibición de Sniping Abierto Ilimitado**: No existirán pasillos rectos de más de 30 metros sin elementos de oclusión visual (columnas, esquinas de 45 grados, paneles).
- **Esquinas Tácticas (L-Corners & T-Junctions)**: Las intersecciones de mapas están diseñadas para forzar el uso del cono de visión del Dron antes de doblar a ciegas.
- **Niebla de Guerra Estructural**: Las áreas no exploradas por la escuadra están oscurecidas en el minimapa y en el campo visual térmico.

---

## ⛰️ 3. La Importancia del Terreno y Elevación

- **Ventaja de Altura (High Ground)**: Mantener la posición elevada otorga mejor ángulo de tiro y mayor cobertura física, pero expone la firma electromagnética del equipo a la detección lejana de los drones enemigos.
- **Puntos de Estrangulamiento (Chokepoints)**: Áreas de paso obligatorio hacia la sala del Núcleo que requieren el uso combinado de humo térmico, supresión y drones de brecha para poder atravesarse.
- **Cobertura Hackeable/Destruible**: Ciertas barreras metálicas pueden ser cerradas o abiertas mediante hackeo de terminales locales, cambiando la topología de la sala en medio de la batalla.

---

## ⚖️ Auditoría contra los 5 Pilares de Diseño

1. **Pilar 1 (La información es el recurso más valioso)**: Cumplido. La geometría del mapa bloquea la visión directa, obligando al uso de drones para mapear el terreno.
2. **Pilar 2 (El jugador nunca combate solo)**: Cumplido. Los chokepoints requieren fuego de supresión conjunto para ser cruzados con seguridad.
3. **Pilar 3 (El objetivo es controlar el núcleo, no eliminar enemigos)**: Cumplido. Toda la arquitectura del mapa converge naturalmente hacia la sala central del Núcleo IA.
4. **Pilar 4 (El terreno decide la batalla)**: Cumplido. El mapa dicta el resultado mediante elevación, coberturas interactivas y conductos.
5. **Pilar 5 (La cooperación supera al héroe individual)**: Cumplido. Un jugador solitario que intenta avanzar por una línea abierta es suprimido y eliminado rápidamente por la geometría defensiva.
