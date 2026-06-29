import 'dart:convert';
import 'package:primhub/api/api_http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/api/global_cache.dart';

/// Contiene los datos procesados para un gráfico simple (torta, dona, barras).
class SimpleChartData {
  final List<String> labels;
  final List<double> values;

  SimpleChartData({required this.labels, required this.values});
}

/// Contiene los datos procesados para un gráfico de barras apiladas.
class StackedBarChartData {
  final List<String> labels; // Etiquetas cortas para el eje X
  final List<String> fullLabels; // Etiquetas completas para tooltips
  final List<List<double>> seriesValues; // Datos de cada serie
  final List<String> seriesNames; // Nombres de las series

  StackedBarChartData({
    required this.labels,
    required this.fullLabels,
    required this.seriesValues,
    required this.seriesNames,
  });
}

/// Contenedor para todas las métricas de proyecto calculadas.
class ProjectMetrics {
  final SimpleChartData complianceData;
  final SimpleChartData statusData;
  final StackedBarChartData moduleStatusData;
  final SimpleChartData modulePercentageData;

  ProjectMetrics({
    required this.complianceData,
    required this.statusData,
    required this.moduleStatusData,
    required this.modulePercentageData,
  });
}

/// Clase responsable de calcular todas las métricas para los gráficos de proyectos.
class ProjectMetricsCalculator {
  /// Calcula todas las métricas para los gráficos de la página de Métricas de Proyecto.
  ///
  /// Recibe una lista de solicitudes y devuelve un objeto [ProjectMetrics] con los datos procesados.
  static ProjectMetrics calculate(List<Map<String, dynamic>> requests) {
    // 1. Calcular datos para el gráfico de Cumplimiento (% de Cumplimiento)
    final complianceData = _calculateComplianceData(requests);

    // 2. Calcular datos para el gráfico de Estado (Solicitudes por Estado)
    final statusData = _calculateStatusData(requests);

    // 3. Calcular datos para los gráficos de Módulos (Estado por Módulo y % Avance)
    final moduleMetrics = _calculateModuleMetrics(requests);

    return ProjectMetrics(
      complianceData: complianceData,
      statusData: statusData,
      moduleStatusData: moduleMetrics['moduleStatusData']!,
      modulePercentageData: moduleMetrics['modulePercentageData']!,
    );
  }

  /// Determina la categoría de cumplimiento ('TERMINADA', 'PENDIENTE', 'ESPERA DE CLIENTE') para una solicitud.
  /// Esta lógica se centraliza aquí para ser usada tanto en los gráficos como en las tablas de detalle.
  static String getComplianceCategory(Map<String, dynamic> req) {
    final statusData = req['R_Status_ID']; // Puede ser Map o int
    final statusId = statusData is Map ? statusData['id'] : statusData;

    String rawStatusName = statusData is Map
        ? (statusData['Name'] ??
              statusData['identifier'] ??
              req['R_Status_Name'] ??
              'Sin Estado')
        : (req['R_Status_Name'] ?? 'Sin Estado');
    String lowerStatus = rawStatusName.toLowerCase();

    if (lowerStatus.contains('espera de cliente')) {
      return 'ESPERA DE CLIENTE';
    } else if (lowerStatus.contains('por entregar') ||
        lowerStatus.contains('evaluacion') ||
        lowerStatus.contains('anulada') ||
        lowerStatus.contains('archivada') ||
        lowerStatus.contains('aprobada por el cliente') ||
        lowerStatus.contains('close') ||
        lowerStatus.contains('cerrad') ||
        lowerStatus.contains('entregado') ||
        lowerStatus.contains('entregada') ||
        statusId == 103 ||
        statusId == 1000019 ||
        statusId == 1000030) {
      return 'TERMINADA';
    } else {
      return 'PENDIENTE';
    }
  }

