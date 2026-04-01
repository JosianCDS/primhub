import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/Shared_Custom/cardcustom.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/pages/Projects/dialogs/project_calendar_dialog.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/api/token.dart';

class ProjectDurationCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final Color textColor;
  final bool hasMetrics;

  const ProjectDurationCard({super.key, required this.project, required this.textColor, this.hasMetrics = false});

  DateTime? _parseDateSafely(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    if (dateStr.length >= 10) {
      String datePart = dateStr.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
        return DateTime.tryParse(datePart);
      }
    }
    return DateTime.tryParse(dateStr.replaceAll(' ', 'T'));
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Días Transcurridos';
    String value = '0';
    String subtitle = 'Sin fecha de contrato';
    String projectName = project['Name'] ?? 'Proyecto';
    String? dateContract = project['DateContract'];
    String? dateFinish = project['DateFinish'];

    if (dateContract != null) {
      DateTime? start = _parseDateSafely(dateContract);
      if (start != null) {
        DateTime startDay = DateTime(start.year, start.month, start.day);
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);
        DateTime? endDay;

        if (dateFinish != null && dateFinish.isNotEmpty) {
          DateTime? end = _parseDateSafely(dateFinish);
          if (end != null) endDay = DateTime(end.year, end.month, end.day);
        }

        if (today.isBefore(startDay)) {
          title = 'Proyecto Planificado';
          value = '0';
          if (endDay != null) {
            subtitle = 'Del ${startDay.day}/${startDay.month}/${startDay.year} al ${endDay.day}/${endDay.month}/${endDay.year}';
          } else {
            subtitle = 'Inicia el ${startDay.day}/${startDay.month}/${startDay.year}';
          }
        } else if (endDay != null) {
          if (today.isBefore(endDay)) {
            title = 'Proyecto En Curso';
            value = today.difference(startDay).inDays.toString();
            subtitle = 'Del ${startDay.day}/${startDay.month}/${startDay.year} al ${endDay.day}/${endDay.month}/${endDay.year}';
          } else {
            title = 'Proyecto Cerrado';
            value = endDay.difference(startDay).inDays.toString();
            subtitle = 'Del ${startDay.day}/${startDay.month}/${startDay.year} al ${endDay.day}/${endDay.month}/${endDay.year}';
          }
        } else {
          title = 'Proyecto En Curso';
          value = today.difference(startDay).inDays.toString();
          subtitle = 'Desde ${start.day}/${start.month}/${start.year}';
        }
      }
    }

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => ProjectCalendarDialog(project: project),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: CardCustom(
        hover: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Color.fromRGBO(223, 231, 255, 1), shape: BoxShape.circle),
                    child: const Icon(Icons.calendar_today, color: Color.fromRGBO(79, 71, 229, 1), size: 36),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          projectName,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.7)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(color: const Color(0xff4F47E5), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (hasMetrics)
              Positioned(
                top: 0,
                right: 0,
                child: Tooltip(
                  message: 'Este proyecto tiene métricas disponibles',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      context.push('/metrics', extra: {'projectId': project['id']});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary, size: 28),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProjectDeliverablesCard extends StatelessWidget {
  final int projectId;
  final Map<String, dynamic> stats;
  final Color textColor;

  const ProjectDeliverablesCard({super.key, required this.projectId, required this.stats, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final et = stats['et'] ?? 0;
    final sg = stats['sg'] ?? 0;
    final gn = stats['gn'] ?? 0;
    // final bool pendingEt = stats['pendingEt'] ?? false;
    // final bool pendingSg = stats['pendingSg'] ?? false;
    // final bool pendingGn = stats['pendingGn'] ?? false;

    return CardCustom(
      hover: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color.fromRGBO(254, 244, 199, 1), shape: BoxShape.circle),
            child: const Icon(Icons.folder_special, color: Color.fromRGBO(217, 119, 8, 1), size: 36),
          ),
          const SizedBox(height: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Documentos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: () => context.push('/deliverables', extra: {'projectId': projectId, 'view': 'Entregables'}),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(children: [_buildStatItem(context, et, 'Entregables' /*, pendingEt*/)]),
                    ),
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.withOpacity(0.3)),
                  InkWell(
                    onTap: () => context.push('/deliverables', extra: {'projectId': projectId, 'view': 'Seguimiento'}),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(children: [_buildStatItem(context, sg, 'Seguimiento' /*, pendingSg*/)]),
                    ),
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.withOpacity(0.3)),
                  InkWell(
                    onTap: () => context.push('/deliverables', extra: {'projectId': projectId, 'view': 'General'}),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(children: [_buildStatItem(context, gn, 'General' /*, pendingGn*/)]),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Documentos del proyecto.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, int count, String label /*, bool hasPending*/) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(color: const Color(0xffD97708), fontWeight: FontWeight.bold, fontSize: 24),
            ),
            // if (count > 0)
            //   Container(
            //     margin: const EdgeInsets.only(top: 4, left: 2),
            //     width: 8,
            //     height: 8,
            //     decoration: BoxDecoration(color: hasPending ? Colors.red : Colors.green, shape: BoxShape.circle),
            //   ),
          ],
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
        ),
      ],
    );
  }
}

class ProjectSelector extends StatelessWidget {
  final List<int> selectedProjectIds;
  final List<dynamic> projects;
  final ValueChanged<List<int>> onSelectionChanged;

  const ProjectSelector({super.key, required this.selectedProjectIds, required this.projects, required this.onSelectionChanged});

  void _showMultiSelectProjects(BuildContext context) async {
    final List<int> tempSelectedProjectIds = List.from(selectedProjectIds);
    List<dynamic> sortedProjects = List.from(projects);
    sortedProjects.sort((a, b) => (a['Name'] ?? '').compareTo(b['Name'] ?? ''));

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CustomModal(
          title: 'Seleccionar Proyectos',
          width: 500,
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                height: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              tempSelectedProjectIds.clear();
                              tempSelectedProjectIds.addAll(sortedProjects.map<int>((p) => p['id'] as int));
                            });
                          },
                          child: const Text('Seleccionar Todos'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              tempSelectedProjectIds.clear();
                            });
                          },
                          child: const Text('Deseleccionar Todos', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: ListBody(
                          children: sortedProjects.map((project) {
                            final bool isSelected = tempSelectedProjectIds.contains(project['id']);
                            return CheckboxListTile(
                              title: Text(project['Name'] ?? 'Proyecto sin nombre'),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    tempSelectedProjectIds.add(project['id']);
                                  } else {
                                    tempSelectedProjectIds.remove(project['id']);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
            CustomButton(
              text: 'Aceptar',
              onPressed: () {
                onSelectionChanged(tempSelectedProjectIds);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayText;
    if (selectedProjectIds.isEmpty) {
      if (projects.isEmpty) return const SizedBox.shrink();
      displayText = 'Ningún proyecto seleccionado';
    } else if (selectedProjectIds.length == 1) {
      final project = projects.firstWhere((p) => p['id'] == selectedProjectIds.first, orElse: () => {'Name': 'Proyecto no encontrado'});
      displayText = project['Name'] ?? 'Proyecto sin nombre';
    } else {
      displayText = '${selectedProjectIds.length} proyectos seleccionados';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: projects.length > 1 ? () => _showMultiSelectProjects(context) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(child: Text(displayText, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
