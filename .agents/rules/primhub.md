---
trigger: always_on
---

## primhub — Reglas de personalización del agente

Primhub es una aplicación **Flutter multi-plataforma** (desktop-first) para gestión de horas de soporte, entregables, cotizaciones y métricas. Se conecta contra un backend **iDempiere/REST** (OData-style).

---

## 1. Estructura de carpetas

```
lib/
  api/            → Capa de datos: HTTP, autenticación, caché global, control de acceso
  endpoint/       → Configuración de URLs del backend (Endpoint, Envirioment, PostMedia)
  theme/          → Sistema de temas y colores de la app
  ui/
    Shared_Custom/  → Widgets reutilizables propios del proyecto (NO usar Material directos si existe uno aquí)
    pages/          → Páginas organizadas por módulo: Home, Login, Support, Projects, Metrics, OnDevelop
    widgets/        → Widgets de utilidad generales (duration_formatter, etc.)
```

**Reglas de organización:**
- Cada nueva página va en `lib/ui/pages/<Módulo>/<NombrePágina>.dart`.
- Si una página tiene lógica compleja, separar en `<nombre>_logic.dart` dentro de la misma carpeta.
- Los widgets reutilizables entre módulos van en `lib/ui/Shared_Custom/`.
- Nombres de archivos: `snake_case.dart`. Nombres de clases: `PascalCase`.
- **Nunca** colocar lógica de negocio ni llamadas HTTP dentro de un `StatelessWidget` o directamente en el `build()`.

---

## 2. Convenciones de código Dart/Flutter

- Usar `const` constructors siempre que sea posible.
- Los `StatefulWidget` deben tener su estado privado: `_MiWidgetState`.
- Preferir `initState()` para cargar datos asíncronos; usar `mounted` antes de llamar `setState()` tras awaits.
- **No usar `debugPrint()`** en código nuevo — los logs existentes están marcados con `// [Mantenimiento] Log removido:`. Si necesitas debug temporal, comentar con esa misma etiqueta al terminar.
- Evitar `dynamic` cuando se conozca el tipo. Preferir `Map<String, dynamic>` para respuestas del API.
- Al parsear IDs numéricos de respuestas JSON, usar el patrón: `(val as num?)?.toInt()` — el backend puede devolver `int` o `double`.

---

## 3. Arquitectura y capa API

### Token y autenticación
- `Token.auth` → JWT actual. `Token.token` → `"Bearer <jwt>"` listo para headers.
- `Token.clear()` borra todas las credenciales. Llamar junto con `GlobalCache.clear()` al cerrar sesión.
- `User` (en `token.dart`) guarda nombre, email, `cBPartnerID` y `userID` del usuario logueado.
- **Nunca** acceder al token directamente desde la UI; siempre a través de `Token.token` como header.

### GlobalCache
- Es la fuente de verdad en memoria para: `requests`, `projects`, `bPartners`, `users`, `statuses`, `requestTypes`, `categories`, `groups`, `salesReps`, `productChips`.
- Se inicializa en dos fases:
  - **Fase 1** (`syncData()`): bloqueante, carga lo mínimo para que el Home funcione.
  - **Fase 2**: en background, carga histórico de 4 años.
- Para refrescar datos puntuales usar `GlobalCache.syncSingleRequest(id)` en vez de forzar un `syncData(force: true)` completo.
- Escuchar cambios reactivos mediante `GlobalCache.backgroundSyncNotifier` (es un `ValueNotifier<bool>`).
- Para proyectos, usar `GlobalCache.loadProjectRequestsInBackground(projectId)` — maneja deduplicación y Completers automáticamente.

### AccessControl
- **Siempre** usar `AccessControl` para decisiones de visibilidad/permisos en la UI. Nunca comparar UUIDs de roles directamente en widgets.
- Roles reales (del JWT): `isRealAdmin`, `isRealSupport`, `isRealProject`.
- Roles efectivos para UI (respetan el modo de vista admin): `isAdmin`, `isSupport`, `isProject`.
- Capacidades clave:
  - `canEditProject`, `canCreateProjectItems`, `canManageFiles` → solo Admin.
  - `canCreateRequests` → Admin o Soporte real.
  - `canAddUpdates` → solo Admin.
  - `canDownloadFiles`, `canViewRequestDetails` → todos.
- Uso típico en widget: `if (AccessControl.canManageFiles) ... else ...`

### AdminViewMode
- Los admins pueden simular vistas de Soporte/Proyecto mediante `AdminViewModeManager`.
- Modes: `AdminViewMode.mixed`, `.support`, `.project`.
- Para verificar el modo actual: `AdminViewModeManager().currentMode`.
- Para guardar el modo: `AdminViewModeManager().saveMode(mode)` (persiste en `SharedPreferences`).

### SessionManager
- `SessionManager.navigatorKey` debe estar asignado al `MaterialApp.router` (ya está en `app.dart`).
- Al detectar 401/403 del backend, llamar `SessionManager().showSessionExpiredDialog()` — redirige al login y muestra diálogo no descartable.
- **No** llamar `GoRouter.of(context).go('/login')` directamente desde la capa API; usar siempre `SessionManager`.

### Endpoint y entorno
- `Envirioment.isProduction = false` → staging (`primhub.primware.net`). `true` → producción (`erp.primware.net`).
- Todas las URLs de la API se construyen desde `Endpoint.<recurso>`. **No hardcodear URLs**.
- Para subir archivos usar `PostMedia(recordID: id, tableName: 'NombreTabla').endPoint`.

---

## 4. Widgets compartidos (Shared_Custom) — Obligatorios

Siempre preferir estos widgets sobre los equivalentes de Material:

