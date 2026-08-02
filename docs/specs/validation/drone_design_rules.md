# SPEC VALIDATION: DRONE DESIGN RULES — REVISIÓN 5.0

- **Estado**: Actualizado / Revisión 5.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/drone_design_rules.md`

---

## 🎯 1. Filosofía del Dron: La Extensión Permanente del Operador

La identidad inmutable del jugador en GRAVITY es la **Tríada Táctica**:

$$\text{Identidad del Jugador} = \text{Operador Humano} + \text{Exoesqueleto Táctico} + \text{Dron Permanente}$$

El Dron no es: ❌ Habilidad con cooldown · ❌ Mascota decorativa · ❌ Gadget de un solo uso · ❌ Torreta autónoma de daño.

El Dron es: ✅ Segunda fuente de percepción táctica · ✅ Extensión física y tecnológica presente desde el inicio · ✅ Entidad que evoluciona junto al operador · ✅ Guardián natural durante las canalizaciones del operador.

---

## 📈 2. Evolución del Dron por Generaciones Tecnológicas

### Generación 1 — Dron Estándar (0:00 a ~15:00 min)
- **Modo Escolta**: Orbita el hombro del operador, escanea en cono secundario.
- **Modo Estacionario**: Se ancla a superficies como cámara de vigilancia o repetidor de red.
- **Modo Piloto Directo**: Pilotado en tiempo real; el cuerpo del operador queda inmóvil y vulnerable.
- Rango de enlace de red: alcance básico.
- Batería estándar.

### Generación 2 — Dron Especializado (~15:00 min en adelante)
La Doctrina elegida define el perfil del Dron:

| Doctrina | Capacidades del Dron en Gen 2 |
| :--- | :--- |
| **Reconocimiento** | Sonar de alta frecuencia, escaneo omnidireccional, filtrado térmico |
| **Defensa** | Proyección de micro-escudos, atenuación balística en el perímetro |
| **Soporte Logístico** | Recarga de batería de drones aliados, reparación Dron-a-Dron en campo, interferencia en canalizaciones enemigas |
| **Asistencia Ofensiva** | *Smart Vectoring*, marcado de puntos débiles en armaduras |
| **Manipulación Tecnológica** | Hackeo remoto de puertas/terminales, inhabilitación de visores |

### Generación 3 — Dron de Evolución Avanzada (~30:00 min en adelante)
- La Doctrina se profundiza.
- El Dron desbloquea **Efectos de Red pasivos** que benefician a toda la escuadra.
- Los efectos de red se desactivan si el operador Gen 3 fuente es incapacitado.

---

## 🔧 3. Sistema de Pérdida y Recuperación

La destrucción del Dron **no regenera automáticamente**. Proceso de recuperación:

```
Dron Destruido ──► Wreckage Site (Restos en el mapa)
                        │
         ┌──────────────┴──────────────┐
         ▼                             ▼
Cosecha propia                 Cosecha por Field Engineer aliado
(el operador)                  (reparación Dron-a-Dron remota)
         └──────────────┬──────────────┘
                        ▼
           Síntesis en Punto de Reabastecimiento
           (El dron regresa en su Generación actual)
```

**Distinción crítica**: La destrucción del Dron NO hace retroceder la Generación alcanzada.

---

## 🛡️ 4. El Dron como Guardián durante la Canalización

Durante la **Fase 2 de Canalización** (ventana de interrupción de 6 segundos), el operador tiene movilidad reducida. El Dron, al poder actuar libremente, se convierte en el **protector natural**:

- Puede interceptar un dron enemigo que intente enlace de hackeo sobre el operador.
- Puede proyectar barrera electromagnética para obstruir líneas de visión enemigas hacia el Centro de Integración.
- Puede actuar como señuelo para distraer al rival mientras el operador completa la Fase 3.

Esta mecánica refuerza directamente la simbiosis Operador-Dron en los momentos de mayor vulnerabilidad.

---

## ⚖️ 5. El Trilema Táctico: Proteger, Usar o Sacrificar

| Opción | Acción | Ventaja | Riesgo |
| :--- | :--- | :--- | :--- |
| **Proteger** | Mantener en Modo Escolta | Conserva visión local y protección de canalización | Limita el alcance de exploración |
| **Usar** | Enviar en Modo Piloto o Estacionario | Obtiene visión lejana, hackeo o cosecha remota | El operador queda ciego si el Dron es destruido |
| **Sacrificar** | Activar sobrecarga EMP | Inhabilita la sala entera / contraataque enemigo | El Dron tarda en sintetizarse; la Generación se mantiene |

---

## 🛑 6. Límites Estructurales Invariables

- El Dron **nunca es fuente de daño primario autónomo**.
- El Dron emite **firma de audio y luz** al escanear activamente.
- Si supera el **rango de enlace de red**, entra en modo deriva y queda vulnerable al hackeo enemigo.
- La batería del Dron y la energía del exoesqueleto comparten la misma fuente (**Batería Táctica**).

---

## 🚫 7. Anti-Patrones de Diseño de Dron (Lista Roja)

- ❌ Drones con armas automáticas que eliminen enemigos sin decisión del jugador.
- ❌ Drones con sigilo total indetectable durante toda la partida.
- ❌ Drones que se regeneren pasivamente sin coste táctico.
- ❌ Drones cuya única función sea aumentar el daño directo del operador.
