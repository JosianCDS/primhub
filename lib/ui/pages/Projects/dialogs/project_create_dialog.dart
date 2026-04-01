import 'package:flutter/material.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/admin_view_mode.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';

class ProjectCreateDialog extends StatefulWidget {
  final List<dynamic> projects;
  final Function(String value, String name, String description, int? bpId, String dateContract, String dateFinish, int? projectTypeId) onCreateProject;
  final Function(int projectId, String name, String desc) onCreatePhase;
  final Function(int phaseId, String name, String desc) onCreateTask;

  const ProjectCreateDialog({super.key, required this.projects, required this.onCreateProject, required this.onCreatePhase, required this.onCreateTask});

  @override
  State<ProjectCreateDialog> createState() => _ProjectCreateDialogState();
}

class _ProjectCreateDialogState extends State<ProjectCreateDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController dateContractController = TextEditingController();
  final TextEditingController dateFinishController = TextEditingController();
  final ProjectsLogic _logic = ProjectsLogic();

  List<dynamic> _bPartners = [];
  List<dynamic> _projectTypes = [];
  int? selectedBpId;
  String creationType = 'Project';
  int? selectedProjectId;
  int? selectedPhaseId;
  int? selectedProjectTypeId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([_logic.fetchBPartners(), _logic.fetchProjects(context, isViewingMine: AdminViewModeManager().isViewingMine)]);
    if (mounted) {
      setState(() {
        _bPartners = results[0];
        _projectTypes = results[1];
        if (_bPartners.any((bp) => bp['id'] == User.cBPartnerID)) {
          selectedBpId = User.cBPartnerID;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomModal(
      title: 'Nuevo Proyecto',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: creationType,
              decoration: InputDecoration(
                labelText: 'Tipo de Registro',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'Project', child: Text('Proyecto')),
                DropdownMenuItem(value: 'Phase', child: Text('Fase')),
                DropdownMenuItem(value: 'Task', child: Text('Tarea')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => creationType = val);
                }
              },
            ),
            const SizedBox(height: 16),

            if (creationType == 'Project') ...[
              CustomTextField(controller: valueController, label: 'Código (Value)'),
              const SizedBox(height: 16),
              CustomTextField(controller: nameController, label: 'Nombre'),
              const SizedBox(height: 16),
              CustomTextField(controller: descController, label: 'Descripción', maxLines: 3),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedProjectTypeId,
                decoration: InputDecoration(
                  labelText: 'Tipo de Proyecto',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _projectTypes.map<DropdownMenuItem<int>>((pt) {
                  return DropdownMenuItem<int>(
                    value: pt['id'],
                    child: Text(pt['Name'] ?? 'Sin Nombre', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedProjectTypeId = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedBpId,
                decoration: InputDecoration(
                  labelText: 'Tercero (Cliente)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _bPartners.map<DropdownMenuItem<int>>((bp) {
                  return DropdownMenuItem<int>(
                    value: bp['id'],
                    child: Text(bp['Name'] ?? 'Sin Nombre', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedBpId = val),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) {
                          dateContractController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        }
                      },
                      child: AbsorbPointer(
                        child: CustomTextField(controller: dateContractController, label: 'Fecha Contrato', hintText: 'YYYY-MM-DD', prefixIcon: const Icon(Icons.calendar_today)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) {
                          dateFinishController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        }
                      },
                      child: AbsorbPointer(
                        child: CustomTextField(controller: dateFinishController, label: 'Fecha Fin', hintText: 'YYYY-MM-DD', prefixIcon: const Icon(Icons.calendar_today)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (creationType == 'Phase' || creationType == 'Task') ...[
              DropdownButtonFormField<int>(
                value: selectedProjectId,
                decoration: InputDecoration(
                  labelText: 'Proyecto Padre',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.projects.map<DropdownMenuItem<int>>((p) {
                  return DropdownMenuItem<int>(
                    value: p['id'],
                    child: Text(p['Name'] ?? 'Sin Nombre', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedProjectId = val;
                    selectedPhaseId = null;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            if (creationType == 'Task') ...[
              DropdownButtonFormField<int>(
                value: selectedPhaseId,
                decoration: InputDecoration(
                  labelText: 'Fase Padre',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: selectedProjectId == null
                    ? []
                    : (widget.projects.firstWhere((p) => p['id'] == selectedProjectId)['C_ProjectPhase'] as List? ?? []).map<DropdownMenuItem<int>>((ph) {
                        return DropdownMenuItem<int>(
                          value: ph['id'],
                          child: Text(ph['Name'] ?? 'Sin Nombre', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                onChanged: (val) => setState(() => selectedPhaseId = val),
              ),
              const SizedBox(height: 16),
            ],

            if (creationType != 'Project') ...[CustomTextField(controller: nameController, label: 'Nombre'), const SizedBox(height: 16), CustomTextField(controller: descController, label: 'Descripción', maxLines: 2)],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        CustomButton(
          text: 'Crear',
          onPressed: () {
            if (creationType == 'Project') {
              if (nameController.text.isNotEmpty && valueController.text.isNotEmpty) {
                widget.onCreateProject(valueController.text, nameController.text, descController.text, selectedBpId, dateContractController.text, dateFinishController.text, selectedProjectTypeId);
                Navigator.pop(context);
              }
            } else if (creationType == 'Phase') {
              if (selectedProjectId != null && nameController.text.isNotEmpty) {
                widget.onCreatePhase(selectedProjectId!, nameController.text, descController.text);
                Navigator.pop(context);
              }
            } else if (creationType == 'Task') {
              if (selectedPhaseId != null && nameController.text.isNotEmpty) {
                widget.onCreateTask(selectedPhaseId!, nameController.text, descController.text);
                Navigator.pop(context);
              }
            }
          },
        ),
      ],
    );
  }
}
