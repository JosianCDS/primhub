import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import '../../Shared_Custom/custom_button.dart';
import '../../widgets/custom_drawer.dart';

class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      drawer: const CustomDrawer(currentRoute: '/marketplace'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomContainer(
              title: 'Solicitar Cotización',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Necesitas un desarrollo a medida, un nuevo plugin o más horas de soporte? Describe tu requerimiento y te contactaremos.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  const Text('Asunto', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const CustomTextField(hintText: 'Ej. Nuevo módulo de reportes'),
                  const SizedBox(height: 15),
                  const Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const CustomTextField(maxLines: 5, hintText: 'Detalla aquí tu requerimiento...'),
                  const SizedBox(height: 20),
                  CustomButton(text: 'Enviar Solicitud', onPressed: () {}, width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
