# SPEC VALIDATION: OPERATOR DESIGN RULES — REVISIÓN 5.0: TECH SCAVENGER REDEFINIDO

- **Estado**: Actualizado / Revisión 5.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/operator_design_rules.md`

---

## 🎯 Regla de Oro del Diseño de Operadores

> **"Ningún Operador en GRAVITY es una isla. Todo Operador debe ser un engranaje incompleto que solo alcanza su máximo poder al acoplarse con su escuadra."**

Ningún operador puede ser autosuficiente en información, potencia de fuego, movilidad y supervivencia simultáneamente.

---

## 📋 El Cuestionario Mandatory de 5 Preguntas

Todo nuevo operador debe responder obligatoriamente:

### 1. ¿Qué Información Aporta?
¿Cómo altera o revela la Niebla de Guerra? ¿Qué ve que otros no pueden ver?
*Ejemplo*: Revela firmas electromagnéticas a través de paredes pero no la posición exacta de movimiento.

### 2. ¿Cómo Interactúa con su Dron?
¿Cuál es la simbiosis entre el cuerpo del operador y el dron?
*Ejemplo*: El dron proyecta una pantalla de humo térmico que solo el visor de este exoesqueleto puede filtrar parcialmente.

### 3. ¿Qué Aporta al Equipo?
¿Cuál es su contribución táctica colectiva irremplazable?
*Ejemplo*: Proporciona recarga remota de batería a los drones de sus aliados en el perímetro.

### 4. ¿Qué Dependencia Crea con otros Operadores?
¿De quién requiere ayuda para sobrevivir o ser efectivo?
*Ejemplo*: Es altamente vulnerable durante el proceso de hackeo y requiere que un Breacher absorba el fuego.

### 5. ¿Qué Debilidad Táctica Incurable Tiene?
¿Cuál es su talón de Aquiles estructural?
*Ejemplo*: Queda completamente ciego durante el control de dron en modo piloto.

---

## 🎭 Los 5 Roles Tácticos de GRAVITY

### 1. 👁️ Recon / Intel Architect
- **Función**: Mapear Niebla de Guerra, identificar firmas enemigas, detectar canalizaciones de Generación.
- **Dependencia**: Necesita al Breacher para cubrir su posición mientras su dron explora.
- **Debilidad**: Efectividad reducida en combate cerrado donde el sonar no tiene alcance.

### 2. 🛡️ Vanguard / Breacher
- **Función**: Absorber impacto, asegurar coberturas, avanzar hacia el Núcleo IA.
- **Dependencia**: Necesita información del Recon para no avanzar a ciegas (como A2 en la simulación).
- **Debilidad**: Lento para reposicionarse; queda expuesto si pierde la cobertura inicial.

### 3. ⚡ Tech Disruptor / Hacker
- **Función**: Hackeo remoto, inhabilitación de visores, interferencia en canalizaciones enemigas.
- **Dependencia**: Requiere que el Breacher cree los ángulos seguros para que su Dron alcance los objetivos.
- **Debilidad**: Cero si su Dron es destruido — queda reducido a combatiente estándar.

### 4. 🎯 Overwatch / Anchor
- **Función**: Fuego de supresión de largo alcance, soporte energético de drones aliados.
- **Dependencia**: Necesita información del Recon para aplicar supresión sobre posiciones confirmadas.
- **Debilidad**: Posición fija que es previsible para un equipo con buena información.

### 5. 🔧 Tech Scavenger / Field Engineer (Rediseño Post-Simulación)
**Problema corregido**: El rol original era percibido como "recolector pasivo".

**Nueva Definición**: Operador especializado en **Control Tecnológico Activo del Campo de Batalla**.

#### Las 5 Funciones Tácticas Activas del Field Engineer:
1. **Cosecha Remota por Dron**: Extrae componentes de Wreck Sites sin exposición física. Permanece en posición de combate mientras el Dron trabaja.
2. **Reparación de Drones Aliados en Campo**: Sintetiza el dron destruido de un aliado a distancia de campo mediante enlace de red Dron-a-Dron.
3. **Activación y Sabotaje de Infraestructura**: Hackea nodos secundarios para denegar recursos al rival o activar bonificaciones de zona.
4. **Interferencia en Canalizaciones Enemigas**: En Gen 2 (Doctrina Logística), su Dron puede crear ruido electromagnético en el Centro de Integración rival durante la Fase 2, extendiendo efectivamente su ventana de vulnerabilidad.
5. **Consolidación de Wreck Sites Aliados**: Asegura los restos de drones aliados en terreno controlado, protegiéndolos del saqueo enemigo.

#### Cuestionario Mandatory del Field Engineer:
- ✅ **Información**: Revela ubicaciones de Wreck Sites activos y estado de nodos tecnológicos en el mapa táctico.
- ✅ **Dron**: Su Dron es su herramienta de trabajo principal. Sin él, la mayoría de sus funciones quedan inhabilitadas.
- ✅ **Aporte al Equipo**: Sostiene la economía de Mantenimiento de la escuadra y acelera la recuperación tecnológica post-combate.
- ✅ **Dependencia**: Necesita protección armada de Breacher u Overwatch mientras su Dron trabaja en zonas expuestas.
- ✅ **Debilidad**: Si su Dron es destruido, pierde su ventaja táctica única y queda como combatiente de línea sin especialización ofensiva.

---

## 🚫 Lista Roja de Anti-Patrones de Operador

- ❌ **El Asesino Invisible**: Sigilo total con puntería de daño máximo (Viola Pilar 1).
- ❌ **El Tanque Solitario**: Escudo de 360 grados + captura autónoma del Núcleo (Viola Pilares 2 y 5).
- ❌ **El Francotirador Omnipresente**: Ve todo el mapa desde spawn sin desplegar drones (Viola Pilar 4).
- ❌ **El Recolector Fantasma**: Cosecha todo el mapa sin participar en combate ni soporte directo (Viola Pilar 2 — versión anterior del Scavenger).
