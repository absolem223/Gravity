# SPEC VALIDATION: DRONE RESOURCE ECONOMY — REVISIÓN 5.0

- **Estado**: Actualizado / Revisión 5.0 (Fase 0.5 — Game Architecture)
- **Ubicación**: `docs/specs/validation/drone_resource_economy.md`

---

## 🎯 Principio Rector de la Economía

> **"El dominio del campo de batalla — no el conteo de bajas — es la fuente principal de prosperidad tecnológica."**

---

## 💰 Los Dos Flujos de Recursos

```
                    RECURSOS TECNOLÓGICOS DEL CAMPO
                                 │
          ┌──────────────────────┴──────────────────────┐
          ▼                                             ▼
RECURSOS DE MANTENIMIENTO                 RECURSOS DE EVOLUCIÓN
──────────────────────────               ──────────────────────────
Propósito: Reparar drones                Propósito: Pagar el salto
destruidos y módulos.                    de Generación (1→2, 2→3).

Fuentes:                                 Fuentes:
- Chatarra de Wreck Sites                - Nodos Tecnológicos del mapa
- Nodos tecnológicos ligeros             - Tecnología abandonada en
- Infraestructura neutral                  sectores de alto riesgo

Dónde se usa:                            Dónde se usa:
Campo / Puntos ligeros                   Centros de Integración
                                         Tecnológica exclusivamente

Dinámica:                                Dinámica:
Consumo táctico rápido                   Consolidación permanente
(emergencia inmediata)                   (inversión a largo plazo)
```

---

## ⏳ Economía por Fase de Partida

### Fase Gen 1 (0:00 - 15:00): Economía de Supervivencia y Territorio
- **Flujo dominante**: Chatarra ligera de Wreck Sites y nodos de acceso fácil.
- **Prioridad**: Mantener los drones reparados y los módulos activos.
- **Conflicto principal**: Disputas por los primeros nodos de recursos entre escuadras que establecen rutas de cosecha.
- **Actores**: Todos los operadores cosechan de forma básica. El Field Engineer tiene ventaja en velocidad de recolección remota.

### Fase Gen 2 (~15:00 - 30:00): Economía de Especialización
- **Flujo dominante**: Nodos tecnológicos de riesgo medio en los flancos del mapa.
- **Prioridad**: Acumular Recursos de Evolución para la canalización en el Centro de Integración.
- **Conflicto principal**: Interceptar canalizaciones enemigas en Fase 2 (ventana de 6 segundos con firma fuerte).
- **Actores**: El Field Engineer transfiere recursos acumulados a operadores prioritarios para que alcancen Gen 2 primero.

### Fase Gen 3 (~30:00 en adelante): Economía de Dominio
- **Flujo dominante**: Nodos avanzados en sectores de alto riesgo cercanos al Núcleo IA.
- **Prioridad**: Controlar la Estación de Gen 3 y financiar la Operación del Núcleo.
- **Conflicto principal**: El equipo que controla la Estación de Gen 3 y el perímetro del Núcleo dicta el clímax de la partida.

---

## 🔧 El Field Engineer en la Economía

El Field Engineer (Tech Scavenger rediseñado) no es un recolector pasivo, sino el **administrador activo de la economía tecnológica de la escuadra**:

1. **Cosecha remota via Dron**: Extrae componentes de Wreck Sites sin exponerse, permaneciendo en posición de combate.
2. **Transferencia de Recursos de Evolución**: Puede compartir recursos acumulados con aliados para acelerar el salto a Gen 2 de un operador prioritario.
3. **Interferencia en Canalizaciones Enemigas**: Su Dron (Doctrina Logística Gen 2) puede crear ruido electromagnético en el Centro de Integración rival, extendiendo la Fase 2 del enemigo.
4. **Consolidación de Wreck Sites**: Protege los restos de drones aliados del saqueo enemigo.

---

## 🛑 Anti-Snowballing: Prevención de Acumulación Desmedida

1. **Límite de Inventario (Cap)**: Cada operador porta un máximo de 100 unidades. Las piezas sobrantes se descartan.
2. **Rendimientos Decrecientes en Mejoras**: El coste de cada nivel de módulo escala exponencialmente. La diferencia entre nivel 2 y nivel 3 es marginal frente al coste.
3. **Pérdida por Incapacitación**: Un operador abatido suelta el 50% de sus componentes no procesados en el mapa.
4. **Inmutabilidad de la Generación Alcanzada**: El equipo perdedor conserva su Generación aunque pierda operadores. La brecha nunca es insalvable tecnológicamente.

---

## 🚫 Prevención del Kill Farming

- Los kills de operadores enemigos otorgan una cantidad **mínima** de chatarra.
- La **mayor fuente de recursos** son los Nodos Tecnológicos del mapa.
- Esto obliga a las escuadras a expandirse y disputar sectores del nivel en lugar de acampar.
