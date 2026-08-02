# SPEC: OPERATORS SYSTEM — SISTEMA DE OPERADORES Y EXOESQUELETOS

- **Estado**: Propuesto (Fase 0.5 — Game Architecture)
- **Dominio**: Player & Entities
- **Ubicación**: `docs/specs/player/operators_system.md`

---

## 🎯 Filosofía de los Operadores

En **GRAVITY**, un Operador no es un "héroe fantástico" con poderes mágicos ni un soldado genérico. 

Un Operador es un **especialista táctico de respuesta rápida** equipado con una simbiosis tripartita:
1. **El Operador Humano**: Aporta la toma de decisiones estratégicas, posicionamiento y puntería.
2. **El Exoesqueleto**: Proporciona soporte biomecánico, mitigación de impacto, gestión de energía y habilidades físicas tácticas.
3. **El Dron de Asistencia**: Funciona como una **extensión permanente y autónoma** del cuerpo y la mente del operador.

---

## 🦾 Sistema de Exoesqueletos

El Exoesqueleto es el armazón biomecánico que viste el Operador. Define su perfil de movilidad, capacidad de resistencia y capacidad de carga de módulos.

```
┌─────────────────────────────────────────────────────────────┐
│                    EXOESQUELETO TÁCTICO                      │
├──────────────────────────────┬──────────────────────────────┤
│ Módulos Biomecánicos (Físico)│ Módulos de Red (Tecnológico)  │
│ - Estabilidad de retroceso    │ - Capacidad de procesamiento │
│ - Absorción de impacto       │ - Batería del Dron           │
│ - Velocidad de desplazamiento│ - Alcance de señal y hackeo  │
└──────────────────────────────┴──────────────────────────────┘
```

### Principios del Exoesqueleto:
- **No otorga invulnerabilidad**: El exoesqueleto mitiga daño y estabiliza el movimiento, pero un mal posicionamiento sigue siendo letal.
- **Gestión de Energía Compartida**: El exoesqueleto y el Dron consumen la misma fuente de energía (Batería Táctica). Activar un impulso físico reduce la autonomía del Dron.
- **Sin habilidades "Press button to win"**: Las habilidades del exoesqueleto son herramientas funcionales (ej. anclaje magnético para reducir retroceso, cortina de humo térmico, refuerzo de escudo temporal).

---

## 🤖 El Dron como Extensión Permanente del Jugador

Cada operador ingresa al campo de batalla con un **Dron de Asistencia** asignado desde el inicio de la partida. El Dron no es una racha de bajas (*killstreak*) ni una habilidad temporal: **es una entidad viva en el juego**.

### Modos de Operación del Dron:

1. **Modo Escolta (Autónomo)**:
   - El dron orbita sobre el hombro del operador o sigue su espalda.
   - Escanea automáticamente en un cono secundario de visión.
   - Alerta mediante audio/UI sobre firmas electromagnéticas o movimiento en ángulos muertos.

2. **Modo Estacionario (Punto de Control)**:
   - El operador ordena al dron anclarse a una pared, techo o esquina.
   - Actúa como una cámara de vigilancia o repetidor de red para la escuadra.

3. **Modo Control Directo (Piloto)**:
   - El operador entra en estado vulnerable (su cuerpo permanece inmóvil) mientras pilota el dron en tiempo real para infiltrarse en conductos o realizar hackeos remotos.

### Destrucción y Reinicio del Dron:
- Si el dron es destruido por fuego enemigo, el operador pierde su capacidad de reconocimiento secundario y su alcance de hackeo hasta que la batería se recargue y se vuelva a sintetizar el dron en un punto de reabastecimiento.

---

## 🎭 Diferenciación entre Operadores (Sin romper los Pilares)

La diferenciación entre operadores se basa en su **Kit de Información y Utilidad Táctica**, no en daño bruto.

| Tipo de Operador | Enfoque del Exoesqueleto | Enfoque del Dron | Rol Táctico en Escuadra |
| :--- | :--- | :--- | :--- |
| **Intel Specialist** | Ligero, sigilo térmico y velocidad | Dron Micro-Sonar de alta frecuencia | Adquisición de información y mapeo |
| **Breacher / Heavy** | Blindaje pesado, amortiguación de concusión | Dron de barrera de dispersión electromagnética | Apertura de brechas y cobertura |
| **Tech Disruptor** | Procesamiento de red, resistencia a empaches | Dron EMP e interrupción de señales | Inhabilitación de electrónica enemiga |
| **Support Architect** | Despliegue de cobertura dinámica y energía | Dron de reparación física y transferencia | Sustento de escuadra y refuerzo de área |

---

## ⚖️ Auditoría contra los 5 Pilares de Diseño

1. **Pilar 1 (La información es el recurso más valioso)**: Cumplido. El Dron es la fuente primaria de recolección de información del operador.
2. **Pilar 2 (El jugador nunca combate solo)**: Cumplido. El binomio Operador-Dron garantiza que el jugador siempre opere con un compañero sintético.
3. **Pilar 3 (El objetivo es controlar el núcleo, no eliminar enemigos)**: Cumplido. Las habilidades de los operadores están orientadas a defender áreas o hackear el Núcleo, no a exterminio masivo.
4. **Pilar 4 (El terreno decide la batalla)**: Cumplido. El anclaje de drones en la geometría del mapa y el uso del terreno determinan la cobertura.
5. **Pilar 5 (La cooperación supera al héroe individual)**: Cumplido. Un dron solitario no puede capturar el Núcleo; un operador sin dron queda ciego tácticamente.