  /// Lógica para el gráfico de % de Cumplimiento.
  static SimpleChartData _calculateComplianceData(
    List<Map<String, dynamic>> requests,
  ) {
    final Map<String, int> compliancePieData = {
      'TERMINADA': 0,
      'PENDIENTE': 0,
      'ESPERA DE CLIENTE': 0,
    };

    for (var req in requests) {
      // Usar el método centralizado para obtener la categoría
      final compCat = getComplianceCategory(req);
      if (compliancePieData.containsKey(compCat)) {
        compliancePieData[compCat] = (compliancePieData[compCat] ?? 0) + 1;
      }
    }

    final complianceLabels = compliancePieData.keys
        .where((k) => compliancePieData[k]! > 0)
        .toList();
    final values = complianceLabels
        .map((k) => compliancePieData[k]!.toDouble())
        .toList();
    return SimpleChartData(labels: complianceLabels, values: values);
  }

  /// Lógica para el gráfico de Solicitudes por Estado.
  static SimpleChartData _calculateStatusData(
    List<Map<String, dynamic>> requests,
  ) {
    final Map<String, int> statusCounts = {};

    for (var req in requests) {
      final statusData = req['R_Status_ID'] as Map?;
      final rawStatusName =
          statusData?['Name'] ??
          statusData?['identifier'] ??
          req['R_Status_Name'] ??
          'Sin Estado';
      final lowerStatus = rawStatusName.toLowerCase();

      if (lowerStatus.contains('anulada'))
        continue; // No se toman en cuenta las anuladas

      final statusName = rawStatusName.contains('_')
          ? rawStatusName.split('_').last.trim()
          : rawStatusName.trim();
      statusCounts[statusName] = (statusCounts[statusName] ?? 0) + 1;
    }

    return SimpleChartData(
      labels: statusCounts.keys.toList(),
      values: statusCounts.values.map((v) => v.toDouble()).toList(),
    );
  }

  /// Lógica para los gráficos de Módulos.
  static Map<String, dynamic> _calculateModuleMetrics(
    List<Map<String, dynamic>> requests,
  ) {
    final Map<String, Map<String, int>> moduleStatusCounts = {};

    for (var req in requests) {
      final statusData = req['R_Status_ID'];
      final statusId = statusData is Map ? statusData['id'] : statusData;

      String rawStatusName = statusData is Map
          ? (statusData['Name'] ??
                statusData['identifier'] ??
                req['R_Status_Name'] ??
                'Sin Estado')
          : (req['R_Status_Name'] ?? 'Sin Estado');
      final lowerStatus = rawStatusName.toLowerCase();

      if (lowerStatus.contains('anulada')) continue;

      final categoryData = req['R_Category_ID'] as Map?;
      final categoryName =
          categoryData?['Name'] ?? categoryData?['identifier'] ?? 'Sin Módulo';

      if (categoryName == 'Sin Módulo' || categoryName.trim().isEmpty) continue;

      final modCat = getComplianceCategory(req);
      moduleStatusCounts.putIfAbsent(
        categoryName,
        () => {'TERMINADA': 0, 'PENDIENTE': 0, 'ESPERA DE CLIENTE': 0},
      );
      moduleStatusCounts[categoryName]![modCat] =
          (moduleStatusCounts[categoryName]![modCat] ?? 0) + 1;
    }

    final moduleFullLabels = moduleStatusCounts.keys.toList();
    final moduleLabels = moduleFullLabels
        .map(
          (l) => l
              .replaceAll(
                RegExp(r'Módulo de |Módulo ', caseSensitive: false),
                '',
              )
              .trim(),
        )
        .map((l) => l.length > 10 ? '${l.substring(0, 9)}..' : l)
        .toList();
    final moduleTerminadaValues = moduleFullLabels
        .map((mod) => (moduleStatusCounts[mod]!['TERMINADA'] ?? 0).toDouble())
        .toList();
    final modulePendienteValues = moduleFullLabels
        .map((mod) => (moduleStatusCounts[mod]!['PENDIENTE'] ?? 0).toDouble())
        .toList();
    final moduleEsperaValues = moduleFullLabels
        .map(
          (mod) =>
              (moduleStatusCounts[mod]!['ESPERA DE CLIENTE'] ?? 0).toDouble(),
        )
        .toList();
    final modulePercentageValues = moduleFullLabels.map((mod) {
      final total =
          (moduleStatusCounts[mod]!['TERMINADA'] ?? 0) +
          (moduleStatusCounts[mod]!['PENDIENTE'] ?? 0) +
          (moduleStatusCounts[mod]!['ESPERA DE CLIENTE'] ?? 0);
      return total > 0
          ? ((moduleStatusCounts[mod]!['TERMINADA'] ?? 0) / total * 100)
          : 0.0;
    }).toList();

    return {
      'moduleStatusData': StackedBarChartData(
        labels: moduleLabels,
        fullLabels: moduleFullLabels,
        seriesValues: [
          moduleTerminadaValues,
          modulePendienteValues,
          moduleEsperaValues,
        ],
        seriesNames: const ['Terminada', 'Pendiente', 'Espera de Cliente'],
      ),
      'modulePercentageData': SimpleChartData(
        labels: moduleLabels,
        values: modulePercentageValues,
      ),
    };
  }
}

