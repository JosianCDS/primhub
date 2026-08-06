---
name: flutter-idempiere-master-architect
description: Guía maestra arquitectónica (Enterprise-Level) para apps Flutter conectadas a iDempiere REST. Incluye patrones UI/UX avanzados, caché global, estrategias offline-first, CI/CD y resolución de problemas.
---

# Flutter + iDempiere — Arquitectura Maestra y Patrones de Desarrollo

Este proyecto es una aplicación **Flutter multi-plataforma** con conexión a un backend **REST**. Está diseñado específicamente para integrarse con el **API REST Estándar de iDempiere (Plugin org.idempiere.rest / OData compatible)**, operando sobre las rutas base `/api/v1/` (Models, Windows, Processes, Auth). Estas son las reglas obligatorias para escribir y mantener el código.

> **🤖 INSTRUCCIÓN CRÍTICA PARA EL AGENTE DE IA (Control de Alucinación y Scope)**:  
> Este documento es masivo y abarca integraciones de nivel corporativo. **Tu comportamiento como Agente debe regirse por estas 4 reglas inquebrantables**:
> 1. **Análisis de Scope (KISS)**: NO intentes implementar las soluciones de las secciones **14, 18, 19, 20 o 21** (Ej: Isar, Hive, WebSockets, Generación Dinámica de UI, Riverpod) **a menos que** el usuario lo pida explícitamente o el código actual ya lo exija. Usa siempre la solución más simple posible para el problema en curso.
> 2. **Lee y Mapea antes de escribir**: NUNCA alucines o asumas el contenido de un archivo por su nombre. Usa siempre tu herramienta para leer el archivo fuente completo ANTES de editar. Además, apóyate fuertemente en herramientas de análisis como **Graphify** para entender el mapa del código; si no está instalado, debes solicitar permiso explícito al usuario para instalarlo, explicándole su objetivo y cómo beneficiará la comprensión arquitectónica del proyecto.
> 3. **Preservación Estricta del Código**: Cuando edites o refactorices un archivo, **PROHIBIDO** borrar silenciosamente variables, métodos o lógicas de negocio que no entiendas. Conserva intacto todo el código que no esté directamente relacionado con tu tarea.
> 4. **Ante la Duda, Pregunta**: Si los requerimientos del usuario son ambiguos, o si la implementación entra en conflicto con las reglas de este documento, DETÉNTE y hazle una pregunta clara de opción múltiple al usuario antes de escribir código.

---

## 1. Estructura de carpetas

```text
lib/
  api/            → Capa de datos: HTTP, funciones de autenticación, caché global
  endpoint/       → Configuración de URLs del backend (Endpoints, Entornos)
  theme/          → Sistema de temas y colores de la app
  ui/
    shared/       → Widgets reutilizables propios del proyecto (NO usar Material directo si existe uno aquí)
    pages/        → Páginas organizadas por módulo: Home, Login, [ModuloX], etc.
    utils/        → Funciones de utilidad generales (formateadores, validadores, etc.)
```

**Reglas de organización:**
- Cada nueva página va en `lib/ui/pages/<modulo>/<nombre_pagina>.dart`.
- Si una página tiene lógica HTTP o de negocio compleja, separar en `<nombre>_logic.dart` o `<nombre>_functions.dart` en la misma carpeta.
- Los widgets reutilizables entre módulos van en `lib/ui/shared/`.
- Nombres de archivos: `snake_case.dart`. Nombres de clases: `PascalCase`.
- **Nunca** colocar lógica de negocio ni llamadas HTTP dentro de un `StatelessWidget` o directamente en el `build()`.

---

## 2. Convenciones de código Dart/Flutter

- Usar `const` constructors siempre que sea posible.
- Los `StatefulWidget` deben tener su estado privado: `_MiWidgetState`.
- Preferir `initState()` para cargar datos asíncronos iniciales; usar `if (!mounted) return;` antes de llamar `setState()` tras usar `await`.
- **No usar `debugPrint()`** en código nuevo de producción. Si usas logs, que sea a través de un gestor de logs (ej. `CurrentLogMessage`) o coméntalos con `// [Debug]`.
- Evitar `dynamic` cuando se conozca el tipo. Preferir `Map<String, dynamic>` para respuestas del API JSON.

---

## 3. Arquitectura y Capa API (Manejo de Tokens)

### 3.1 Manejo Global del Token
- `Token.auth` → Almacena el JWT actual en memoria (ej. `"Bearer <jwt>"`), listo para los headers.
- Al cerrar sesión, limpiar todos los tokens globales y variables estáticas de usuario.
- **Nunca** acceder al token directamente desde la UI; siempre usarlo en la capa API.

### 3.2 Refresco de Token: Validación Previa (Preemptive Validation)
Se implementa un mecanismo de "Refresco Eager". El token no se refresca esperando un error HTTP 401, sino **comprobando su vigencia localmente antes de cada petición protegida**.

