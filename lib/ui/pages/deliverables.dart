import 'package:flutter/material.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import '../shared/custom_table.dart';
import '../shared/custom_button.dart';
import '../widgets/custom_drawer.dart';
import '../shared/hover_widgets.dart';

class DeliverablesPage extends StatefulWidget {
  const DeliverablesPage({super.key});

  @override
  State<DeliverablesPage> createState() => _DeliverablesPageState();
}

class _DeliverablesPageState extends State<DeliverablesPage> {
  String _selectedFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Entregable/Seguimiento',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const CustomDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUploadDialog(context),
        backgroundColor: const Color(0xFF4F47E5),
        tooltip: 'Subir Archivo',
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
          double childAspectRatio = constraints.maxWidth > 900 ? 1.5 : 0.75;
          int charLimit = constraints.maxWidth < 600 ? 5 : 25;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Entregables'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Seguimiento'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_selectedFilter == 'Todos' ||
                    _selectedFilter == 'Entregables') ...[
                  const Text(
                    'Entregables',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio:
                        childAspectRatio, // Ajuste dinámico del tamaño vertical
                    children: [
                      _buildDeliverableCard(
                        '',
                        'Manuales de Usuario',
                        '3 archivos',
                        Colors.amber,
                        charLimit,
                        isFolder: true,
                      ),
                      _buildDeliverableCard(
                        'ZIP',
                        'Codigo_Fuente',
                        '150 MB',
                        Colors.orange,
                        charLimit,
                      ),
                      _buildDeliverableCard(
                        '',
                        'Especificaciones',
                        '5 archivos',
                        Colors.amber,
                        charLimit,
                        isFolder: true,
                      ),
                      _buildDeliverableCard(
                        'XLSX',
                        'Reporte_Financiero',
                        '850 KB',
                        Colors.green,
                        charLimit,
                      ),
                    ],
                  ),
                ],
                if (_selectedFilter == 'Todos' ||
                    _selectedFilter == 'Seguimiento') ...[
                  const SizedBox(height: 30),
                  const Text(
                    'Seguimiento de proyecto',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                    children: [
                      _buildDeliverableCard(
                        '',
                        'Minutas de Sesiones',
                        '12 archivos',
                        Colors.purple,
                        charLimit,
                        isFolder: true,
                      ),
                      _buildDeliverableCard(
                        'PDF',
                        'Asistencia',
                        '1.8 MB',
                        Colors.red,
                        charLimit,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == label,
      onSelected: (bool selected) {
        if (selected) setState(() => _selectedFilter = label);
      },
    );
  }

  void _showUploadDialog(BuildContext context) {
    String? selectedLocation;
    String? fileName;

    final List<String> locations = [
      'Entregables (Raíz)',
      'Entregables / Manuales de Usuario',
      'Entregables / Especificaciones',
      'Seguimiento (Raíz)',
      'Seguimiento / Minutas de Sesiones',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return CustomModal(
              title: 'Subir Archivo',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecciona la ubicación:'),
                  const SizedBox(height: 8),
                  CustomDropdown<String>(
                    hintText: 'Destino',
                    value: selectedLocation,
                    items: locations
                        .map(
                          (loc) =>
                              DropdownMenuItem(value: loc, child: Text(loc)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => selectedLocation = val),
                  ),
                  const SizedBox(height: 16),
                  const Text('Archivo:'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fileName ?? 'Ningún archivo seleccionado',
                          style: TextStyle(
                            color: fileName == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: () {
                          setState(() => fileName = 'documento_nuevo.pdf');
                        },
                        tooltip: 'Seleccionar archivo',
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                CustomButton(
                  text: 'Subir',
                  onPressed: (selectedLocation != null && fileName != null)
                      ? () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Subiendo $fileName a $selectedLocation...',
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFolderContents(BuildContext context, String folderName) {
    // Datos de ejemplo para la tabla
    final List<Map<String, String>> files = [
      {
        'name': 'Requerimientos_v1',
        'ext': 'pdf',
        'date': '2023-01-10',
        'size': '2.5 MB',
        'uploadDate': '2023-01-12',
        'modDate': '2023-01-15',
        'uploader': 'Juan Perez',
        'modifier': 'Maria Lopez',
      },
      {
        'name': 'Diagrama_Flujo',
        'ext': 'png',
        'date': '2023-02-05',
        'size': '1.2 MB',
        'uploadDate': '2023-02-06',
        'modDate': '2023-02-06',
        'uploader': 'Carlos Ruiz',
        'modifier': 'Carlos Ruiz',
      },
    ];

    showDialog(
      context: context,
      builder: (context) {
        return CustomModal(
          title: 'Contenido: $folderName',
          width: 800,
          content: CustomTable(
            columns: const [
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Extensión')),
              DataColumn(label: Text('Fecha')),
              DataColumn(label: Text('Peso')),
              DataColumn(label: Text('Fecha Subida')),
              DataColumn(label: Text('Última Mod.')),
              DataColumn(label: Text('Subido por')),
              DataColumn(label: Text('Modificado por')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: files
                .map(
                  (file) => DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>((
                      Set<MaterialState> states,
                    ) {
                      if (states.contains(MaterialState.hovered)) {
                        return Colors.blue.withOpacity(0.1);
                      }
                      return null;
                    }),
                    cells: [
                      DataCell(Text(file['name']!)),
                      DataCell(Text(file['ext']!)),
                      DataCell(Text(file['date']!)),
                      DataCell(Text(file['size']!)),
                      DataCell(Text(file['uploadDate']!)),
                      DataCell(Text(file['modDate']!)),
                      DataCell(Text(file['uploader']!)),
                      DataCell(Text(file['modifier']!)),
                      DataCell(
                        IconButton(
                          icon: const Icon(
                            Icons.download,
                            color: Color(0xFF4F47E5),
                          ),
                          tooltip: 'Descargar',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Descargando ${file['name']}.${file['ext']}...',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeliverableCard(
    String extension,
    String name,
    String size,
    Color color,
    int charLimit, {
    bool isFolder = false,
  }) {
    return HoverScaleCard(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: isFolder
                    ? const EdgeInsets.all(8)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  border: Border.all(color: color, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isFolder
                    ? Icon(Icons.folder, color: color, size: 28)
                    : Text(
                        extension,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                name.length > charLimit
                    ? '${name.substring(0, charLimit)}...'
                    : name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                size,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const Spacer(),
              CustomButton(
                text: isFolder ? 'Abrir' : 'Descargar',
                onPressed: () {
                  if (isFolder) {
                    _showFolderContents(context, name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Descargando $name.$extension...'),
                      ),
                    );
                  }
                },
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
