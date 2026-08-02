# SPEC VALIDATION: DRONE DESIGN RULES — REVISIÓN 4.0

- **Estado**: Actualizado / Revisión 4.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/drone_design_rules.md`

---

## 🎯 1. Filosofía del Dron: La Extensión Permanente del Operador

La identidad inmutable del jugador en GRAVITY es la **Tríada Táctica**:

$$\text{Identidad del Jugador} = \text{Operador Humano} + \text{Exoesqueleto Táctico} + \text{Dron Permanente}$$

El Dron no es:
- ❌ Una habilidad con cooldown.
- ❌ Una mascota decorativa pasiva.
- ❌ Un gadget de un solo uso.
- ❌ Una torreta autónoma de daño.

El Dron es:
- ✅ La segunda fuente de percepción e inteligencia táctica del operador.
- ✅ Una extensión física y tecnológica presente desde el inicio hasta el fin de la partida.
- ✅ Una entidad que evoluciona junto al operador a través de las Generaciones Tecnológicas.

---

## 📈 2. Evolución del Dron por Generaciones Tecnológicas

La evolución del Dron está directamente acoplada al avance de las Generaciones del Operador. No existe una progresión separada del dron; la Tríada Táctica evoluciona como una unidad.

### Generación 1 — Dron Estándar (0:00 a ~15:00 min)
El dron en su estado base ofrece capacidades tácticas esenciales pero limitadas:
- **Modo Escolta**: Orbita el hombro del operador y escanea en cono secundario de visión.
- **Modo Estacionario**: Se ancla a superficies como cámara de vigilancia o repetidor de red.
- **Modo Piloto Directo**: El operador pilota el dron en tiempo real (su cuerpo queda inmóvil y vulnerable).
- Rango de enlace de red: alcance básico.
- Batería estándar sin mejoras de eficiencia.

### Generación 2 — Dron Especializado (~15:00 min en adelante)
Al alcanzar Gen 2, el operador elige una **Doctrina Tecnológica permanente** en un Centro de Integración. El dron adopta las características de esa doctrina:

| Doctrina | Capacidades del Dron en Gen 2 |
| :--- | :--- |
| **Reconocimiento** | Sonar de alta frecuencia, escaneo omnidireccional, filtrado térmico a través de paredes |
| **Defensa** | Proyección de micro-escudos, atenuación balística en el perímetro del operador |
| **Soporte Logístico** | Campo de recarga de batería para drones aliados, enlace de transferencia de componentes |
| **Asistencia Ofensiva** | *Smart Vectoring*, marcado de puntos débiles en armaduras enemigas |
| **Manipulación Tecnológica** | Hackeo remoto de puertas/terminales, inhabilitación de visores enemigos |

### Generación 3 — Dron de Evolución Avanzada (~30:00 min en adelante)
La Doctrina se profundiza y el dron desbloquea **Efectos de Red pasivos** que benefician a toda la escuadra automáticamente, sin requerir activación manual.

---

## 🔧 3. Sistema de Pérdida y Recuperación

La destrucción del dron **no regenera automáticamente por tiempo**. El proceso de recuperación requiere esfuerzo táctico:

```
Dron Destruido ──► Wreckage Site (Restos en el mapa)
                        │
                        ▼
        Recolección de Recursos de Mantenimiento
        (Chatarra del dron, nodos del mapa, infraestructura)
                        │
                        ▼
        Síntesis en Punto de Reabastecimiento
        (El dron regresa en su Generación actual: inmutable)
```

**Distinción crítica**: Los *Recursos de Mantenimiento* reconstruyen el dron en su Generación actual. Los *Recursos de Evolución* (distintos) permiten avanzar de Generación en los Centros de Integración. La destrucción del dron **no hace retroceder la Generación alcanzada**.

---

## ⚖️ 4. El Trilema Táctico: Proteger, Usar o Sacrificar

En cada enfrentamiento, el jugador debe tomar una decisión crítica con su dron:

| Opción | Acción | Ventaja | Riesgo |
| :--- | :--- | :--- | :--- |
| **Proteger** | Mantener en Modo Escolta | Conserva la visión local constante | Limita el alcance de exploración |
| **Usar** | Enviar en Modo Piloto o Estacionario | Obtiene visión lejana o hackeo | El operador queda ciego si el dron es destruido |
| **Sacrificar** | Activar sobrecarga EMP | Inhabilita la sala entera | El dron tarda en sintetizarse de nuevo |

---

## 🛑 5. Límites Estructurales Invariables

- El dron **nunca es una fuente de daño primario autónomo**.
- El dron emite **firma de audio y luz** cuando escanea activamente (los enemigos atentos pueden detectarlo).
- Si el dron supera el **rango de enlace de red**, entra en modo deriva y queda vulnerable al hackeo enemigo.
- La batería del dron y la energía del exoesqueleto comparten la **misma fuente (Batería Táctica)**. Activar impulsos físicos del exoesqueleto reduce la autonomía del dron.

---

## 🚫 6. Anti-Patrones de Diseño de Dron (Lista Roja)

- ❌ Drones con armas automáticas que eliminen enemigos sin decisión del jugador.
- ❌ Drones con sigilo total que los haga indetectables durante toda la partida.
- ❌ Drones que se regeneren pasivamente sin coste táctico de mantenimiento.
- ❌ Drones cuya única función sea aumentar el daño de disparo del operador.
