# SPATIAL COOPERATION TEST RESULTS — RESULTADOS DEL TEST DE COOPERACIÓN ESPACIAL

- **Estado**: Activo — Fase 1: Vertical Slice Implementation (Etapa 3)
- **Ubicación**: `docs/specs/vertical_slice/spatial_coop_test_results.md`
- **Versión**: 1.0

---

## 🎯 Configuración del Test Espacial

| Parámetro | Condición del Test |
| :--- | :--- |
| **Operadores** | 4 Operadores (P1 Recon, P2 Vanguard, P3 Disruptor, P4 Engineer) |
| **Mapa** | `SANDBOX-01` (`sandbox_test_scene.tscn`) |
| **Entidades externas** | Sin IA defensora, sin Drones, sin Núcleo IA activo |
| **Enfoque** | Validar la lectura espacial, la fluidez del movimiento en grupo, el uso natural de coberturas y la legibilidad de cámara |

---

## 📊 RESULTADOS POR EVALUACIÓN ESPACIAL

### 1. Lectura Clara de Posiciones ✅ APROBADO
- **Observación**: Las insignias `Label3D` sobre cada operador con `no_depth_test = true` permiten saber exactamente dónde está cada compañero a través de muros y coberturas.
- **Resultado**: Cero confusión entre los slots P1, P2, P3 y P4. El color identificador y el rol en texto son legibles desde el ángulo isométrico de 65°.

### 2. Facilidad para Reagruparse ✅ APROBADO
- **Observación**: Cuando un operador supera la distancia de 12m del centroide de la escuadra, la alerta `[SEPARATED]` en naranja advertencia y la actualización de distancia en el HUD generan una reacción inmediata para converger.
- **Resultado**: Los jugadores se reagrupan sin que el sistema bloquee artificialmente su desplazamiento. La velocidad de locomoción (6.5 m/s) permite maniobras de convergencia ágiles.

### 3. Comportamiento Natural alrededor de Coberturas ✅ APROBADO
- **Observación**: La comprobación de cobertura vía `LineOfSightQuery.check_cover_protection` evalúa si los pies o el pecho del objetivo están bloqueados por geometría 3D.
- **Resultado**:
  - **Muro bajo (`LowCoverWall`, 1.0m)**: Si el operador está agachado o detrás del muro, los pies quedan bloqueados por la física del raycast mientras el pecho permanece visible → **50% de daño mitigado**.
  - **Bloque medio (`MediumCoverBlock`, 2.5m)**: Si el operador se posiciona detrás del bloque completo, ambos raycasts (pecho y pies) son bloqueados → **100% de daño bloqueado**.
  - **Comportamiento**: No requiere mecánicas de "pegarse a la pared" ni botones extras. Estar físicamente detrás de una cobertura otorga la protección directamente.

### 4. Legibilidad de la Cámara durante Desplazamientos ✅ APROBADO
- **Observación**: El controlador `CameraController` interpola el centroide del grupo y expande el offset Z dinámicamente (`min_zoom = 12m`, `max_zoom = 28m`).
- **Resultado**: Durante desplazamientos rápidos por las 3 rutas del mapa, la cámara no presenta tirones ni giros bruscos. La orientación Top-Down a 65° preserva la visibilidad de la elevación (mezzanine) y las tres coberturas principales.

---

## ⚖️ CONCLUSIÓN DEL TEST ESPACIAL

El test demuestra que **el combate en GRAVITY es una consecuencia natural de la información y la geometría del terreno**. Estar en cobertura baja otorga una ventaja defensiva medible (-50% daño) sin entorpecer el ritmo de juego ni recurrir a mecánicas arcade.