class GraphicsFunctions {
  /// Obtiene solicitudes filtrando por ID del Proyecto
  static Future<List<Map<String, dynamic>>> fetchMetricsData({
    required int projectId,
    bool forceRefresh = false,
  }) async {
    // 1. Priorizar la Caché de Proyecto específica (donde se cargan datos históricos completos)
    if (!forceRefresh && GlobalCache.projectRequestsCache.containsKey(projectId)) {
// [Mantenimiento] Log removido:       print("DEBUG API: Obteniendo métricas desde Caché de Proyecto específica...");
      final projReqs = GlobalCache.projectRequestsCache[projectId]!;
      return projReqs.where((req) {
        bool isActive = req['IsActive'] == true || req['IsActive'] == 'Y';
        int? reqGroupId = req['R_Group_ID'] is Map ? req['R_Group_ID']['id'] : req['R_Group_ID'];
        return isActive && reqGroupId == 1000006;
      }).toList();
    }

    // 2. Usar Caché Global General como segunda opción
    if (!forceRefresh && GlobalCache.isDataLoaded) {
// [Mantenimiento] Log removido:       print(
// [Mantenimiento] Log removido:         "DEBUG API: Obteniendo métricas del proyecto $projectId desde GlobalCache...",
// [Mantenimiento] Log removido:       );
      return GlobalCache.requests.where((req) {
        bool isActive = req['IsActive'] == true || req['IsActive'] == 'Y';
        int? reqProjectId = req['C_Project_ID'] is Map
            ? req['C_Project_ID']['id']
            : req['C_Project_ID'];
        int? reqGroupId = req['R_Group_ID'] is Map
            ? req['R_Group_ID']['id']
            : req['R_Group_ID'];

        return isActive && reqProjectId == projectId && reqGroupId == 1000006;
      }).toList();
    }

    // 2. Fallback: Llamada a la API si la caché no está disponible
    List<Map<String, dynamic>> allRecords = [];
    int skip = 0;
    const int pageSize = 100;
    bool hasMore = true;

    // FILTRO iDempiere: Activos, del Proyecto por ID numérico y que sean Requerimientos de cliente (R_Group_ID = 1000006)
    String filter =
        "C_Project_ID eq $projectId and IsActive eq true and R_Group_ID eq 1000006";

    // Expand optimizado (Quitamos el límite de $select para que la tabla pueda recibir el Asunto, Usuario, etc.)
    String expand =
        "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name)";

    try {
      while (hasMore) {
        final queryParams = {
          '\$skip': skip.toString(),
          '\$top': pageSize.toString(),
          '\$filter': filter,
          '\$expand': expand,
        };

        final uri = Uri.parse(
          '${Endpoint.baseUrl}/api/v1/models/R_Request',
        ).replace(queryParameters: queryParams);

// [Mantenimiento] Log removido:         print("DEBUG API: Consultando página con skip $skip...");

        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': Token.token,
          },
        );

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
          final records = jsonResponse['records'] as List?;

          if (records == null || records.isEmpty) {
            hasMore = false;
          } else {
            allRecords.addAll(records.map((r) => Map<String, dynamic>.from(r)));
            if (records.length < pageSize) {
              hasMore = false;
            } else {
              skip += pageSize;
            }
          }
        } else {
          hasMore = false;
// [Mantenimiento] Log removido:           print(
// [Mantenimiento] Log removido:             "DEBUG API ERROR: Status ${response.statusCode} - ${response.body}",
// [Mantenimiento] Log removido:           );
        }
      }
    } catch (e) {
// [Mantenimiento] Log removido:       print("DEBUG API EXCEPTION: $e");
    }
    return allRecords;
  }
}