1. **Variables Necesarias**:
   - Guardar en almacenamiento local (`SharedPreferences`) la fecha exacta de generación del token: `last_token_generated_at`.
   - Constante global de ventana de vida útil (ej. `_tokenReuseWindowMinutes = 40`).
2. **Función Validadora (`_canReuseCurrentToken`)**:
   - Revisa si `Token.auth` existe y si la diferencia entre `DateTime.now()` y `last_token_generated_at` es MENOR a la ventana de vida útil. Si es así, retorna `true` (token válido), de lo contrario `false`.
3. **Función Barrera (`usuarioAuth` o `authenticateRequest`)**:
   - **Toda** petición HTTP protegida debe ejecutar `await usuarioAuth(...)` antes de proceder.
   - Si `_canReuseCurrentToken()` es `true`, la barrera finaliza de inmediato.
   - Si es `false`, la barrera hace la petición POST para loguearse/refrescar. Si es exitosa, actualiza `Token.auth` y sobrescribe `last_token_generated_at` con el `DateTime.now()` actual. Si falla, cierra sesión.

---

## 4. Llamadas HTTP — Patrón estándar

Todas las llamadas al backend deben seguir esta estructura. Nota cómo se inyecta la función barrera antes de la petición principal:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
// Importar capa API, endpoints y auth...

