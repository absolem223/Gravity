# SPEC VALIDATION: DESIGN VALIDATION — REVISIÓN 4.0

- **Estado**: Actualizado / Revisión 4.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/design_validation.md`

---

## 🎯 Propósito

Clasificar de forma explícita y actualizada todas las decisiones de diseño de PROJECT GRAVITY en **Confirmadas (Inmutables)** vs **Abiertas (Pendientes)**, y auditar la arquitectura funcional completa contra los 5 Pilares de Diseño.

---

## 🔒 DECISIONES CONFIRMADAS (Inmutables)

Las siguientes decisiones forman parte de la identidad fundacional de GRAVITY. No pueden alterarse sin un RFC aprobado con justificación arquitectónica extrema.

### 1. La Información como Recurso Principal
- El TTK frontal sin información de dron es elevado.
- Disparar o avanzar a ciegas constituye un error táctico estructural.
- La Niebla de Guerra y el cono de visión son mecánicas primarias de combate, no solo estética.

### 2. El Dron como Extensión Permanente del Operador
- La identidad del jugador es la Tríada Táctica: *Operador + Exoesqueleto + Dron*.
- El dron no es una habilidad con cooldown, ni mascota, ni gadget.
- La pérdida del dron exige recuperación táctica activa mediante Recursos de Mantenimiento.

### 3. Generaciones Tecnológicas Permanentes e Irreversibles
- La progresión sigue la secuencia: Gen 1 (0-15 min) → Gen 2 (~15 min) → Gen 3 (~30 min).
- Las Generaciones **no se pierden** al morir ni al perder operadores.
- La progresión se siente como "dominio tecnológico del campo de batalla", no como subir de nivel.

### 4. Infraestructura Física para Evolucionar
- El salto de Generación exige canalización física en los **Centros de Integración Tecnológica** del mapa.
- La canalización es detectable y genera ventana de interrupción táctica para el rival.

### 5. Separación Estricta de Recursos
- *Recursos de Mantenimiento* ≠ *Recursos de Evolución*.
- Nunca se mezclan ni son intercambiables.

### 6. Objetivo Basado en Operación Tecnológica del Núcleo IA
- El hackeo del Núcleo es una operación continuada por presencia de red en el perímetro.
- No es un "plantar bomba" estático.

### 7. Gen 3 Otorga Efectos de Red, No Mayor Daño
- La superioridad de Gen 3 es de información y soporte de escuadra.
- Un equipo de Gen 1 coordinado puede derrotar a jugadores Gen 3 dispersos.

### 8. La Cooperación es Superior al Héroe Individual
- Cero mecánicas de *Press Button to Win* o *Lone Wolf Carry*.
- Los Efectos de Red de Gen 3 exigen 4 operadores vivos y coordinados para alcanzar su máximo potencial.

---

## 🔓 DECISIONES ABIERTAS (En Proceso de Profundización)

Las siguientes áreas están en elaboración o serán evaluadas en prototipado en `sandbox/`:

1. **Tiempos exactos de canalización en Centros de Integración**: El valor de 4 segundos es provisional. Debe prototipase en `sandbox/` para validar el equilibrio entre vulnerabilidad táctica y gratificación.
2. **Coste exacto de Recursos de Evolución (Gen 1→2 y Gen 2→3)**: Intencionalmente sin números. Se definirá después del prototipado del Vertical Slice.
3. **Límite exacto del inventario de componentes**: Actualmente estimado en 100 unidades. Pendiente de ajuste empírico.
4. **Árbol de módulos específicos por Doctrina en Gen 2**: Las opciones concretas dentro de cada Doctrina están pendientes de especificación.
5. **Variantes de operadores disponibles en lanzamiento**: Pendiente del Cuestionario Mandatory de 5 Preguntas de `operator_design_rules.md`.
6. **Balance entre autonomía y control directo del dron**: La proporción óptima de uso entre Modo Escolta y Modo Piloto se determinará en prototipado.

---

## 📊 Auditoría del Sistema de Generaciones Tecnológicas y Pacing contra los 5 Pilares

### Pilar 1 — La Información es el Recurso más Valioso ✅
- **Gen 1**: La Niebla de Guerra y los drones base determinan quién tiene ventaja en el primer contacto.
- **Gen 2**: La elección de Doctrina de *Reconocimiento* marca qué equipo tiene mayor visión del mapa.
- **Gen 3**: El *Radar Neuronal* de Gen 3 comparte posiciones enemigas en tiempo real con toda la escuadra.
- **Riesgo Auditado y Mitigado**: Gen 3 no puede convertirse en información omnisciente sin esfuerzo. El dron sigue requiriendo despliegue activo.

### Pilar 2 — El Jugador Nunca Combate Solo ✅
- La Tríada Táctica garantiza que el operador siempre opera con su extensión cibernética.
- Los Efectos de Red de Gen 3 crean interdependencia tácticas entre los 4 operadores.
- **Riesgo Auditado y Mitigado**: El *Scavenger* (Field Engineer) debe tener protección armada para no quedar aislado durante la cosecha de piezas.

### Pilar 3 — El Objetivo es Controlar el Núcleo IA ✅
- Los Centros de Integración de Gen 3 están posicionados en zonas de riesgo cercanas al Núcleo, vinculando orgánicamente la progresión con el objetivo final.
- Alcanzar Gen 3 sin atacar el Núcleo es gastar recursos sin convertirlos en presión de victoria.
- **Riesgo Auditado y Mitigado**: La Onda de Pulso Continua del Núcleo a los 40 minutos fuerza el asalto final, evitando partidas estancadas.

### Pilar 4 — El Terreno Decide la Batalla ✅
- Controlar los Centros de Integración Tecnológica es un objetivo físico en el mapa. No se puede evolucionar sin pisar ese territorio.
- Los Wreck Sites (Scrap Zones) generados por destrucción de drones crean zonas de interés dinámicas en la geometría del nivel.
- La cobertura física del mapa es igualmente efectiva para Gen 1 y Gen 3.
- **Riesgo Auditado y Mitigado**: Los Centros de Integración no pueden estar en zonas completamente seguras ni en zonas imposiblemente peligrosas.

### Pilar 5 — La Cooperación Supera al Héroe Individual ✅
- Un operador Gen 3 solitario que intenta capturar el Núcleo sin escuadra es vulnerable desde todos los ángulos.
- Los Efectos de Red de Gen 3 requieren que todos los operadores estén activos y coordinados para alcanzar su máximo impacto.
- La recuperación de drones en campo requiere protección activa del equipo.
- **Riesgo Auditado y Mitigado**: Ninguna Doctrina de Gen 2 o Gen 3 puede ser completamente autosuficiente según las reglas de `operator_design_rules.md`.

---

## ⚠️ Riesgos de Diseño Abiertos para Vigilancia Continua

| Riesgo | Probabilidad | Plan de Mitigación |
| :--- | :--- | :--- |
| Gen 1 se vuelve demasiado lenta y aburrida | Media | Pulsos de escaneo de Nodos desde el min 5 + Niebla que se disipa parcialmente |
| Gen 2 crea snowball insuperable | Media | Firma detectable en canalización + bono de daño a targets canalizando |
| Gen 3 se siente como DPS upgrade | Alta (Vigilar) | Gen 3 solo otorga Efectos de Red de información/soporte, NUNCA daño bruto |
| Partidas superiores a 45 min | Media-Alta | Onda de Pulso Continua del Núcleo a los 40 min fuerza resolución |
