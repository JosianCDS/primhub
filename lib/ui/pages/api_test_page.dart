import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/api/auth_api.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:primhub/ui/shared/custom_table.dart';
import '../widgets/custom_drawer.dart';

class ApiTestPage extends StatefulWidget {
  const ApiTestPage({super.key});

  @override
  State<ApiTestPage> createState() => _ApiTestPageState();
}

class _ApiTestPageState extends State<ApiTestPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _results = [];
  String _statusMessage = 'Presiona Consultar para obtener datos';

  // Variables para gestión de horas
  double _contractedHours = 0.0;
  double _consumedHours = 0.0;
  bool _showLowHoursAlert = false;
  List<Map<String, dynamic>> _transactions = [];
  int? _validBPartnerId;
  final Set<int> _selectedIds = {};

  // URL específica solicitada
  String get _queryUrl {
    final payload = Token.decodePayload(Token.token);
    final int userId = payload['AD_User_ID'] ?? 101;
    return "${Endpoint.baseUrl}/api/v1/models/C_Invoice?\$filter=IsSOTrx eq true and C_DocTypeTarget_ID eq 116 and AD_User_ID eq $userId and (DocStatus eq 'CO' or DocStatus eq 'DR')&\$expand=C_InvoiceLine(\$select=M_Product_ID,QtyEntered;\$filter=M_Product_ID eq 1000850)&\$select=DocumentNo,C_BPartner_ID";
  }

  String _formatDate(DateTime date) {
    final iso = date.toUtc().toIso8601String();
    if (iso.contains('.')) {
      return "${iso.split('.').first}Z";
    }
    return iso;
  }

  @override
  void initState() {
    super.initState();
    _loadHoursData();
  }

  Future<void> _loadHoursData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Cargar Horas Contratadas (Facturas)
      final invoiceResponse = await http.get(
        Uri.parse(_queryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      double contracted = 0.0;
      List<Map<String, dynamic>> txList = [];
      DateTime? latestContractDate;

      if (invoiceResponse.statusCode == 200) {
        final jsonResponse = json.decode(
          utf8.decode(invoiceResponse.bodyBytes),
        );
        final records = jsonResponse['records'] as List;

        // Ordenar por fecha descendente para encontrar el contrato más reciente
        records.sort(
          (a, b) => (b['Created'] ?? '').compareTo(a['Created'] ?? ''),
        );

        if (records.isNotEmpty) {
          final latest = records.first;
          latestContractDate = DateTime.tryParse(latest['Created'] ?? '');

          // Tomamos solo las horas del último contrato (reinicio)
          final lines = latest['C_InvoiceLine'] as List?;
          if (lines != null) {
            for (var line in lines) {
              contracted += (line['QtyEntered'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }

        for (var record in records) {
          if (record['C_BPartner_ID'] != null) {
            _validBPartnerId = record['C_BPartner_ID']['id'];
          }
          txList.add({
            'id': record['id'],
            'Summary': 'Factura: ${record['DocumentNo']}',
            'Date': record['Created'] ?? '',
            'Type': 'Abono',
            'Endpoint': '${Endpoint.baseUrl}/api/v1/models/C_Invoice',
          });
        }
      }

      // 2. Cargar Horas Consumidas (Solicitudes)
      // Filtramos por el mismo usuario (101) y producto (1000850) que las facturas
      final payload = Token.decodePayload(Token.token);
      final int userId = payload['AD_User_ID'] ?? 101;
      final requestUrl =
          "${Endpoint.request}?\$filter=M_Product_ID eq 1000850 and AD_User_ID eq $userId";

      final requestResponse = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      double consumed = 0.0;
      if (requestResponse.statusCode == 200) {
        final jsonResponse = json.decode(
          utf8.decode(requestResponse.bodyBytes),
        );
        final records = jsonResponse['records'] as List;
        for (var req in records) {
          final start = req['StartDate'];
          final close = req['CloseDate'];
          double duration = 0.0;

          if (start != null && close != null) {
            try {
              final s = DateTime.parse(start);
              final c = DateTime.parse(close);
              duration = c.difference(s).inMinutes / 60.0;
            } catch (_) {}
          }

          // Solo sumar consumo si la solicitud es posterior al último contrato
          bool isApplicable = true;
          if (latestContractDate != null) {
            final reqDate = DateTime.tryParse(req['Created'] ?? '');
            if (reqDate != null && reqDate.isBefore(latestContractDate)) {
              isApplicable = false;
            }
          }

          if (isApplicable) {
            consumed += duration;
          }

          txList.add({
            'id': req['id'],
            'Summary': req['Summary'] ?? '',
            'Date': req['Created'] ?? '',
            'Type': 'Consumo',
            'Endpoint': Endpoint.request,
          });
        }
      }

      // Ordenar por fecha descendente
      txList.sort(
        (a, b) => (b['Date'] as String).compareTo(a['Date'] as String),
      );

      setState(() {
        _contractedHours = contracted;
        _consumedHours = consumed;

        _transactions = txList;

        // Alerta: Si tengo menos del 40% de las horas totales
        double remaining = _contractedHours - _consumedHours;
        _showLowHoursAlert =
            _contractedHours > 0 && remaining < (_contractedHours * 0.40);
      });
    } catch (e) {
      debugPrint('Error loading hours data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Confirmar eliminación',
        content: Text(
          '¿Estás seguro de eliminar ${_selectedIds.length} registros? Esto afectará el cálculo de horas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          CustomButton(
            text: 'Eliminar',
            backgroundColor: Colors.red,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      int deletedCount = 0;
      for (final id in _selectedIds) {
        final tx = _transactions.firstWhere(
          (t) => t['id'] == id,
          orElse: () => {},
        );
        if (tx.isNotEmpty) {
          final url = '${tx['Endpoint']}/$id';
          final response = await http.delete(
            Uri.parse(url),
            headers: {'Authorization': Token.token},
          );
          if (response.statusCode == 200 || response.statusCode == 204) {
            deletedCount++;
          }
        }
      }
      _selectedIds.clear();
      await _loadHoursData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se eliminaron $deletedCount registros.')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting transactions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendHoursTransaction(
    String summary,
    double hours,
    bool isConsumption,
  ) async {
    setState(() => _isLoading = true);
    try {
      // 1. Refrescar Token si existe
      if (Token.refreshToken != null) {
        final refreshRes = await AuthApi.refreshToken(Token.refreshToken!);
        if (refreshRes.containsKey('token')) {
          Token.auth = refreshRes['token'];
          if (refreshRes.containsKey('refresh_token')) {
            Token.refreshToken = refreshRes['refresh_token'];
          }
        }
      }

      // Obtener datos de sesión
      final payload = Token.decodePayload(Token.token);
      int clientId = Token.client ?? payload['AD_Client_ID'] ?? 11;
      int orgId = Token.organitation ?? payload['AD_Org_ID'] ?? 11;
      final int userId = payload['AD_User_ID'] ?? 101;

      // Documentos transaccionales no pueden estar en Org * (0). Forzamos HQ (11) si es necesario.
      if (orgId == 0) orgId = 11;

      String url;
      Map<String, dynamic> data;

      if (isConsumption) {
        url = Endpoint.request;
        final now = DateTime.now();
        final end = now.add(Duration(minutes: (hours * 60).toInt()));
        data = {
          'Summary': summary,
          'Priority': '5',
          'R_RequestType_ID': 101, // Service Request
          'AD_Client_ID': clientId,
          'AD_Org_ID': orgId,
          'M_Product_ID': 1000850,
          'AD_User_ID': userId,
          'StartDate': _formatDate(now),
          'CloseDate': _formatDate(end),
          'R_Status_ID': 103, // Final Close
        };
      } else {
        url = "${Endpoint.baseUrl}/api/v1/models/C_Invoice";
        data = {
          'AD_Client_ID': clientId,
          'AD_Org_ID': orgId,
          'IsSOTrx': true,
          'C_DocTypeTarget_ID': 116,
          'AD_User_ID': userId,
          'C_BPartner_ID':
              _validBPartnerId ?? 1000000, // C&W Construction (Demo)
          'C_InvoiceLine': [
            {
              'AD_Client_ID': clientId,
              'AD_Org_ID': orgId,
              'M_Product_ID': 1000850,
              'QtyEntered': hours,
              'PriceEntered': 10,
              'PriceActual': 10,
              'PriceList': 10,
            },
          ],
        };
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transacción realizada con éxito')),
          );
        }
        await _loadHoursData(); // Recargar datos
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _results = [];
      _statusMessage = 'Consultando...';
    });

    try {
      final response = await http.get(
        Uri.parse(_queryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;

        if (records.isEmpty) {
          setState(() {
            _statusMessage = 'No se encontraron registros.';
          });
        } else {
          final List<Map<String, dynamic>> parsedData = [];

          for (var record in records) {
            final docNo = record['DocumentNo'] ?? 'N/A';
            final lines = record['C_InvoiceLine'] as List?;

            if (lines != null && lines.isNotEmpty) {
              for (var line in lines) {
                parsedData.add({
                  'DocumentNo': docNo,
                  'Product': line['M_Product_ID']?['identifier'] ?? 'Unknown',
                  'QtyEntered': line['QtyEntered']?.toString() ?? '0',
                });
              }
            } else {
              // Si no hay líneas que coincidan con el filtro interno, mostramos solo la cabecera
              parsedData.add({
                'DocumentNo': docNo,
                'Product': 'Sin coincidencia',
                'QtyEntered': '-',
              });
            }
          }

          setState(() {
            _results = parsedData;
            _statusMessage = 'Registros encontrados: ${_results.length}';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'Error ${response.statusCode}: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Excepción: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showHoursDialog(bool isConsumption) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => CustomModal(
        title: isConsumption ? 'Gastar Horas' : 'Solicitar Horas',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: controller,
              label: 'Cantidad de Horas',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CustomButton(
            text: 'Confirmar',
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context);
                _sendHoursTransaction(
                  isConsumption
                      ? 'Consumo de prueba: $val horas'
                      : 'Solicitud de contrato: $val horas',
                  val,
                  isConsumption,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API PRUEBA')),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Gestión de Horas
            const Text(
              'Gestión de Horas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            if (_showLowHoursAlert)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '¡Advertencia! Te estás quedando sin horas (Menos del 40% disponible).',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoCard(
                  'Contratadas',
                  _contractedHours.toStringAsFixed(1),
                  Colors.blue,
                ),
                _buildInfoCard(
                  'Consumidas',
                  _consumedHours.toStringAsFixed(1),
                  Colors.orange,
                ),
                _buildInfoCard(
                  'Disponibles',
                  (_contractedHours - _consumedHours).toStringAsFixed(1),
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Solicitar Horas',
                    icon: Icons.add_shopping_cart,
                    onPressed: () => _showHoursDialog(false),
                    backgroundColor: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Gastar Horas',
                    icon: Icons.timer,
                    onPressed: () => _showHoursDialog(true),
                    backgroundColor: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historial de Transacciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_selectedIds.isNotEmpty)
                  CustomButton(
                    text: 'Eliminar (${_selectedIds.length})',
                    icon: Icons.delete,
                    backgroundColor: Colors.red,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: _deleteSelected,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: CustomTable(
                showCheckboxColumn: true,
                columns: const [
                  DataColumn(
                    label: Text('ID', style: TextStyle(color: Colors.white)),
                  ),
                  DataColumn(
                    label: Text('Tipo', style: TextStyle(color: Colors.white)),
                  ),
                  DataColumn(
                    label: Text(
                      'Resumen',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DataColumn(
                    label: Text('Fecha', style: TextStyle(color: Colors.white)),
                  ),
                ],
                rows: _transactions
                    .map(
                      (t) => DataRow(
                        selected: _selectedIds.contains(t['id']),
                        onSelectChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(t['id']);
                            } else {
                              _selectedIds.remove(t['id']);
                            }
                          });
                        },
                        cells: [
                          DataCell(
                            Text(
                              '${t['id']}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${t['Type']}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${t['Summary']}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${t['Date']}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 40, color: Colors.white24),

            // Sección Original de Consulta
            const Text(
              'Consulta de Facturas (C_Invoice)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'URL: $_queryUrl',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Consultar',
              onPressed: _fetchData,
              isLoading: _isLoading,
              icon: Icons.search,
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    _statusMessage.startsWith('Error') ||
                        _statusMessage.startsWith('Excepción')
                    ? Colors.red
                    : Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: CustomTable(
                columns: const [
                  DataColumn(
                    label: Text(
                      'Document No',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Producto',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Cantidad',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
                rows: _results.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          row['DocumentNo'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      DataCell(
                        Text(
                          row['Product'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      DataCell(
                        Text(
                          row['QtyEntered'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