| Widget | Uso |
|---|---|
| `CustomModal` | Todos los diálogos/modales. Parámetros: `title`, `content`, `actions`, `width`, `height`, `scrollable`. Ancho por defecto: 400. |
| `CustomButton` | Todos los botones de acción. Soporta `isLoading`, `icon`, `backgroundColor`. |
| `CustomTextField` | Todos los campos de texto. Soporta `inputFormatters`, `validator`, `maxLines`. |
| `CustomDropdown<T>` | Todos los selects/dropdowns. Genérico. |
| `CardCustom` | Tarjetas con estilo unificado del sistema. |
| `CustomContainer` | Contenedores con decoración consistente. |
| `CustomSkeleton` | Placeholder de carga (shimmer). Usar mientras se cargan datos. |
| `CustomTable` | Tablas simples. Para tablas de solicitudes usar `RequestsDataTableCore`. |
| `ToastMessage` | Notificaciones toast. Usar en lugar de `SnackBar` para feedback de acciones. |
| `HelpIcon` | Ícono de ayuda con tooltip. |

**Cómo mostrar un modal:**
```dart
showDialog(
  context: context,
  builder: (_) => CustomModal(
    title: 'Título',
    width: 500,
    content: /* tu widget */,
    actions: [
      CustomButton(text: 'Cancelar', onPressed: () => Navigator.of(context).pop()),
      CustomButton(text: 'Confirmar', onPressed: _onConfirm),
    ],
  ),
);
```

---

## 5. Routing con go_router

- El router vive en `lib/app.dart`. Para agregar una nueva ruta, editar `_router` en ese archivo.
- Usar `NoTransitionPage` (ya establecido como estándar) para todas las rutas de nivel superior.
- Pasar datos entre rutas mediante `state.extra` (tipo `Map<String, dynamic>?`).
- Para navegar: `context.go('/ruta')` o `context.push('/ruta', extra: {'key': value})`.
- La redirección de autenticación está en el `redirect` del router; **no duplicar lógica de auth** en páginas individuales.
- Rutas existentes: `/`, `/splash`, `/login`, `/login-selection`, `/support`, `/my-requests`, `/request-updates/:id`, `/knowledge-base`, `/deliverables`, `/metrics`, `/metric-requests`, `/project-requests`, `/marketplace`, `/profile`.

---

## 6. Sistema de temas

- Los temas están en `lib/theme/`. Usar `AppThemes.lightTheme` y `AppThemes.darkTheme`.
- Para alternar entre temas: `AppThemes.themeModeNotifier.value = ThemeMode.dark` (es un `ValueNotifier`).
- **No hardcodear colores** en widgets. Usar siempre `Theme.of(context).colorScheme.<propiedad>`.
- Colores de referencia disponibles en `lib/theme/colors.dart` y `ColorTheme`.
- Google Fonts ya está integrado en el tema — no importar fuentes adicionales.

---

## 7. Llamadas HTTP — Patrón estándar

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

Future<List<Map<String, dynamic>>> fetchAlgo() async {
  final uri = Uri.parse('${Endpoint.request}?\$filter=...&\$top=50');
  final response = await http.get(uri, headers: {
    'Authorization': Token.token,
    'Content-Type': 'application/json',
  });

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes)); // utf8.decode es obligatorio
    return List<Map<String, dynamic>>.from(data['records'] ?? []);
  }
  throw Exception('Error ${response.statusCode}');
}
```

- Siempre usar `utf8.decode(response.bodyBytes)` — el backend retorna UTF-8 y `response.body` puede corromper acentos.
- Los filtros son OData: `\$filter=Campo eq Valor`, `\$top=N`, `\$orderby=Campo desc`, `\$expand=Relacion(\$select=Campo)`.
- **Nunca** llamar a `http` directamente desde un widget — crear una función en la capa `api/` o en `*_logic.dart`.

---

## 8. Gestión de estado

- La app **no usa un gestor de estado global** (no hay Provider, Riverpod, Bloc). El estado se maneja con `StatefulWidget` + `setState`.
- `GlobalCache` actúa como caché global de datos del backend.
- Para reactividad entre widgets: usar `ValueNotifier` + `ValueListenableBuilder` (ver `backgroundSyncNotifier` y `themeModeNotifier`).
- Al limpiar `TextEditingController`, `ScrollController`, etc., siempre hacerlo en `dispose()`.

---

## 9. Navegación con graphify

- Antes de explorar el código para preguntas de arquitectura, usar `graphify-out/GRAPH_REPORT.md` o el índice en `graphify-out/wiki/index.md`.
- Los **God Nodes** (nodos más conectados) son: `package:flutter/material.dart`, `access_control.dart`, `token.dart`, `custom_modal.dart`, `custom_button.dart`, `go_router`, `custom_inputs.dart`, `http`, `endpoint.dart`.
- Después de modificar archivos `.dart`, ejecutar: `graphify update .` para mantener el grafo actualizado.

---

## 10. Qué evitar

- ❌ No usar `Navigator.push()` — siempre usar `GoRouter` (`context.go`, `context.push`).
- ❌ No crear dialogs con `AlertDialog` directamente — usar `CustomModal`.
- ❌ No usar `ElevatedButton`/`TextButton` sueltos — usar `CustomButton`.
- ❌ No usar `TextField` suelto — usar `CustomTextField` o `CustomDropdown`.
- ❌ No hardcodear URLs del backend — usar `Endpoint.*`.
- ❌ No comparar roles por UUID directamente en widgets — usar `AccessControl.*`.
- ❌ No llamar `GlobalCache.syncData(force: true)` desde un widget en cada build — solo cuando el usuario explícitamente refresca.
- ❌ No usar `response.body` para decodificar JSON — usar `utf8.decode(response.bodyBytes)`.
- ❌ No agregar `debugPrint()` en código de producción.