Future<List<Map<String, dynamic>>> fetchDatosProtegidos({required BuildContext context}) async {
  try {
    // 1. Ejecutar función barrera antes de hacer cualquier cosa.
    await usuarioAuth(context: context, ...); 
    
    // 2. Realizar petición real con el token
    final uri = Uri.parse('${Endpoint.recurso}?\$filter=...&\$top=50');
    final response = await http.get(uri, headers: {
      'Authorization': Token.auth!,
      'Content-Type': 'application/json',
    });

    // 3. Manejar respuesta usando utf8.decode
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data['records'] ?? []);
    } else {
      // Manejar errores...
    }
  } catch (e) {
    if (e is http.ClientException) {
      handle401(context);
    }
  }
  return [];
}
```
- Siempre usar `utf8.decode(response.bodyBytes)` en lugar de `response.body` directo para evitar caracteres (acentos/ñ) corruptos.
- **Nunca** llamar a `http` directamente desde un widget.

---

## 5. Control de Acceso y Sesión

- **Siempre** usar un gestor de control de accesos (ej. `AccessControl`) para decisiones de visibilidad o permisos en la UI (ej. `if (AccessControl.isAdmin)`). Nunca comparar IDs quemados en el widget.
- Al detectar una expiración de sesión inevitable, redirigir centralizadamente a través de un `SessionManager` u organizador de rutas. **No** invocar el enrutador (`context.go('/login')`) crudo desde la capa API.

---

## 6. Endpoints y Entorno

- El entorno se gestiona mediante flags (ej. `Environment.isProduction`).
- Todas las URLs de la API se construyen desde variables/clases centrales (ej. `Endpoint.<recurso>`). **No hardcodear URLs como strings directos dentro de los métodos**.

---

## 7. Widgets compartidos — Regla de Reutilización

Siempre preferir los widgets internos del proyecto sobre los equivalentes de Material puros para mantener consistencia UI/UX:

- `CustomModal` para diálogos.
- `CustomButton` para acciones primarias/secundarias.
- `CustomTextField` o `CustomDropdown` para formularios.
- `CustomSkeleton` o `ShimmerList` para placeholders de carga (en vez de `CircularProgressIndicator` directos).
- `ToastMessage` o similar para notificaciones tipo snackbar.

---

## 8. Gestión de Estado y Ruteo (Reglas Generales)

- **Estado Local**: Usar `StatefulWidget` + `setState`. Para variables que se escuchan a través de varios widgets sin re-dibujar toda la página, preferir `ValueNotifier` + `ValueListenableBuilder`.
- **Enrutamiento**: Toda navegación debe hacerse a través del sistema de enrutamiento establecido en el proyecto (ej. `GoRouter` o push directos estandarizados). 
- Al limpiar controladores (`TextEditingController`, `ScrollController`, etc.), **siempre** hacerlo en el método `dispose()`.

---

## 9. Sistema de Temas

- Usar las clases centralizadas de temas (ej. `AppThemes.lightTheme`).
- **No hardcodear colores** hexadecimales quemados en los widgets. Usar `Theme.of(context).colorScheme.<propiedad>` u objetos de color predefinidos (ej. `ColorTheme.primary`).

---

## 10. Qué EVITAR (Anti-patrones estrictos)

- ❌ **No crear diálogos crudos con `AlertDialog`** directamente — usar los modales estandarizados del proyecto (`CustomModal`).
- ❌ **No crear botones o textfields crudos** perdiendo el diseño base — usar los componentes de la carpeta shared (`CustomButton`, `CustomTextField`, etc.).
- ❌ **No hardcodear URLs del backend** en los widgets ni armar strings quemados. Usar siempre el archivo central de `Endpoint`.
- ❌ **No realizar llamadas HTTP directamente en el `build()`** de un widget ni dentro de un `StatelessWidget`. Siempre delegarlo a un `StatefulWidget` en su `initState` o métodos específicos, o a un controlador externo.
- ❌ **No omitir el chequeo de `mounted`**. Después de cualquier `await` en un widget (como una petición HTTP), nunca llames a `setState()` sin verificar `if (!mounted) return;` para evitar fugas de memoria y crashes si el usuario cerró la pantalla.
- ❌ **No manejar la expiración de sesión (401) dispersa por toda la UI**. No llenes los widgets de `Navigator.push(Login)`. La intercepción de 401 y la redirección debe estar centralizada en la capa de red (`api_http.dart`) y un `SessionManager`.
- ❌ **No usar `Navigator.push` para pantallas principales**. Si la app usa `GoRouter`, usa siempre `context.go()` o `context.push()` para mantener el historial Web y las URLs limpias.
- ❌ **No traer tablas completas de iDempiere a ciegas**. Nunca hagas un `GET` a un modelo grande sin limitadores. Usa siempre `$select` para traer solo las columnas necesarias y `$top` para paginar, evitando colapsar la memoria del teléfono.
- ❌ **No asumir que un número en el JSON siempre será de tipo `int`**. iDempiere a veces envía `double` para campos numéricos. Al parsear IDs o montos, usa el casteo seguro: `(json['id'] as num?)?.toInt()`.
- ❌ **No decodificar JSON ignorando el Encoding**. Nunca uses `response.body` directo si hay riesgo de tildes o eñes. Usa siempre `utf8.decode(response.bodyBytes)`.
- ❌ **No dejar `debugPrint()` sueltos en producción**. Si necesitas loggear errores, usa el logger interno (ej. `CurrentLogMessage.add()`) que guarda el historial sin ensuciar la consola de release.

---

## 11. Referencia del API REST iDempiere (OData)

El backend de iDempiere expone un API REST que sigue convenciones tipo OData. Aquí se detallan los patrones principales extraídos de la colección de Postman:

### Endpoints de Autenticación (`api/v1/auth/`)
- `POST /tokens`: Iniciar sesión con `userName` y `password` (y opcionalmente el contexto: clientId, roleId, organizationId).
- `POST /refresh`: Obtener un nuevo token usando el `refresh_token`.
- `PUT /tokens`: Actualizar el token actual cambiando de rol, organización o almacén en la misma sesión.
- `POST /logout`: Invalidar y cerrar la sesión activa.

### Endpoints de Modelos (CRUD sobre tablas) (`api/v1/models/{table_name}`)
- **GET**: Consultar registros. Por defecto el tamaño de página es de 100 registros.
- **POST**: Crear un nuevo registro.
- **PUT**: Actualizar un registro existente.
- **DELETE**: Eliminar un registro.

### Parámetros de Consulta OData (Query Parameters)
Para refinar las consultas `GET` a las tablas, el API soporta los siguientes parámetros:
- **Filtros (`$filter`)**: Condicionales SQL-like. Ej: `?$filter=Name in ('106','PST') AND C_Tax_ID eq 106`.
- **Selección (`$select`)**: Limitar los campos/columnas devueltos en la respuesta. Ej: `?$select=Name,Description`.
- **Paginación (`$top` y `$skip`)**: `$top=50` limita la respuesta a 50 resultados, `$skip=10` ignora los primeros 10 resultados del query.
- **Relaciones (`$expand`)**: Permite anidar datos de tablas hijas o relacionadas en una sola petición. Ej: `?$expand=childTable($select=Name)`.
- **Validaciones (`$valrule` y `$context`)**: Filtrar la tabla usando una regla de validación del diccionario de iDempiere pasando un contexto.

### Otros Endpoints Relevantes
- **Procesos**: Se pueden ejecutar procesos de iDempiere remotamente.
- **Adjuntos (Attachments)**: Operaciones para leer, agregar o eliminar archivos adjuntos a los registros del ERP.
- **Metadata**: Endpoints como `/models` o `/auth/roles` sirven para consultar qué tablas, organizaciones y roles están disponibles para el cliente conectado.

### Ejemplos de Campos y Situaciones Comunes en iDempiere
Al consumir la API de iDempiere, los datos tienen estructuras características:
- **Foreign Keys (Listas desplegables/Relaciones)**: Los campos que referencian a otra tabla (ej. `C_BPartner_ID`) no devuelven un simple entero, sino un objeto con `id` e `identifier`.
  ```json
  "C_BPartner_ID": {
    "propertyLabel": "BPartner",
    "id": 1000000,
    "identifier": "Joe Perez",
    "model-name": "c_bpartner"
  }
  ```
  Al enviar datos (POST/PUT), normalmente debes enviar el ID envuelto en un objeto: `"C_BPartner_ID": {"id": 1000000}` (o según la configuración de tu endpoint, simplemente el entero).
- **Fechas**: Suelen venir en formato ISO-8601 (ej. `"DateInvoiced": "2024-05-10T00:00:00Z"`). Utiliza métodos de parseo de Dart (`DateTime.parse()`) antes de enviarlas a la UI.
- **Manejo de Errores Custom**: Algunas respuestas (ej. procesos o endpoints personalizados) pueden devolver una estructura `{"isError": true, "summary": "Mensaje"}` con Status 200 en lugar de depender únicamente del StatusCode HTTP 400/500. Siempre valida estos campos internos.
- **Campos de Sí/No (Booleanos iDempiere)**: iDempiere usa frecuentemente los caracteres `'Y'` y `'N'` en lugar de booleanos estrictos (`true`/`false`). Ej: En un query OData usarás `IsActive eq 'Y'`.

---

## 12. Librerías de Flutter (Recomendaciones y Usos Comunes)

Para resolver las necesidades de un ecosistema Flutter-iDempiere robusto, es altamente recomendable apoyar la arquitectura en las siguientes herramientas (utilizadas ampliamente en este tipo de proyectos):

- **`http`**: Para la comunicación cruda con la API REST (combinado con tu propia clase interceptora de 401, como vimos en `api_http.dart`).
- **`shared_preferences`**: Para la persistencia de datos ligeros de sesión como tokens JWT, IDs de roles, organizaciones y configuraciones estáticas del usuario logueado.
- **`go_router`**: Para un enrutamiento declarativo, seguro (permite usar *redirects* o *guards* para proteger rutas cuando no hay sesión) y apto para aplicaciones web/desktop.
- **`shimmer` o `skeletonizer`**: Para crear efectos de carga elegantes en listas (esqueletos de tarjetas) mientras la API de iDempiere responde con los grandes volúmenes de datos.
- **`file_picker` y `cross_file`**: Indispensables si tu aplicación requiere interacción con los endpoints de **Adjuntos** (Attachments) de iDempiere, especialmente para soportar la subida y descarga fluida tanto en Web como en Mobile.
- **`toastification` (o equivalente)**: Para dar feedback rápido y no intrusivo al usuario sobre el éxito o fracaso de las operaciones CRUD (ej. "Registro guardado correctamente").

---

## 13. Patrones de Diseño de UI y UX (Frontend)

El frontend de una aplicación o portal conectado a iDempiere debe sentirse profesional, reactivo y claro. Aplica estos patrones de diseño que ya han demostrado éxito en este ecosistema:

- **Empty States (Estados Vacíos) Amigables**: Si un query OData `$filter` no devuelve registros, **nunca** dejes una pantalla blanca. Muestra siempre una ilustración o icono tenue junto con un texto descriptivo claro (ej. *"No hay solicitudes activas en este momento"*).
- **Carga Diferida y Esqueletos (Skeletons)**: No bloquees la pantalla con un spinner estático (`CircularProgressIndicator`) al centro. Muestra la estructura de la página (AppBar, Menús) y dibuja tarjetas parpadeantes o "CustomSkeletons" en el área de contenido mientras esperas la red. Da sensación de mayor velocidad.
- **Modales Seguros y Descriptivos**: Para acciones destructivas (Eliminar, Cancelar Documento) o de cambio de estado importante, usa Modales centrales que oscurezcan el fondo, siempre con botones de acción explícitos: "Confirmar" (destacado) y "Cancelar" (secundario o outline).
- **Tematización Dinámica y Precisa (Light/Dark Mode)**: Soporta modo oscuro. Usa un `ValueNotifier` global acoplado a `MaterialApp`. Asegúrate de que todos los colores provengan estrictamente de `Theme.of(context).colorScheme` y evita "hardcodear" grises arbitrarios que arruinarían la lectura nocturna.
- **Consistencia e Interacción en Formularios**:
  - Indica claramente los campos obligatorios.
  - Al presionar un botón de envío ("Guardar"), cambia su estado a `isLoading = true` (mostrando un pequeño spinner dentro del botón) y **desactiva su función de clic** inmediatamente para prevenir envíos duplicados al backend por "doble toque".
- **Layout Adaptable (Desktop-First / Responsive)**: Los ecosistemas de iDempiere (ERPs, portales B2B) suelen consumirse intensamente en monitores de oficina (Web/Desktop). Limita el ancho máximo de tus vistas y formularios usando contenedores centrados (ej. `maxWidth: 1200`) para evitar que la UI se estire de borde a borde y abrume la vista en pantallas ultra-anchas.
- **Límite de Complejidad por Archivo (Max ~650 líneas)**: Para mantener el código limpio, mantenible y escalable, si el archivo de un Widget o Pantalla supera las 600-650 líneas, es una señal estricta de que debes detenerte y refactorizar. Extrae sub-componentes a una subcarpeta `widgets/` o delega su lógica (estado, peticiones HTTP) a un archivo `<nombre>_logic.dart`.

---

## 14. Sugerencias Generales (No Obligatorias)
Estas son recomendaciones de "buenas prácticas" arquitectónicas y visuales, cuya implementación debe ser evaluada por el desarrollador líder según las necesidades del proyecto:

- **Estructura de Carpetas Sugerida (Feature-First vs Layer-First)**: Aunque la estructura base recomendada es por capas (`api`, `ui/pages`, etc.), para proyectos masivos se sugiere un enfoque mixto "Feature-First": `lib/features/support/`, `lib/features/projects/`, donde cada módulo tenga sus propios widgets, lógica y modelos, compartiendo solo lo esencial en `lib/core/`.
- **Patrones de UI/UX Expandidos**:
  - **Animaciones sutiles**: Usar animaciones en transiciones (ej. `AnimatedSwitcher` o el cross-fade del ruteador) para que los cambios de estado (cargando -> vacío -> datos) no sean tan bruscos a la vista.
  - **Manejo de Formularios Largos**: iDempiere tiene ventanas con muchísimos campos. Sugerencia: agrupar los formularios en pestañas (`TabBar`) o pasos secuenciales (`Stepper`) en vez de una lista vertical infinita.
  - **Caché Local Fuerte**: Para datos de catálogos estáticos (países, regiones, monedas), evaluar usar bases de datos locales robustas (`hive`, `sqflite` o `isar`) en vez de recargarlos vía HTTP en cada inicio.
- **Librerías Adicionales**: 
  - `dio` en lugar de `http` si el equipo prefiere un manejo sumamente avanzado de interceptores globales (colas de peticiones bloqueadas esperando refresco de sesión, cancelación de requests).
  - Gestores de Estado Global (`Riverpod`, `Bloc` o `Provider`) en lugar de `StatefulWidget` puro si el proyecto requiere reactividad profunda entre módulos totalmente independientes.

---

## 15. Métodos de Resolución de Errores (Troubleshooting Básico)
Cuando la comunicación entre Flutter y el REST de iDempiere falla en el entorno Web/Desktop, revisa estos puntos (ideales para descartar problemas comunes que hacen perder tiempo):

- **Caché del Navegador**: Si el login falla sin razón aparente o el token parece estancado en un bucle de expiración 401 que te expulsa de inmediato, realiza un **Hard Reload** (Ctrl+F5 o Cmd+Shift+R) o usa la opción *"Empty Cache and Hard Reload"* del navegador. 
- **Application Storage (Falsos 401)**: A veces credenciales corruptas sobreviven al refresco. Ve a las DevTools de Chrome -> *Application* -> *Storage* -> **Clear site data**. Al darle clic, obligarás a la app a iniciar de cero.
- **Pestaña Network (Red)**: Siempre que haya un error de datos o un `Format Exception` (JSON inválido), abre la pestaña *Network*, filtra por `Fetch/XHR` y verifica de inmediato:
  - ¿Qué *Request Method* se usó en *Headers*? (A lo mejor se pedía un `PUT` y la app está mandando un `POST`).
  - ¿El body enviado (*Payload*) iba bien estructurado en JSON válido?
  - ¿Qué texto exacto devolvió la pestaña *Response*? (iDempiere suele devolver un HTML de error del servidor Apache Tomcat en vez de un JSON cuando la URL está mal escrita o hay error 500).
- **Consola de Red Efímera**: Activa la casilla **"Preserve log"** en la pestaña *Network*. Así evitarás que una redirección repentina en la app (como un cierre de sesión automático forzado) te borre del historial la petición original que fue la que causó el fallo.

---

## 16. Optimización del Agente de IA: Uso de Graphify

Para mantener la calidad y consistencia del código a gran escala en proyectos de este tipo, se **recomienda fuertemente el uso e instalación de `graphify`**.

- **¿Qué es Graphify?**: Es una herramienta (CLI/MCP) que escanea el proyecto de Flutter y genera un grafo de conocimiento detallado de la arquitectura actual. Esto le permite al Agente de IA comprender exactamente cómo se conectan las clases, widgets compartidos y funciones de la API en todo el ecosistema antes de proponer código nuevo.
- **¿Por qué usarlo?**: Evita que el agente "adivine" o "alucine" cómo se llama el widget del botón primario, o dónde se aloja la lógica del token. Con graphify activo, el agente navega el proyecto como si estuviera viendo un mapa satelital.
- **Sugerencias de Uso**: 
  - Ejecutar `graphify update .` regularmente tras sesiones de refactorización grandes o creación de nuevos módulos.
  - Sugerir al agente IA que lea el reporte generado (`graphify-out/GRAPH_REPORT.md` o use el MCP de queries) siempre que se le pida analizar problemas arquitectónicos o referenciar componentes globales.

---

## 17. Prácticas Avanzadas y Arquitectura de Despliegue

### Conceptos Adicionales de Alto Nivel
- **Mapeo Fuerte de Datos (`json_serializable` / `freezed`)**: En proyectos inmensos, evita mapear a mano (ej. `json['id']`). Usa generadores de código para que el IDE autocompleta los campos traídos desde iDempiere y garantice su tipo.
- **Manejo del CORS Localmente**: Al desarrollar Web contra una API REST externa, el CORS suele bloquear las pruebas locales. Evalúa lanzar Chrome con `--disable-web-security` temporalmente o levantar un proxy local.
- **Variables de Entorno Estrictas**: Extraer siempre las IPs o URLs a archivos `.env` (con `flutter_dotenv`) o usando parámetros de compilación (`--dart-define`) para cambiar fluidamente de entornos Dev/Test/Prod.

### Despliegue y Control de Caché en Producción (appConstructor.sh)

En aplicaciones Flutter Web, uno de los problemas más críticos es que el navegador guarda en caché el gran archivo `main.dart.js`, provocando que los usuarios no vean los cambios tras un despliegue.

Para solventarlo, se utiliza un script automatizado que "destruya" (cache-busting) la caché forzando un parámetro de versión y desregistre los Service Workers antiguos. A continuación, el script de compilación estándar sugerido para estos ecosistemas:

#### Archivo: `appConstructor.sh`

```bash
#!/bin/bash
set -euo pipefail

