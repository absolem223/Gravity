# SPEC: MATCH PACING & TECHNOLOGY TIMELINE — RITMO DE PARTIDA Y LÍNEA TEMPORAL TECNOLÓGICA

- **Estado**: Propuesto (Fase 0.5 — Game Architecture)
- **Dominio**: Progression & Match Flow
- **Ubicación**: `docs/specs/progression/match_pacing_and_technology_timeline.md`

---

## 🎯 Filosofía del Pacing Tecnológico

GRAVITY adopta una estructura de partida táctica de **Formato Extenso y Multi-Fase (35 a 45 minutos de duración total)**. 

La progresión no es una subida de nivel abstracta o individual de estilo RPG. Debe sentirse bajo la premisa oficial de diseño:

> **"La escuadra consiguió suficiente dominio tecnológico del campo de batalla para evolucionar."**

Las Generaciones Tecnológicas son **permanentes e irreversibles**; una vez alcanzadas por la escuadra en los Centros de Integración, permanecen activas hasta el desenlace de la partida.

---

## ⏳ Línea Temporal de Generaciones Tecnológicas

```
[ 0:00 - 15:00 min ] GENERACIÓN 1 — TECNOLOGÍA BASE (Reconocimiento & Recursos)
                     - Estado base, drones estándar, exploración de niebla.
                     - Cosecha de recursos iniciales y primeros choques por terreno.
                           │
                           ▼ Inversión en Centro de Integración Tecnológica
[ 15:00 - 30:00 min] GENERACIÓN 2 — ESPECIALIZACIÓN TECNOLÓGICA (Doctrinas)
                     - Elección de Doctrina (Recon, Defensa, Logística, Ofensiva, Manipulación).
                     - Diferenciación profunda de Drones y Exoesqueletos.
                           │
                           ▼ Inversión Avanzada en Estación Principal
[ 30:00 - 45:00+ min] GENERACIÓN 3 — EVOLUCIÓN AVANZADA (Efectos de Red & Núcleo)
                     - Tecnologías de red avanzadas y soporte de escuadra.
                     - Operación Tecnológica final sobre el Núcleo IA.
```

---

### 1. Generación 1 — Tecnología Base (0:00 a 15:00 min)
- **Objetivo Táctico**: Establecer la base estratégica de la escuadra.
- **Dinámica**: Exploración de Niebla de Guerra, triangulación de firmas del mapa, cosecha de chatarra tecnológica ligera y primeros choques por el control de Centros de Integración neutros.
- **Sensación**: Incertidumbre, tensión constante, sigilo y recolección de información.

### 2. Generación 2 — Especialización Tecnológica (15:00 a 30:00 min)
- **Objetivo Táctico**: Convertir la doctrina elegida en una ventaja estratégica para la escuadra.
- **Dinámica**: Selección irreversible de 1 de las 5 Doctrinas. El Dron adopta su perfil especializado. Inicio de incursiones coordinadas hacia el perímetro del Núcleo IA.
- **Sensación**: Especialización, choque de doctrinas opuestas y fricción territorial intensa.

### 3. Generación 3 — Evolución Avanzada (30:00 a 45:00+ min)
- **Objetivo Táctico**: Consolidar la superioridad tecnológica para la Operación del Núcleo IA.
- **Dinámica**: Desbloqueo de *Efectos de Red* que potencian a los 4 miembros. El combate alcanza su pico de interacción cibernética.
- **Sensación**: Dominio tecnológico, tensión de Overtime y clímax estratégico.

---

## ⚠️ Análisis de Riesgos y Mitigaciones

### Riesgo 1: Que la Generación 1 (0-15 min) resulte lenta o pasiva
- **Mitigación**: Los Nodos Tecnológicos iniciales emiten pulsos de escaneo periódicos a partir del minuto 5, forzando a los exploradores a encontrarse en el mapa y disputar piezas de mantenimiento.

### Riesgo 2: Que llegar primero a Gen 2 genere un Snowball insuperable
- **Mitigación**: La canalización en el Centro de Integración a Gen 2 emite una firma de energía detectable en todo el mapa. La escuadra retrasada recibe una alerta y un bono de daño por flanqueo a objetivos canalizando, otorgando una ventana de interrupción táctica perfecta.

### Riesgo 3: Que Gen 3 convierta la partida en una victoria automática por daño
- **Mitigación**: Gen 3 **NO otorga mayor daño bruto (DPS)**. Otorga mayor ancho de banda de información y soporte de red. Un jugador Gen 1 bien posicionado detrás de una cobertura indestructible que ejecute supresión con ayuda de la niebla puede eliminar a un operador Gen 3 desatento.

---

## 🛡️ Mecanismos de Recuperación para Equipos Atrasados (Underdog Mechanics)

1. **La Coordinación supera a la Generación**: El trabajo en equipo entre dos operadores Gen 1 (uno suprimiendo y otro flanqueando) vence a un operador Gen 3 aislado.
2. **El Terreno es Neutro**: Una cobertura de hormigón bloquea el 100% del daño balístico independientemente de si proviene de un arma Gen 1 o Gen 3.
3. **Emboscada a Canales de Integración**: Cazar a un enemigo Gen 2 mientras intenta evolucionar a Gen 3 en la estación principal recompensa con el 50% de sus componentes no procesados.
