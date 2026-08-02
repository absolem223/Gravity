# RFC-0000 — Proceso Formal de Request for Comments (RFC)

- **Estado**: Aprobado
- **Fecha**: 2026-08-02
- **Autor**: Chief Software Architect

---

## 📌 Propósito

El sistema RFC (Request for Comments) es el mecanismo oficial mediante el cual desarrolladores humanos y agentes de IA proponen cambios estructurales, nuevos contratos de red o modificaciones arquitectónicas mayores en **PROJECT GRAVITY**.

---

## 🚦 ¿Cuándo es Obligatorio un RFC?

Un RFC es **estrictamente obligatorio** cuando:
1. Se modifica un contrato de datos entre componentes o módulos.
2. Se introduce un nuevo módulo principal en `game/modules/`.
3. Se altera el protocolo de red, serialización o sincronización.
4. Se propone migrar un script de GDScript a GDExtension (C++) (ADR-0001).
5. Se agrega una dependencia externa o librería al proyecto.

---

## 🔄 Flujo de Aprobación de un RFC

1. **Creación**: Copiar `docs/rfcs/TEMPLATE.md` a `docs/rfcs/XXXX-mi-propuesta.md`.
2. **Revisión**: El creador abre una PR etiquetada como `rfc`.
3. **Discusión**: Los agentes especializados y el Arquitecto leen el RFC, comentan y proponen ajustes.
4. **Resolución**:
   - **Aprobado**: Se asigna un número oficial, se genera un ADR en `docs/adrs/` si aplica, y se procede a la implementación.
   - **Rechazado**: Se archiva indicando los motivos en el documento.