BUILD_DIR="build/web"
INDEX_FILE="$BUILD_DIR/index.html"
VERSION=$(date +%Y%m%d%H%M%S)
SNIPPET_FILE="$BUILD_DIR/__version_snippet__.html"
TMP_FILE="$INDEX_FILE.tmp"

echo "Limpiando proyecto..."
flutter clean

echo "🏗️  Compilando con versión: $VERSION..."
echo "const String appBuildVersion = '$VERSION';" > lib/build_version.dart
flutter build web --release --pwa-strategy=none --dart-define=APP_VERSION=$VERSION --no-tree-shake-icons
if [ ! -f "$INDEX_FILE" ]; then
  echo "Error: No se encontró $INDEX_FILE"
  exit 1
fi

echo "Aplicando versión en flutter_bootstrap.js..."
# Reescribe cualquier <script src="flutter_bootstrap.js..."> para meter ?v=VERSION
awk -v ver="$VERSION" '{
  gsub(/<script src="flutter_bootstrap\.js[^"]*"/,
       "<script src=\"flutter_bootstrap.js?v=" ver "\"");
  print
}' "$INDEX_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INDEX_FILE"

echo "Aplicando versión a main.dart.js dentro de flutter_bootstrap.js..."
sed -i "s/main\.dart\.js/main.dart.js?v=$VERSION/g" "$BUILD_DIR/flutter_bootstrap.js"

