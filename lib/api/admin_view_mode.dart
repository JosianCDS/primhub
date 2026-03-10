import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AdminViewMode { mixed, support, project }

class AdminViewModeManager extends ChangeNotifier {
  static final AdminViewModeManager _instance = AdminViewModeManager._internal();
  factory AdminViewModeManager() => _instance;
  AdminViewModeManager._internal();

  AdminViewMode _currentMode = AdminViewMode.mixed;
  AdminViewMode get currentMode => _currentMode;

  Future<void> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('admin_view_mode');
    switch (modeString) {
      case 'support':
        _currentMode = AdminViewMode.support;
        break;
      case 'project':
        _currentMode = AdminViewMode.project;
        break;
      default:
        _currentMode = AdminViewMode.mixed;
        break;
    }
    notifyListeners();
  }

  Future<void> saveMode(AdminViewMode mode) async {
    if (_currentMode == mode) return; // No hacer nada si el modo es el mismo

    _currentMode = mode;
    notifyListeners(); // Notificar a los listeners ANTES de la operación asíncrona

    final prefs = await SharedPreferences.getInstance();
    String modeString;
    switch (mode) {
      case AdminViewMode.support:
        modeString = 'support';
        break;
      case AdminViewMode.project:
        modeString = 'project';
        break;
      default:
        modeString = 'mixed';
        break;
    }
    await prefs.setString('admin_view_mode', modeString);
  }

  String getModeName(AdminViewMode mode) {
    return mode.toString().split('.').last; // 'mixed', 'support', 'project'
  }
}
