# SPEC VALIDATION: DRONE RESOURCE ECONOMY — ECONOMÍA DE PIEZAS Y CONTROL TERRITORIAL

- **Estado**: Aprobado (Fase 0.5 — Validación y Profundización)
- **Ubicación**: `docs/specs/validation/drone_resource_economy.md`

---

## 🎯 Objetivo del Sistema Económico

La **Economía de Piezas y Componentes** en GRAVITY tiene como propósito vincular la recuperación de drones y la progresión dentro de la partida al **control del terreno**, evitando que el juego se convierta en un simple *farm de eliminaciones* (*Kill Farming*).

---

## ⚙️ 1. Mecánica de Obtención de Componentes

Los Componentes Tecnológicos (Scrap/Parts) no provienen únicamente de jugadores enemigos eliminados. Provienen primariamente de la infraestructura del mapa y del conflicto:

```
┌─────────────────────────────────────────────────────────────┐
│                 FUENTES DE COMPONENTES                      │
├──────────────────────────────┬──────────────────────────────┤
│ 1. Infraestructura de Mapa   │ 2. Restos de Conflicto        │
│ - Nodos de red abandonados   │ - Drones destruidos          │
│ - Torretas/Cámaras hackeadas │ - Coberturas electrónicas    │
│ - Terminales secundarias     │   destruidas en combate      │
└──────────────────────────────┴──────────────────────────────┘
```

### Prevención del "Kill Farming":
- Destruir a un operador enemigo otorga una cantidad MÍNIMA de piezas.
- La mayor fuente de componentes se encuentra en los **Nodos Tecnológicos del Mapa** (ubicados en zonas de riesgo medio y en la periferia del Núcleo IA).
- Esto obliga a las escuadras a expandirse y controlar sectores del mapa en lugar de acampar en un pasillo buscando bajas.

---

## 🛡️ 2. Recompensa al Control Territorial

- **Nodos de Extracción Progresiva**: Controlar una sala secundaria con un Nodo Tecnológico otorga piezas de forma pasiva a la escuadra a lo largo del tiempo.
- **Acceso a Tecnología Abandonada**: Las zonas más alejadas de las rutas principales contienen suministros tecnológicos antiguos. Enviar un dron a explorarlas recompensa a la escuadra con componentes de alta calidad sin necesidad de disparar una sola bala.

---

## 🛑 3. Anti-Snowballing: Prevención de Acumulación Desmedida

Para evitar que el equipo que toma la delantera acapare todas las piezas y vuelva imbatibles a sus drones (*Snowball Effect*):

1. **Límite Estricto de Almacenamiento (Inventory Cap)**: Cada operador solo puede cargar hasta 100 unidades de componentes. Las piezas sobrantes se vuelven inestables y se descartan automáticamente.
2. **Rendimientos Decrecientes en Mejoras (Diminishing Returns)**: Reparar un dron cuesta un monto fijo. Mejorarlo al Nivel 2 cuesta el doble; al Nivel 3 cuesta el cuádruple. La inversión en mejoras avanzadas ofrece incrementos marginales de beneficio.
3. **Pérdida por Incapacitación**: Si un operador muere mientras transporta componentes no procesados, suelta el 50% de esas piezas en el lugar de su caída, permitiendo al equipo perdedor recuperar terreno económico mediante una emboscada táctica.

---

## 🧠 4. Decisiones Significativas de Gasto

Los componentes no son "dinero arbitrario". Representan decisiones de adaptación táctica en tiempo real:

- **Opción A: Reparación Básica Inmediata** (Gasto bajo): Devuelve el dron a su estado funcional básico para recuperar visión rápidamente.
- **Opción B: Mejora Módulo Especializado** (Gasto medio): Conserva el dron actual pero le añade resistencia EMP o mayor radio de sonar.
- **Opción C: Sintetizar Variante Alternativa** (Gasto alto): Cambia el dron de un perfil de Reconocimiento a un perfil de Defensa Electrónica para adaptarse a la fase final de defensa del Núcleo IA.
