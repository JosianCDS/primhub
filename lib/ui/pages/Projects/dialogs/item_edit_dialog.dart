import 'package:flutter/material.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';

class ItemEditDialog extends StatelessWidget {
  final String type;
  final String currentName;
  final String currentDesc;
  final Function(String name, String desc) onSave;

  const ItemEditDialog({super.key, required this.type, required this.currentName, required this.currentDesc, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    final TextEditingController descController = TextEditingController(text: currentDesc);

    return CustomModal(
      title:
          'Editar ${type == 'project'
              ? 'Proyecto'
              : type == 'phase'
              ? 'Fase'
              : 'Tarea'}',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(controller: nameController, label: 'Nombre'),
          const SizedBox(height: 16),
          CustomTextField(controller: descController, label: 'Descripción', maxLines: 2),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        CustomButton(
          text: 'Guardar',
          onPressed: () {
            onSave(nameController.text, descController.text);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