echo "Eliminando bloque previo de versión (si existiera)..."
# Borra el bloque entre marcadores (multilínea) si existía
perl -0777 -pe 's/<!-- BUILD_VERSION_START -->.*?<!-- BUILD_VERSION_END -->\n?//s' \
  -i "$INDEX_FILE"

echo "Creando snippet de AUTO-UPDATE..."
cat > "$SNIPPET_FILE" <<EOF
<!-- BUILD_VERSION_START -->
<script>
(function () {
  var currentVersion = "$VERSION";
  var prev = localStorage.getItem('app_build');
  var alreadyReloaded = sessionStorage.getItem('__app_auto_reloaded__') === '1';

  function unregisterAllAndReload() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function(regs) {
        for (var i = 0; i < regs.length; i++) {
          regs[i].unregister();
        }
      }).catch(function() {});
    }
    
    if (!alreadyReloaded) {
      sessionStorage.setItem('__app_auto_reloaded__', '1');
      window.location.reload(true);
    }
  }

  if (!prev) {
    localStorage.setItem('app_build', currentVersion);
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function(regs) {
        for (var i = 0; i < regs.length; i++) { regs[i].unregister(); }
      });
    }
  } else if (prev !== currentVersion) {
    localStorage.setItem('app_build', currentVersion);
    unregisterAllAndReload();
  } else {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function(regs) {
        for (var i = 0; i < regs.length; i++) { regs[i].unregister(); }
      });
    }
  }
})();
</script>
<!-- BUILD_VERSION_END -->
EOF

