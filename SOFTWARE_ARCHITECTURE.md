# SOFTWARE_ARCHITECTURE.md — ARQUITECTURA DE SOFTWARE GRAVITY

## 🏗️ Resumen Arquitectónico

**PROJECT GRAVITY** adopta una arquitectura desacoplada, orientada a datos, con simulación autoritativa en servidor y predicción/reconciliación en cliente.

---

## 🌐 Topología de Red y Replicación (Multiplayer-First)

```
[ CLIENTE 1 ]  <--- (Input / Predicted State) --->  [ SERVIDOR AUTORITATIVO ]
[ CLIENTE 2 ]  <--- (Input / Predicted State) --->  [ (Godot Headless / Independent) ]
                                                            |
                                                   [ STATE SIMULATION ]
                                                   (Core Component Systems)
```

1. **Server Authoritative**: El servidor ejecuta la simulación canónica del estado del juego. El cliente no decide resultados de lógica, combate o posición final.
2. **Client Prediction & Reconciliation**: Para una respuesta fluida, el cliente predice el resultado localmente y aplica reconciliación cuando llega el estado del servidor.
3. **Transport Layer Agnostic (ADR-0003)**: Las llamadas de red están abstraídas detrás de una interfaz `INetworkDriver`, permitiendo utilizar High-Level Multiplayer de Godot, WebSockets, ENet o protocolos custom.

---

## 🧩 Modelo Basado en Componentes y Datos (Component & Data Driven)

```
             ┌─────────────────────────────┐
             │       ENTIDAD (ID)          │
             └──────────────┬──────────────┘
                            │ Posee
       ┌────────────────────┼────────────────────┐
       ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Component A  │    │ Component B  │    │ Component C  │
│ (Data pure)  │    │ (Data pure)  │    │ (Data pure)  │
└──────────────┘    └──────────────┘    └──────────────┘
       ▲                    ▲                    ▲
       └────────────────────┼────────────────────┘
                            │ Procesado por
             ┌──────────────┴──────────────┐
             │       SISTEMAS (Logic)      │
             └─────────────────────────────┘
```

1. **Entidades**: Identificadores numéricos puros o nodos contenedores sin lógica pesada.
2. **Componentes**: Estructuras de datos pura (Resources o Dictionaries tipados) sin efectos secundarios.
3. **Sistemas**: Clases procesadoras de lógica que operan sobre listas de componentes.

---

## 📂 Organización de Capas en `game/`

```
game/
├── core/         # Sistemas primarios del motor (Network, State Manager, Event Bus, Save System)
├── modules/      # Módulos de dominio desacoplados (Movement, Inventory, Health, Combat)
├── shared/       # Constantes globales, Enums, Interfaces, Helper Functions
└── data/         # Schemas y Recursos (JSON, .tres, data tables)
```

### Regla de Dependencia Unidireccional:
`modules/` ──depende de──> `core/` y `shared/`  
`core/` ──depende de──> `shared/`  
`shared/` ──NO depende de nadie──  
`data/` ──utilizado por todos mediante loaders neutros──

---

## 🔒 Contratos de Interfaz

Todos los módulos deben exponer un archivo `interface.gd` o utilizar señales tipadas definidas en `shared/events/`. Queda prohibido llamar métodos privados directos en instancias de otros módulos.
