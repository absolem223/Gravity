# SPEC VALIDATION: DESIGN VALIDATION — REVISIÓN 6.0: AUDITORÍA POST-SIMULACIÓN GEN 3

- **Estado**: Actualizado / Revisión 6.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/design_validation.md`

---

## 🎯 Propósito

Auditoría completa y definitiva de la arquitectura funcional de PROJECT GRAVITY. Incorpora los hallazgos de ambas simulaciones de partida (`full_match_simulation.md` y `full_match_simulation_gen3.md`) y cierra formalmente la **Fase 0.5 — Game Architecture**.

---

## 🔒 DECISIONES CONFIRMADAS (Inmutables)

### 1. La Información como Recurso Principal
- El TTK frontal sin información de Dron es elevado y penalizador.
- Avanzar sin información de posición enemiga es un error táctico estructural.
- La Niebla de Guerra y el cono de visión son mecánicas primarias de combate.
- **Validado en Gen 3**: El Radar Neuronal tuvo un punto ciego estructural (conductos sin escanear) que fue explotado tácticamente — la información nunca es omnisciente.

### 2. El Dron como Extensión Permanente del Operador
- Tríada Táctica: Operador + Exoesqueleto + Dron.
- El Dron actúa como guardián natural durante la Fase 2 de Canalización.
- La pérdida del Dron exige recuperación táctica activa; la Generación alcanzada no se pierde.
- **Validado en Gen 3**: El sacrificio del Dron de I1 (EMP) fue la jugada decisiva de la partida. Sin Dron, I1 quedó tácticamente reducido — el Efecto de Red desapareció con él.

### 3. Generaciones Tecnológicas Permanentes e Irreversibles
- Secuencia: Gen 1 (0–15 min) → Gen 2 (~15 min) → Gen 3 (~30 min).
- Las Generaciones no se pierden al morir.
- **Validado en Gen 3**: En condiciones normales, 1 a 2 operadores por escuadra alcanzan Gen 3. No es necesario que toda la escuadra evolucione — esto es un resultado correcto.

### 4. Sistema de Canalización en Tres Fases
- Fase 1: Calentamiento (3 seg) — firma débil.
- Fase 2: Activo (6 seg) — firma fuerte, única ventana de interrupción.
- Fase 3: Estabilización (2 seg) — irreversible.
- **Validado en Gen 3**: I3 extendió la Fase 2 de V1 en +2 segundos con ruido electromagnético, dando tiempo a I2 para llegar. Sin esa interferencia, V1 hubiera completado Gen 3 sin oposición. El mecanismo tuvo valor táctico real.

### 5. Persistencia Parcial del Progreso del Núcleo IA
- Estado ACTIVO → CONTESTADO → DEGRADACIÓN (no reseteo).
- Degradación: -10%/30 seg. Al superar 50%, -5%/30 seg.
- **Validado en Gen 3**: La barra se degradó del 35% (primer intento) al 25% durante el período de reagrupación, lo que equivalió a ~5 minutos de control defensor. La persistencia fue justa — el avance no desapareció, pero tampoco fue gratuito.

### 6. Field Engineer como Control Tecnológico Activo
- 5 funciones tácticas activas mediante Dron.
- **Validado en Gen 3**: I4 transfirió recursos a I2 en el minuto 22 (Factor decisivo para que I2 alcanzara Gen 2). La reparación Dron-a-Dron redujo el tiempo de síntesis del Dron de I3 en los primeros minutos.

### 7. Gen 3 como Poder Estratégico Sin Victoria Automática
- Principio rector: *Gen 3 amplía las opciones de la escuadra. No sustituye la necesidad de ejecutarlas.*
- Los Efectos de Red se desactivan si el operador Gen 3 fuente es incapacitado.
- **Validado en Gen 3**: V1 con Supresión Sincronizada fue desactivada al ser incapacitada por el EMP de I1. VEIL estuvo a segundos de ganar incluso con V1 caída — el contrajuego existió y fue ejecutable.
- **Respuesta a la pregunta central**: Gen 3 crea nuevas decisiones tácticas sin crear una ventaja imposible de remontar. ✅

### 8. La Cooperación es Superior al Héroe Individual
- **Validado en Gen 3**: La victoria de IRON requirió 4 acciones encadenadas: sacrificio de Dron (I1) + mantenimiento de enlace bajo fuego (I2) + protección exterior con Dron (I3) + recursos acumulados desde el minuto 22 (I4). Ninguna acción sola fue suficiente.

---

## 🔓 DECISIONES ABIERTAS — ACTUALIZADAS POST-GEN 3

Las siguientes decisiones estaban abiertas antes de la simulación Gen 3 y se actualizan ahora:

### Abiertas que Permanecen Pendientes
1. **Valores exactos de canalización**: Los 3+6+2 segundos son estimaciones de diseño. Requieren prototipado.
2. **Ritmo exacto de degradación del Núcleo**: -10%/30 seg es estimación. Se ajustará en Vertical Slice.
3. **Árbol de módulos específicos por Doctrina en Gen 2**: Pendiente de especificación.
4. **Coste exacto de Recursos de Evolución**: Se definirá en el Vertical Slice.

### Nuevas Decisiones Abiertas (Derivadas de la Simulación Gen 3)

5. **Punto ciego de Recon Gen 3 en conductos**: El conducto sumergido que V3 usó para evadir el Radar Neuronal fue tácticamente correcto, pero podría volverse la estrategia dominante. Se propone una detección de movimiento pasiva (vibración, calor) que genere alertas blandas en el HUD del Recon. *Pendiente de validación con `vision_cone.md`.*

6. **Condición de exposición del operador para sobrecarga EMP del Dron**: Para evitar que el EMP sea ejecutable desde cobertura total sin riesgo, se propone que el operador requiera establecer línea de visión directa durante 1 segundo antes de la detonación. *Pendiente de especificación en `drone_design_rules.md`.*

---

## 📊 Auditoría Completa — Ambas Simulaciones vs los 5 Pilares

| Pilar | Sim 1 (38 min) | Sim Gen 3 (43 min) | Veredicto |
| :--- | :--- | :--- | :--- |
| **1. Información > Reacción** | ✅ A2 suprimido por avanzar a ciegas | ✅ V3 evitó Sonar usando conducto; punto ciego decisivo | ✅ VALIDADO |
| **2. Dron como Extensión** | ✅ Sacrificio EMP de A3 bloqueó contraataque | ✅ Sacrificio EMP de I1 fue la jugada decisiva | ✅ VALIDADO |
| **3. Núcleo IA es el Objetivo** | ✅ Estado Contestado al 47% fue el clímax emocional | ✅ Toda la maniobra de fin de partida ocurrió en el perímetro del Núcleo | ✅ VALIDADO |
| **4. Terreno Decide** | ✅ B4 en posición elevada dominó 20 minutos | ✅ Conducto sumergido no escaneado fue punto pivote | ✅ VALIDADO |
| **5. Cooperación > Individuo** | ✅ Victoria requirió cadena de 4 roles coordinados | ✅ Cadena de 4 acciones simultáneas de IRON en el clímax | ✅ VALIDADO |

---

## ⚠️ Tabla de Riesgos — Estado Final Post-Ambas-Simulaciones

| Riesgo | Estado | Resolución |
| :--- | :---: | :--- |
| Gen 1 lenta y pasiva | ✅ Mitigado | Pulsos de Nodos desde min 5; Niebla que se disipa en sector central |
| Gen 2 snowball insuperable | ✅ Mitigado | Firma en canalización (6 seg de ventana real + interferencia por Dron) |
| Gen 3 como victoria automática | ✅ **CERRADO** | Efectos de Red desactivables; sin daño bruto; V3 en conducto casi invierte la partida |
| Hackeo frustrante por reset total | ✅ **CERRADO** | Persistencia parcial con degradación -10%/30 seg validada en simulación |
| Field Engineer percibido como pasivo | ✅ **CERRADO** | 5 funciones activas validadas: transferencia de recursos e I4 fue pivote de partida |
| Canalización sin tensión táctica | ✅ **CERRADO** | Interferencia de I3 extendió la Fase 2 de V1 en +2 seg — tácticamente relevante |
| EMP del Dron como herramienta abusiva | 🔶 ABIERTO | Propuesta: requiere línea de visión directa 1 seg antes de detonación |
| Conducto como punto ciego dominante | 🔶 ABIERTO | Propuesta: alertas blandas de detección pasiva en geometría cerrada |

---

## 🏁 Cierre Oficial de la Fase 0.5 — Game Architecture

**Todas las decisiones de diseño han sido:**
1. Especificadas en documentos SPEC formales.
2. Auditadas contra los 5 pilares.
3. Simuladas en condiciones reales (partida Gen 2 completa + partida Gen 3 completa).
4. Corregidas donde se detectaron problemas.
5. Re-auditadas después de las correcciones.

**✅ Fase 0.5 — Game Architecture: CERRADA**

### Siguiente Fase: Vertical Slice Design

El Vertical Slice definirá el subconjunto mínimo de sistemas necesarios para el primer prototipo jugable en `sandbox/`:

- Sistema de movimiento y física del operador.
- Sistema de Dron (Gen 1: Escolta, Estacionario, Piloto).
- Niebla de Guerra y cono de visión básico.
- Un objetivo prototipo del Núcleo IA (sin estados dinámicos completos).
- Un mapa de sandbox para pruebas de mecánicas fundamentales.

Los dos problemas abiertos post-Gen 3 (EMP y conductos) se resolverán durante el prototipado del Vertical Slice en `sandbox/`.
