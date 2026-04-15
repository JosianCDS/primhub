import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_material.dart';

class AppThemes {
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

  // Centralizamos la tipografía con los requerimientos exactos
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return GoogleFonts.poppinsTextTheme(
      TextTheme(
        titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.normal, color: colorScheme.onSurface), // Títulos
        titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.normal, color: colorScheme.onSurface), // Subtítulos
        bodyLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.normal, color: colorScheme.onSurface), // Textos normales
        bodyMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal, color: colorScheme.onSurface),
        labelLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.normal, color: colorScheme.onSurface),
      ),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = MaterialTheme.lightScheme();
    final textTheme = _buildTextTheme(colorScheme);
    final materialTheme = MaterialTheme(textTheme);

    return materialTheme
        .theme(colorScheme)
        .copyWith(
          scaffoldBackgroundColor: const Color(0xffF3F4F6),
          appBarTheme: AppBarTheme(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary),
          ),
          drawerTheme: DrawerThemeData(
            backgroundColor: colorScheme.onPrimary,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
        );
  }

  static ThemeData get darkTheme {
    final colorScheme = MaterialTheme.darkScheme();
    final textTheme = _buildTextTheme(colorScheme);
    final materialTheme = MaterialTheme(textTheme);

    return materialTheme
        .theme(colorScheme)
        .copyWith(
          appBarTheme: AppBarTheme(
            backgroundColor: colorScheme.onPrimary,
            foregroundColor: colorScheme.onTertiaryContainer,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onTertiaryContainer),
          ),
          drawerTheme: DrawerThemeData(
            backgroundColor: colorScheme.onPrimary,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
        );
  }
}

//? Fuentes
// | Estilo                           | Tamaño aprox. | Uso común                        |
// | -------------------------------- | ------------- | -------------------------------- |
// | `displayLarge`                   | 57.0          | Titulares principales            |
// | `displayMedium`                  | 45.0          | Titulares secundarios            |
// | `displaySmall`                   | 36.0          | Titulares grandes                |
// | `headlineLarge`                  | 32.0          | Encabezado                       |
// | `headlineMedium`                 | 28.0          | Subtítulo                        |
// | `headlineSmall`                  | 24.0          | Secciones                        |
// | `titleLarge`                     | 22.0          | Títulos                          |
// | `titleMedium`                    | 16.0          | Título más pequeño (como AppBar) |
// | `titleSmall`                     | 14.0          | Subtítulos menores               |
// | `bodyLarge`                      | 16.0          | Texto principal                  |
// | `bodyMedium`                     | 14.0          | Texto normal                     |
// | `bodySmall`                      | 12.0          | Notas, descripciones             |
// | `labelLarge`, `labelSmall`, etc. | 11–14.0       | Botones, badges                  |
