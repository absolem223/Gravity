# IMPLEMENTATION LOG — VERTICAL SLICE

- **Estado**: Activo — Fase 1: Vertical Slice Implementation
- **Ubicación**: `docs/specs/vertical_slice/implementation_log.md`
- **Versión**: 1.4

---

## 📜 REGISTRO DE IMPLEMENTACIÓN POR ETAPA

---

### 🟢 ETAPA 1 — Setup Técnico + Cámara + Movimiento Base

**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

---

### 🟢 ETAPA 2 — Input Cooperativo Local + Identidad de Escuadra

**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

---

### 🟢 ETAPA 3 — Operador Base + Combate Básico + Coberturas + Cono de Visión

**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

---

### 🟢 ETAPA 4 — Dron Gen 1 (Escorta, Estacionario, Piloto)

**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

---

### 🟢 ETAPA 5 — Mapa SANDBOX-01

**Fecha**: 2026-08-02
**Estado**: ✅ COMPLETADA Y VALIDADA

#### 1. Archivos Creados / Modificados
- `game/scenes/sandbox_test_scene.tscn` (Modificado): Reconstruido con la geometría oficial de SANDBOX-01 (rutas izquierda, central y derecha, pasarelas elevadas, rampas, coberturas de 3 niveles y conductos estrechos para drones).
- `docs/specs/vertical_slice/sandbox01_validation_results.md` (Nuevo): Documentación detallada de decisiones de diseño del mapa, riesgos, soluciones y pruebas de navegación.
- `docs/specs/vertical_slice/README.md` (Modificado): Actualizado con la referencia a `sandbox01_validation_results.md`.
- `docs/specs/README.md` (Modificado): Actualizado con la referencia a `sandbox01_validation_results.md`.

#### 2. Decisiones Técnicas Ejecutadas
- **Limitación Física del Operador frente a Conductos**: Diseñado un conducto con dimensiones físicas de 0.8m x 0.8m. Al tener el operador un radio de colisión de 0.4m (ancho 0.8m), la fricción con las paredes le impide pasar de forma natural, mientras que el Dron (radio 0.3m, ancho 0.6m) vuela a través sin restricciones físicas.
- **Rampa Inclinada de Acceso**: La rampa de la plataforma elevada de la ruta derecha cuenta con una inclinación suave para validar que los raycasts de `LineOfSightQuery` sigan calculando correctamente las mitidades de cobertura en desniveles.
- **Ubicación Estratégica de Síntesis**: Posicionados los Puntos de Síntesis en los extremos del mapa central (X=-21, X=21), forzando una decisión de retirada que saca temporalmente al operador del frente.

#### 3. Auditoría contra los 5 Pilares de GRAVITY

| Pilar | Evaluación de la Etapa 5 |
| :--- | :--- |
| **Pilar 1 (Información)** | Las tres rutas (especialmente la central abierta y los recovecos de la izquierda) exigen exploración por Dron antes de cruzar los chokepoints. |
| **Pilar 2 (Nunca solo)** | La pasarela elevada de la Ruta Derecha permite que un aliado cubra a otro que avanza por la peligrosa Ruta Central. |
| **Pilar 3 (El Núcleo)** | La geometría del mapa canaliza todas las rutas hacia la plataforma del Norte Central donde se ubica la base del Núcleo IA. |
| **Pilar 4 (El Terreno decide)** | La elevación otorga ventaja de visibilidad para supresión, y la Ruta Izquierda ofrece cobertura densa a costa de velocidad. |
| **Pilar 5 (Cooperación)** | Un operador aislado en la Ruta Central es fácilmente flanqueado por enemigos en la plataforma elevada de la derecha. |

#### 4. Verificación del Criterio DONE para Etapa 5

| Criterio DONE | Estado | Evidencia |
| :--- | :---: | :--- |
| Tres rutas claramente diferenciadas | ✅ | Ruta Izquierda (cerrada), Central (abierta/peligrosa), Derecha (plataforma elevada + rampa) |
| Coberturas bajas, medias y altas físicas | ✅ | Baja (1m), Media (2m) y Alta (4m) integradas |
| Zonas elevadas con rampas integradas | ✅ | Plataforma a +1.5m con rampa inclinada |
| Conductos funcionales para drones | ✅ | `DroneConduit_Left` de 0.8m de ancho transitable por Drones |
| Cámara y zoom estables en desniveles | ✅ | `CameraController` testeado en dispersión máxima de la escuadra |
| VisionCone3D validado en rampas | ✅ | Escaneo y LoS correctos en desniveles y rampas de la Ruta Derecha |
| Coberturas funcionan correctamente | ✅ | Mitigación del 50% al 100% de daño validada por física 3D |
| Dron funcional en todo el mapa | ✅ | Modos Escorta, Estacionario y Piloto testeados en conductos y pasarelas |
| Ubicación definitiva del Núcleo | ✅ | Plataforma del Norte Central definida |
| Synthesis Points ubicados | ✅ | SynthesisPoint1 y 2 en X=-21 y X=21 |
| Playtests de la etapa documentados | ✅ | Registrado en `sandbox01_validation_results.md` |

---

## ⚠️ ANÁLISIS DE RIESGOS PARA LA ETAPA 6 (Núcleo IA)

1. **Estado Contestado con Cobertura Perimetral**:
   - *Riesgo*: Si el perímetro del Núcleo tiene demasiada cobertura alta, los atacantes podrían esconderse y mantener la barra congelada infinitamente sin combate activo.
   - *Mitigación*: La zona perimetral del Núcleo en `SANDBOX-01` se ha diseñado abierta por los laterales, con cobertura baja (1m) en el centro que mitiga parcialmente pero no bloquea LoS de forma total.

2. **Degradación Visual en HUD**:
   - *Riesgo*: Al entrar en degradación la barra del Núcleo, los jugadores alejados podrían no notar la caída del progreso si el feedback visual de la UI es muy estático.
   - *Mitigación*: Implementar un parpadeo de color en la barra de progreso del HUD del `SquadHUD` cuando el estado pase a `DEGRADATION`.

---

## 🟢 ETAPA 5 COMPLETADA — LISTO PARA ETAPA 6 (Implementación del Núcleo IA)
