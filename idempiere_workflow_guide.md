# Guía de Arquitectura Híbrida: Motor de Correos Primhub + iDempiere

## Objetivo
Detallar la arquitectura híbrida implementada para el envío automático de correos en Primhub, que combina el poder visual de **Flutter (generación de HTML)** con la robustez transaccional y gestión de adjuntos del backend de **iDempiere (proceso sendmailtextcds de TrekGlobal/Lirion)**.

Esta arquitectura resuelve las limitaciones nativas de plantillas de iDempiere (que no permiten diseño moderno, condicionales complejos o mapeo fluido de estados) y asegura que cualquier archivo subido por el usuario se envíe físicamente en el correo.

---

## 1. El Proceso en iDempiere (`sendmailtextcds`)

Para que el envío funcione, la instancia de iDempiere debe tener instalado el plugin personalizado de Lirion (`com.cdsoftware.lirion.utils`) que expone el proceso **"Enviar Texto Mail Lirion"** (`sendmailtextcds`).

Este proceso acepta un JSON simple desde Flutter y **se encarga de hacer el envío físico del correo** utilizando el servidor SMTP configurado en iDempiere.

**Parámetros críticos que acepta el proceso:**
* `AD_UserTo_ID`: El ID del usuario destino.
* `IsHtmlBody`: Se envía en `Y` para aceptar HTML puro.
* `MailSubject`: El asunto del correo (procesado en Flutter).
* `MailBody`: El HTML completo del correo (generado y procesado en Flutter).
* `TableName`: La tabla contra la cual se ejecutará el envío.
* `recordID`: El ID del registro de la tabla.

---

## 2. El Motor de Plantillas en Flutter (`EmailTemplates`)

En lugar de usar las plantillas de la ventana `EMail Template` en iDempiere, todo el diseño y mapeo de variables mágicas ocurre en la app.

El archivo `lib/ui/pages/Support/Requests/email_templates.dart` actúa como el único motor de correos:
1. **Diseño Pixel-Perfect:** Contiene el diseño exacto de Primhub (Modo Claro, fondos `#F3F4F6`, bordes redondeados y tipografía Poppins).
2. **Tablas para Clientes de Correo:** Usa estructuras HTML de tablas (`<table>`) para garantizar que Gmail y Outlook alineen y rendericen correctamente elementos complejos (como la transición de `[Estado Viejo] ➔ [Estado Nuevo]`).
3. **Variables Listas:** Como Flutter tiene acceso a `GlobalCache`, puede traducir instantáneamente IDs a nombres reales (nombres de usuario, nombres de estados, etc.) e insertarlos en el HTML sin depender de etiquetas `@` de iDempiere.

---

## 3. El Truco Maestro de los Adjuntos

Cuando un usuario sube archivos a una actualización en la app, estos archivos se guardan en la tabla **`R_RequestUpdate`** de iDempiere, NO en `R_Request`.

**El problema:** Si le decimos al proceso de iDempiere que mande un correo sobre `R_Request` (la cabecera del ticket), iDempiere ignorará los adjuntos recién subidos en la actualización.

**La Solución Híbrida (El Truco Maestro):**
1. La función `createRequestUpdate` en Flutter sube el texto y los adjuntos a iDempiere y **retorna el ID de la nueva actualización (`newRecordId`)**.
2. Al disparar `sendRequestStatusEmail`, si se cuenta con el ID de la actualización, se inyectan dinámicamente estos parámetros al proceso `sendmailtextcds`:
   * `TableName = "R_RequestUpdate"`
   * `recordID = <UpdateId>`

Al ejecutarse el proceso en Java en el backend, iDempiere instanciará el objeto de la actualización (`R_RequestUpdate`), leerá sus adjuntos físicos, y los enviará automáticamente embebidos en el correo junto con nuestro hermoso diseño HTML.

---

## 4. Flujo Resumido

1. El usuario guarda un cambio o envía una actualización en Primhub.
2. Flutter se comunica con el backend y guarda los registros/archivos.
3. Flutter ejecuta `EmailTemplates.buildRequestUpdateEmail(...)` e inyecta toda la información (usuario, estados, texto nuevo, colores).
4. Flutter hace un POST a `/api/v1/processes/sendmailtextcds`:
   ```json
   {
     "AD_UserTo_ID": 1000001,
     "MailSubject": "Actualización en solicitud: 1004389",
     "IsHtmlBody": "Y",
     "MailBody": "<div style='...'>...</div>",
     "TableName": "R_RequestUpdate", 
     "recordID": "10599" 
   }
   ```
5. El servidor SMTP de iDempiere recibe la orden, toma el HTML, busca en `R_RequestUpdate` los adjuntos, y despacha el correo al destino final.

> [!TIP]
> **Mantenimiento Futuro**
> Si en el futuro se desea cambiar el color corporativo, el logotipo o la firma del correo, **solamente** se debe modificar la clase estática en `email_templates.dart`. No hay que tocar la base de datos de iDempiere.
