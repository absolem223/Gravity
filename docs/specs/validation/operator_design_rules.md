# SPEC VALIDATION: OPERATOR DESIGN RULES — REGLAS DE DISEÑO DE OPERADORES

- **Estado**: Aprobado (Fase 0.5 — Validación y Profundización)
- **Ubicación**: `docs/specs/validation/operator_design_rules.md`

---

## 🎯 Regla de Oro del Diseño de Operadores

> **"Ningún Operador en GRAVITY es una isla. Todo Operador debe ser un engranaje incompleto que solo alcanza su máximo poder al acoplarse con su escuadra."**

Queda estrictamente prohibido crear operadores "autosuficientes" que posean detección de información, gran potencia de fuego, alta movilidad y capacidad de supervivencia autónoma.

---

## 📋 El Cuestionario Mandatory de 5 Preguntas

Todo nuevo operador o propuesta de kit debe responder obligatoriamente a las siguientes 5 preguntas antes de ingresar a fase de diseño técnico:

### 1. ¿Qué Información Aporta?
- ¿Cómo altera o revela la Niebla de Guerra?
- *Ejemplo*: Revela firmas electromagnéticas a través de paredes pero no la posición exacta de movimiento.

### 2. ¿Cómo Interactúa con su Dron?
- ¿Cuál es la simbiosis entre el cuerpo del operador y el dron?
- *Ejemplo*: El dron proyecta una pantalla de humo térmico que solo el visor del exoesqueleto de este operador puede filtrar parcialmente.

### 3. ¿Qué Aporta al Equipo?
- ¿Cuál es su contribución táctica colectiva?
- *Ejemplo*: Proporciona recarga remota de batería a los drones de sus 3 aliados en el perímetro.

### 4. ¿Qué Dependencia Crea con otros Operadores?
- ¿De quién requiere ayuda para sobrevivir o ser efectivo?
- *Ejemplo*: Es altamente vulnerable durante el proceso de hackeo y requiere que un *Breacher* absorba el fuego de supresión.

### 5. ¿Qué Debilidad Táctica Incurable Tiene?
- ¿Cuál es su talón de Aquiles estructural?
- *Ejemplo*: Posición totalmente ciega durante el control de dron en modo piloto; cero resistencia a pulsos EMP.

---

## 🚫 Lista Roja de Anti-Patrones de Operador

- ❌ **El Asesino Invisible**: Operadores con sigilo total que disparan sin revelar su posición ni a drones. (Viola Pilar 1).
- ❌ **El Tanque Solitario**: Operadores con escudos impenetrables de 360 grados que pueden capturar el Núcleo sin ayuda. (Viola Pilar 2 y 5).
- ❌ **El Francotirador Omnipresente**: Operadores que ven todo el mapa desde su base sin desplegar drones. (Viola Pilar 4).
