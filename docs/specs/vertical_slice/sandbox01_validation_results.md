# SANDBOX-01 VALIDATION RESULTS — RESULTADOS DE VALIDACIÓN DEL MAPA SANDBOX-01

- **Estado**: Activo — Fase 1: Vertical Slice Implementation (Etapa 5)
- **Ubicación**: `docs/specs/vertical_slice/sandbox01_validation_results.md`
- **Versión**: 1.0

---

## 🎯 1. Decisiones de Diseño

El diseño de `SANDBOX-01` (`sandbox_test_scene.tscn`) fue implementado con el fin de validar el gameplay táctico, la lectura espacial, la conmutación de targets en Modo Piloto, y las coberturas físicas en desniveles y rampas.

### Estructura de las Tres Rutas
1. **Ruta Izquierda (Oeste) — Cobertura y Avance Lento**:
   - Geometría cerrada por muros altos de 4 metros (`RouteLeft_Wall1`).
   - Contiene bloques de cobertura baja (1m) y media (2m).
   - Diseñada para un avance metódico, propenso a emboscadas pero seguro contra fuego lejano.
2. **Ruta Central — Abierta y de Alto Riesgo**:
   - Espacio amplio y despejado sin paredes divisorias.
   - Escasas coberturas bajas dispersas (`Center_LowCover1` y `Center_LowCover2`).
   - Ruta más rápida hacia el Núcleo, pero expuesta a la línea de visión directa de los tres flancos.
3. **Ruta Derecha (Este) — Elevada y Táctica**:
   - Incluye una plataforma elevada a +1.5m (`RouteRight_ElevatedPlatform`) y una rampa de acceso (`RouteRight_Ramp`).
   - Ofrece una línea de visión dominante sobre la ruta central (balcón/mezzanine).
   - Su exposición es alta frente a fuego coordinado desde la zona baja.

### Integración de Coberturas Físicas
- **Baja (1.0m)**: `RouteLeft_LowCover`, `Center_LowCover1/2`. Bloquea los pies pero deja el pecho visible → **50% daño mitigado**.
- **Media (2.0m)**: `RouteLeft_MedCover`, `CorePlaceholder`. Bloquea visión y disparos completamente → **100% daño bloqueado**.
- **Alta (4.0m)**: `SpawnProtectionWall`, `RouteLeft_Wall1`. Bloquea LoS y movilidad a gran escala.

### Conductos de Drones (Drone Conduits)
- Ubicados en los muros divisorios de la ruta izquierda (`DroneConduit_Left`).
- Dimensiones físicas del hueco: ancho de 0.8m, altura de 0.8m.
- **Validación física**: El operador (radio de colisión 0.4m, ancho 0.8m) no puede atravesarlo debido al margen de fricción, mientras que el Dron (radio 0.3m, ancho 0.6m) lo atraviesa con total holgura en Modo Piloto.

### Posición Definitiva del Núcleo IA
- Plataforma a la altura del Norte Central del mapa.
- Perímetro delimitado por la plataforma (`CorePlatform` a +0.5m) con un chokepoint protegido por la geometría circundante.

### Synthesis Points (Puntos de Síntesis)
- Reubicados en los flancos de la zona intermedia (`SynthesisPoint1` y `SynthesisPoint2` a X=-21 y X=21 respectivamente).
- Fuerza al jugador sin Dron a retroceder lateralmente, saliendo de las rutas de avance directo, exponiéndose a posibles flanqueos.

---

## 🧪 2. Pruebas Realizadas y Resultados

### Prueba 1: Navegación del Dron en Conductos y Esquinas ✅ PASÓ
- **Detalle**: El Dron en Modo Piloto vuela a través de `DroneConduit_Left` de forma fluida. No se observaron atascos ni colisiones inestables en las esquinas de los muros de 4m.

### Prueba 2: LoS y Mitigación de Cobertura en Rampas y Plataformas ✅ PASÓ
- **Detalle**: `LineOfSightQuery` fue probado con un operador situado en la plataforma elevada de la Ruta Derecha disparando a un objetivo situado en la rampa inclinada.
- **Resultado**: Los raycasts calculan las posiciones de pies y pecho de forma correcta sin verse alterados por la inclinación local de la rampa o la altura de la pasarela.

### Prueba 3: Estabilidad de la Cámara Isométrica (CameraController) ✅ PASÓ
- **Detalle**: Cuatro operadores se dispersaron entre la Ruta Izquierda (Oeste) y la pasarela de la Ruta Derecha (Este).
- **Resultado**: La cámara ajustó su zoom suavemente hasta su límite máximo (`max_zoom = 28m`) manteniendo a toda la escuadra encuadrada. Al pilotar un Dron en los conductos, la cámara lerpeó hacia el Dron sin saltos bruscos.

---

## ⚠️ 3. Riesgos Encontrados y Soluciones

1. **Riesgo**: La cámara a 65° podría verse obstruida visualmente por los muros altos (4m) de la Ruta Izquierda, ocultando a los operadores.
   - **Solución**: La rotación fija de la cámara permite ver el corredor de la Ruta Izquierda de forma longitudinal. Además, las insignias 3D de escuadra (`no_depth_test = true`) garantizan la legibilidad de la posición aliada a través de las paredes altas.

2. **Riesgo**: Los operadores intentando saltar o trepar sobre coberturas bajas de 1m.
   - **Solución**: El movimiento en el VS está restringido a XZ en superficie (`CharacterBody3D` con gravedad normal). Las coberturas bajas se navegan rodeándolas físicamente, lo cual simplifica la lógica y previene comportamientos arcade.
