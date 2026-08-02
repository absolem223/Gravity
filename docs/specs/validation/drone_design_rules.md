# SPEC VALIDATION: DRONE DESIGN RULES — REGLAS DEL SISTEMA DE DRONES

- **Estado**: Aprobado (Fase 0.5 — Validación y Profundización)
- **Ubicación**: `docs/specs/validation/drone_design_rules.md`

---

## 🎯 Filosofía del Dron: Extensión, No Mascota

En GRAVITY, el Dron de Asistencia **no es un adorno visual ni una torreta de daño automático**. 

El Dron es el ojo cibernético del jugador en el mapa. Sin el Dron, el operador queda funcionalmente ciego y expuesto.

---

## 🛠️ Acciones Exclusivas que SIEMPRE Requieren Drones

1. **Exploración de Conductos Interiores**: Infiltrarse en accesos de tuberías o techos donde el operador humano no cabe físicamente.
2. **Triangulación de Niebla de Guerra**: Despejar sectores oscuros del minimapa y marcar firmas electromagnéticas enemigas.
3. **Hackeo Remoto a Distancia**: Desactivar puertas, terminales o cámaras desde una posición de cobertura sin exponer el cuerpo del operador.
4. **Despliegue de Sensores de Cobertura**: Proyectar humo térmico o barreras electromagnéticas temporales en el perímetro del Núcleo.

---

## 🛑 Límites y Restricciones Estructurales del Dron

- **Cero Daño Primario Automático**: Los drones no llevan ametralladoras ni eliminan enemigos por sí solos.
- **Autonomía por Batería Táctica**: El vuelo continuo consume batería. Agotar la batería obliga al dron a volver a la espalda del operador para recargarse durante 12 segundos.
- **Rango de Enlace de Red**: Si el dron se aleja más de 45 metros del operador, pierde señal, entra en modo deriva y queda vulnerable al hackeo enemigo.
- **Firma de Audio y Luz**: Un dron activo emite un zumbido electromagnético tenue y una luz de escaneo, permitiendo a los defensores atentos detectar su presencia antes de ser escaneados.

---

## ⚖️ El Trilema Táctico del Dron: ¿Proteger, Usar o Sacrificar?

En cada enfrentamiento, el jugador debe tomar una decisión crítica con su Dron:

```
                  ┌─────────────────────────────┐
                  │    DECISIÓN DEL DRON        │
                  └──────────────┬──────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│   1. PROTEGER    │   │     2. USAR      │   │  3. SACRIFICAR   │
│ Mantener en hombro│   │ Piloto/Escaneo   │   │ Detonar EMP      │
│ (Garantiza info  │   │ (Obtiene visión, │   │ (Inhabilita sala,│
│ local constante) │   │ expone cuerpo)   │   │ pierde dron 30s) │
└──────────────────┘   └──────────────────┘   └──────────────────┘
```

1. **Proteger el Dron**: Guardarlo para conservar la visibilidad local y el radar de espaldas.
2. **Usar el Dron**: Enviarlo a escanear la sala enemiga para otorgar datos a la escuadra, asumiendo el riesgo de que el enemigo lo destruya de un disparo.
3. **Sacrificar el Dron**: Activar el modo de sobrecarga EMP del dron para inhabilitar las defensas de una sala completa, perdiendo toda la información del dron durante los siguientes 30 segundos.
