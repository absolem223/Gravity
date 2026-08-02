# SPEC VALIDATION: MATCH FLOW SPEC — REVISIÓN 4.0

- **Estado**: Actualizado / Revisión 4.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/match_flow_spec.md`

---

## 🎯 Estructura Emocional de la Partida

Una partida completa de GRAVITY dura entre **35 y 45 minutos**, estructurada en tres arcos emocionales que se corresponden con las tres Generaciones Tecnológicas.

```
ARCO 1 (Gen 1)      ARCO 2 (Gen 2)        ARCO 3 (Gen 3)
─────────────────   ──────────────────     ──────────────────
Incertidumbre       Especialización        Dominio Tecnológico
Reconocimiento      Fricción Territorial   Operación Crítica
Preparación         Choque de Doctrinas    Clímax y Resolución
[0:00 - 15:00]      [15:00 - 30:00]        [30:00 - 45:00+]
```

---

## 🔄 Flujo Cronológico Detallado

### [ 0:00 - 5:00 ] DESPLIEGUE Y NIEBLA INICIAL
- Ambas escuadras despliegan sus drones en Modo Escolta o Piloto para limpiar la Niebla de Guerra y triangular la firma del Núcleo IA.
- Los primeros jugadores se cruzan en los nodos tecnológicos ligeros de la zona media.
- **Sensación**: Sigilo tenso. El silencio del mapa pesa.

### [ 5:00 - 10:00 ] PRIMER CONTACTO Y DISPUTAS DE RECURSOS
- Las escuadras se encuentran disputando los primeros Nodos Tecnológicos y Wreck Sites.
- Los Drones comienzan a ser enviados en Modo Piloto para escanear los flancos del mapa.
- Primeros intercambios de fuego sobre coberturas en los chokepoints de acceso medio.
- **Sensación**: Adrenalina del primer contacto. Errores costosos de posicionamiento.

### [ 10:00 - 15:00 ] ESTABLECIMIENTO DE LÍNEAS Y ACUMULACIÓN
- Las escuadras consolidan sus rutas de cosecha y establecen posiciones defensivas en las líneas medias.
- Cada operador acumula *Recursos de Evolución* para el salto a Gen 2.
- **Anti-Camping**: Los Nodos del mapa emiten pulsos de escaneo periódicos a partir del minuto 5, forzando movimiento de los equipos pasivos.

### [ 15:00 - 20:00 ] SALTO A GEN 2 — ESPECIALIZACIÓN TECNOLÓGICA
- Los primeros jugadores canalizan su Doctrina en los Centros de Integración de los flancos.
- La canalización emite una **firma de energía visible en el mapa**, alertando al equipo rival y abriendo una ventana crítica de interrupción.
- Los Drones adoptan sus perfiles especializados: el mapa se vuelve más complejo e informado.
- **Sensación**: La partida "cambia de estado". La composición de la escuadra cristaliza su identidad.

### [ 20:00 - 30:00 ] FRICCIÓN DE DOCTRINAS Y PRIMER HACKEO
- Las escuadras especializadas se enfrentan en el sector medio del mapa con capacidades aumentadas.
- Se producen los primeros intentos de hackeo del Núcleo IA, interrumpidos por la escuadra contraria.
- Los Drones de Reconocimiento revelan posiciones para que el Overwatch aplique supresión coordinada.
- **Sensación**: Las decisiones de Doctrina se sienten. La información domina los enfrentamientos.

### [ 30:00 - 35:00 ] SALTO A GEN 3 — EVOLUCIÓN AVANZADA
- Los primeros jugadores canalizan en la Estación de Gen 3 (ubicada en zona de alto riesgo, cerca del Núcleo).
- Los **Efectos de Red** se activan pasivamente: el mapa táctico de la escuadra se completa y la coordinación alcanza su pico.
- La presión sobre el Núcleo IA escala dramáticamente.
- **Sensación**: Dominio tecnológico. La partida se aproxima a su resolución.

### [ 35:00 - 45:00+ ] OPERACIÓN FINAL DEL NÚCLEO IA
- La escuadra con mayor dominio tecnológico y territorial intenta completar la descarga del 100% del Núcleo IA.
- Los eventos de *EM Storm* del Núcleo reducen visibilidad lejana, forzando el combate cerrado.
- Si la barra alcanza el 99% y el equipo rival irrumpe en el perímetro: **Overtime / Estado Contestado**.
- **Sensación**: Tensión máxima. Cada segundo del Overtime es determinante.

---

## 🛑 Mecanismos Anti-Problemas del Pacing

### Prevención de Fase Lenta (Gen 1 pasiva):
- Nodos de recursos emiten pulsos de escaneo periódicos desde el min 5 → fuerza movimiento.
- La Niebla de Guerra en zonas sin explorar densa no es permanente: se disipa parcialmente a los 8 minutos en sectores centrales.

### Prevención de Snowball por Gen 2 Anticipada:
- La canalización en el Centro de Integración de Gen 2 emite firma visible al rival.
- El equipo retrasado recibe un **bono de daño por flanqueo** a objetivos en proceso de canalización.

### Prevención de Gen 3 como Victoria Automática:
- Gen 3 otorga *Efectos de Red* (información y soporte), NO mayor daño bruto.
- Un equipo de Gen 1 con coordinación perfecta y posicionamiento superior derrota a jugadores Gen 3 dispersos.
- La cobertura, la geometría del mapa y la supresión coordinada funcionan igual para todas las Generaciones.

### Prevención de Partidas Muy Largas (>45 min):
- A los 40 minutos sin resolución, el Núcleo IA activa una **Onda de Pulso Continua**: reduce la cobertura disponible en el perímetro y fuerza el asalto final.