echo "Insertando snippet antes de </body>..."
# Inserta el snippet justo antes de </body>. Si no hay </body>, lo agrega al final.
awk -v file="$SNIPPET_FILE" '
BEGIN{inserted=0}
{
  if (!inserted && /<\/body>/) {
    system("cat " file);
    inserted=1;
  }
  print;
}
END{
  if (!inserted) {
    system("cat " file);
  }
}
' "$INDEX_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INDEX_FILE"

rm -f "$SNIPPET_FILE"

echo "Versión $VERSION aplicada y auto-update habilitado en $INDEX_FILE."
echo "Proceso completo."
```

#### ¿Qué hace este script?
1. **Genera una Versión Única**: Usa la fecha y hora exacta (`$VERSION`) para estampar la compilación.
2. **Inyección en Dart**: Sobrescribe un archivo Dart estático y usa `--dart-define` para que la app conozca su propia versión y la imprima visualmente (ej. en el footer).
3. **Cache-Busting (Busteo de Caché)**: Modifica agresivamente los scripts clave de Flutter en `index.html` (ej. `main.dart.js?v=$VERSION`) obligando a los navegadores web a descargar el archivo nuevo.
4. **Aniquilación del Service Worker**: Deshabilita la precarga nativa antigua de PWA desregistrando el serviceWorker (sumado a `--pwa-strategy=none`).
5. **Auto-Recarga por JavaScript**: Inyecta un `<script>` al final del `<body>`. Cuando el cliente abre la URL, compara el *build* recién bajado con el que el cliente guardó en el `localStorage`. Si son distintos, el script asume que hubo un update en el servidor, limpia workers rebeldes y **hace un `window.location.reload(true)` automático**. Garantiza que el usuario reciba la UI actualizada 0.1 segundos después de entrar, sin intervención técnica.

**Comando Estricto de Producción**:
Nunca usar el build convencional, ejecutar siempre:
```bash
./appConstructor.sh
```

---

## 18. Recetas Avanzadas para ERPs (iDempiere)
Cuando el proyecto escale a niveles empresariales, estos son tres patrones avanzados que deberás considerar implementar:

- **Paginación Infinita (Infinite Scrolling)**: Dado que iDempiere limita los queries OData a 100 registros por defecto (`$top`), no intentes forzar descargar 10,000 facturas de golpe. Acopla un `ScrollController` a un `ListView.builder`. Cuando el usuario llegue al 90% de la lista, dispara una petición al backend incrementando el parámetro `$skip` (ej. `$skip=100`, luego `$skip=200`) para inyectar la siguiente "página" de datos de forma indetectable para el usuario.
- **Subida de Adjuntos (Multipart/Base64)**: Al lidiar con el endpoint nativo de Attachments de iDempiere (frecuentemente ligado a `AD_Attachment`), enviar archivos (PDFs o imágenes) desde Flutter Web y Mobile en simultáneo suele ser conflictivo. Estandariza la subida usando `http.MultipartRequest` (o `dio`), asegurando pasar correctamente el `Record_ID`, la tabla destino (`AD_Table_ID`) y el binario con los headers de autorización intactos.
- **Internacionalización Dinámica (i18n)**: iDempiere soporta nativamente múltiples idiomas mediante sus tablas de traducción (`_Trl` y `AD_Message`). Si tu portal lo exige, decide tempranamente si descargarás las etiquetas dinámicas de iDempiere al momento del Login y las guardarás en caché local, o si traducirás todo estáticamente usando el ecosistema estándar de Flutter (`intl` y archivos `.arb`).
- **Renderizado de UI Dinámica (Metadatos)**: Escribir formularios a mano para un ERP con cientos de ventanas no es escalable. iDempiere permite consumir la metadata de sus ventanas (`AD_Window`, `AD_Tab`, `AD_Field`). Una práctica nivel "Experto" es crear un generador de formularios en Flutter que lea ese JSON y dibuje automáticamente los `CustomTextField` y `CustomDropdown` según si el campo es obligatorio, de solo lectura o numérico.
- **Caché Global de Lookups (Listas Desplegables)**: Los formularios de iDempiere consumen muchísimas listas de selección (Países, Tipos de Documento, Impuestos). Nunca dispares un HTTP GET por cada dropdown cada vez que se abre un formulario. Descarga los *Lookups* clave al iniciar la app, guárdalos en un singleton (como un `GlobalCache`) y alimenta los selectores desde la memoria RAM.
- **Offline-First y Sincronización Diferida**: Si la aplicación va a ser usada por operarios en zonas sin red (almacenes profundos, vendedores en ruta), guarda los catálogos en una DB local (SQLite/Isar/Hive). Guarda las transacciones del usuario localmente con un flag `is_synced = false` y diseña un proceso en segundo plano (*Background Worker*) que envíe masivamente todos los `POST` a iDempiere apenas detecte que el dispositivo recuperó el internet.
- **Notificaciones en Tiempo Real (WebSockets / SSE)**: Si necesitas alertas instantáneas en Flutter (ej. "Nueva solicitud de soporte"), evita saturar iDempiere con *Long-Polling* (hacer peticiones `GET` cada 5 segundos). Implementa WebSockets o Server-Sent Events (SSE) y escúchalos pasivamente usando paquetes como `web_socket_channel`.

---

## 19. Integraciones Empresariales (Opcionales / Poco Frecuentes)
Estas implementaciones son de muy alta complejidad técnica y deben quedar **100% a criterio del desarrollador líder** según los requerimientos corporativos críticos. No son obligatorias para un proyecto estándar:

- **Autenticación SSO / OAuth2 (Google/Microsoft)**: Sustituye el login clásico por identidades federadas. Implica recibir el token OAuth en Flutter y enviarlo a un proceso personalizado de iDempiere que valide contra el directorio activo y genere un JWT válido para el ERP.
- **Notificaciones Push (Firebase Cloud Messaging - FCM)**: Para recibir notificaciones push reales en el celular (ej. "Orden pendiente de aprobación"). Requiere configurar Firebase en Flutter y crear un *Callout* en iDempiere que dispare un Webhook hacia el API de FCM cuando ocurra un evento.
- **Deep Linking y Enrutamiento Universal**: Permite que un enlace de correo (ej. `https://erp.tuempresa.com/invoice/1005`) abra directamente una pantalla específica en la App (saltándose el menú). Requiere configuración avanzada en `go_router` y en los manifiestos de Android/iOS/Web, además de manejo de redirección si no hay sesión viva.
- **CI/CD (Integración y Despliegue Continuo Automático)**: Escalar el script `appConstructor.sh` acoplándolo a GitHub Actions o GitLab CI. El objetivo es que cada *push* a la rama `main` compile el proyecto en la nube y lo despliegue vía SSH/FTP al servidor web, eliminando la compilación manual.

