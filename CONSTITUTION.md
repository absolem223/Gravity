# CONSTITUTION.md — CONSTITUCIÓN DEL WORKSPACE GRAVITY

> **ESTATUS: REGLAS INQUEBRANTABLES DEL PROYECTO.**  
> Esta Constitución posee prioridad máxima, situándose únicamente por debajo de `PROJECT_MANIFEST.md`. Su cumplimiento es obligatorio e innegociable para todo desarrollador humano y agente de IA.

---

## ARTÍCULO I: JERARQUÍA DE FUENTES Y GOBERNANZA

1. **Jerarquía Normativa Suprema**:
   - Nivel 0: [PROJECT_MANIFEST.md](file:///E:/GRAVITY/PROJECT_MANIFEST.md)
   - Nivel 1: [CONSTITUTION.md](file:///E:/GRAVITY/CONSTITUTION.md)
   - Nivel 2: [ADRs](file:///E:/GRAVITY/docs/adrs) (Architecture Decision Records)
   - Nivel 3: [SPECs](file:///E:/GRAVITY/docs/specs) (Specifications técnicas funcionales)
   - Nivel 4: [PRINCIPLES.md](file:///E:/GRAVITY/PRINCIPLES.md) y [SOFTWARE_ARCHITECTURE.md](file:///E:/GRAVITY/SOFTWARE_ARCHITECTURE.md)
   - Nivel 5: Código Fuente y Recursos

2. **Resolución de Conflictos**:  
   En caso de contradicción entre el código y la documentación, el código se considera DEFECTUOSO y debe ser corregido para alinearse a la especificación documentada.

---

## ARTÍCULO II: REGLAS INQUEBRANTABLES DE INGENIERÍA

1. **Lenguaje Oficial y Optimizaciones (ADR-0001)**:
   - GDScript 2.x con tipado estricto (`@export`, `as`, `: Type`) es el único lenguaje oficial de producción inicial en `game/`.
   - Queda estrictamente prohibido introducir código en C++, C# o Rust en `game/` sin un RFC aprobado con benchmarks cuantitativos.
   - No se permiten optimizaciones prematuras antes de medir en runtime.

2. **Estrategia Git y Ramificaciones (ADR-0002)**:
   - Toda integración en `main` debe realizarse mediante ramas de vida corta.
   - Ninguna rama creada por un agente de IA (`ai/*`) podrá permanecer abierta más de 48 horas sin integrarse o cerrarse.
   - Toda modificación de arquitectura, contratos de red o esquemas de datos requiere un RFC formal aprobado.

3. **Agnosticismo de Servidor Dedicado (ADR-0003)**:
   - La simulación y la lógica de red deben estar totalmente desacopladas de la infraestructura de hosting.
   - El código en `game/core/` no debe asumir si corre en un cliente, Godot Headless, o un contenedor de microservicios.

4. **Aislamiento Estricto de Prototipos (`sandbox/`)**:
   - Todo experimento, prueba de concepto o benchmark debe crearse exclusivamente dentro de `sandbox/`.
   - Queda rotundamente prohibido commitear código experimental, sucio o no probado dentro de `game/`.

---

## ARTÍCULO III: LÍMITES Y LEYES DE AGENTES IA

1. **Modo de Operación Propositivo**:  
   Ningún agente de IA modificará decisiones de diseño o contratos de datos existentes sin antes proponer y recibir aprobación explícita o resolución de RFC.

2. **Inviolabilidad de la Memoria Institucional**:  
   El directorio `memory/` registra el aprendizaje acumulado del proyecto. Toda lección aprendida o error detectado debe registrarse en `memory/` para evitar regresiones históricas.

3. **Prohibición de Parches de Gameplay / Godot Prematuros**:  
   Ningún agente generará escenas de Godot, scripts de personajes, armas o gameplay hasta que la fase fundacional esté formalmente concluida y autorizada.
