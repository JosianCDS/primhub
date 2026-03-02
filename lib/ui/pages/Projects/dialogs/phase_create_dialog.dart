import 'package:flutter/material.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';

class PhaseCreateDialog extends StatelessWidget {
  final Function(String name, String desc) onSave;

  const PhaseCreateDialog({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    return CustomModal(
      title: 'Nueva Fase',
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
          text: 'Crear',
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              onSave(nameController.text, descController.text);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