---

## 20. Motores de Base de Datos Locales (Estrategias Offline-First)
Derivado del punto de uso sin conexión, cuando debas almacenar volúmenes masivos de datos (catálogos, listas de precios, facturas pendientes) para que la app resista la falta de internet, debes elegir un motor local. Aquí la comparativa para tomar la decisión arquitectónica correcta:

### 1. Hive (Clave-Valor / NoSQL Rápido)
- **Cómo funciona**: Guarda los datos en formato binario usando pares de Clave y Valor. No usa tablas ni relaciones.
- **Beneficios**: Es increíblemente veloz para lectura/escritura y fácil de implementar (no hay que escribir SQL).
- **Situación ideal**: Perfecto para guardar cachés simples de respuestas HTTP (como listas desplegables), configuraciones de usuario o tokens de sesión. Si los datos de iDempiere son simples JSON que solo necesitas guardar y recuperar rápidamente sin cruzarlos, Hive es el rey.

### 2. Isar (Base de Datos de Objetos Avanzada)
- **Cómo funciona**: Sucesora espiritual de Hive, almacena objetos Dart fuertemente tipados permitiendo búsquedas estructuradas y creación de índices múltiples.
- **Beneficios**: Es altamente asíncrona, soporta búsquedas de texto completo (Full-Text Search) muy rápidas y maneja enlaces/relaciones entre objetos nativamente.
- **Situación ideal**: Ideal para apps como "Puntos de Venta (POS) Móviles". Si necesitas descargar 50,000 productos desde iDempiere y permitirle al vendedor buscar por código de barras o nombre en 0.1 segundos estando sin internet, Isar es la opción más moderna y robusta.

