import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/custom_button.dart';
import '../../../api/token.dart';

class CreateRequestDialog extends StatefulWidget {
  const CreateRequestDialog({super.key});

  @override
  State<CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<CreateRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Controladores y variables del formulario
  final TextEditingController _summaryController = TextEditingController();
  String _selectedPriority = 'Media';
  String _selectedType = 'Service Request';
  bool _isAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(
        () => _isAdmin = (prefs.getString('user_role') ?? 'ADMIN') == 'ADMIN',
      );
  }

  // Mapeo de valores para el backend
  final Map<String, String> _priorityMap = {
    'Urgente': '1',
    'Alta': '3',
    'Media': '5',
    'Baja': '7',
    'Menor': '9',
  };

  // IDs correspondientes a los tipos de solicitud
  final Map<String, int> _requestTypeMap = {
    'Service Request': 101,
    'Request for Quotation': 102,
    'Warranty': 103,
  };

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final url = Uri.parse(Endpoint.request);

      final payload = Token.decodePayload(Token.token);
      int clientId = Token.client ?? payload['AD_Client_ID'] ?? 11;
      int orgId = Token.organitation ?? payload['AD_Org_ID'] ?? 11;
      int userId = payload['AD_User_ID'] ?? 101;
      if (orgId == 0) orgId = 11;

      final Map<String, dynamic> data = {
        'Summary': _summaryController.text,
        'Priority': _priorityMap[_selectedPriority],
        'R_RequestType_ID': _requestTypeMap[_selectedType],
        'AD_Client_ID': clientId,
        'AD_Org_ID': orgId,
        'AD_User_ID': userId,
        'SalesRep_ID': userId,
      };

      final body = jsonEncode(data);

      debugPrint('Payload enviado: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solicitud creada correctamente')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error ${response.statusCode}: ${response.body}\nPayload: $body',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomModal(
      title: 'Nueva Solicitud de Soporte',
      width: 500,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomDropdown<String>(
              value: _selectedType,
              label: 'Situación',
              items: [
                'Service Request',
                'Request for Quotation',
                'Warranty',
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _summaryController,
              label: 'Descripción / Resumen',
              maxLines: 4,
              validator: (value) => value == null || value.isEmpty
                  ? 'Por favor ingrese una descripción'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        CustomButton(
          text: 'Enviar Solicitud',
          onPressed: _submitForm,
          isLoading: _isSubmitting,
        ),
      ],
    );
  }
}