### 3. SQLite (Relacional / SQL Clásico)
- **Cómo funciona**: Una base de datos relacional tradicional en el dispositivo, manejada mediante consultas SQL puras (usando el paquete `sqflite`).
- **Beneficios**: Universal, confiable y permite lógicas de consulta extremadamente complejas (`JOIN`, `GROUP BY`, `SUM`) directo en el dispositivo.
- **Situación ideal**: Úsalo si tu aplicación es literalmente un "Mini-ERP Offline" y necesitas cruzar datos entre la tabla Clientes, Pedidos e Impuestos para generar un reporte analítico local antes de sincronizar. Requiere un equipo con sólida experiencia en modelado relacional y sentencias SQL, y su configuración inicial es más verbosa.

---

## 21. Calidad Automática de Código (Testing & Linting - Opcional)
*(Estrategia no obligatoria de escalabilidad, a criterio estricto del desarrollador líder)*

En ecosistemas masivos como un ERP, depender puramente de la revisión humana es un riesgo. Si decides escalar el proyecto a este nivel, asegura la calidad implementando estos dos pilares:

### 1. Linting Estricto (`analysis_options.yaml`)
- **Implementación**: No te conformes con las reglas de Dart por defecto. Usa paquetes con conjuntos de reglas agresivas como `very_good_analysis` o configura el paquete `flutter_lints` al máximo nivel.
- **Objetivo**: Obligar al IDE (y a la IA) a marcar como error variables sin usar, imports innecesarios, constructores no constantes y funciones sin tipo de retorno. Esto estandariza la escritura del código sin importar qué programador toque el archivo, manteniendo el repositorio completamente inmaculado.

### 2. Estrategia Pragmática de Pruebas (Testing)
Hacer pruebas "End-to-End" para 500 pantallas de un ERP es inviable para la mayoría de los equipos. Usa esta estrategia pragmática:
- **Unit Tests**: Obligatorios **solo** para los modelos matemáticos (cálculos de impuestos, subtotales), lógicas complejas de parseo de JSONs que vengan de iDempiere, y la barrera del Token / Autenticación.
- **Widget Tests**: Obligatorios **solo** para los componentes base en la carpeta `lib/ui/Shared_Custom/`. Si garantizas mediante código que tu `CustomTextField` y tu `CustomModal` jamás se van a romper por un cambio futuro, erradicarás el 90% de los bugs visuales del proyecto.
