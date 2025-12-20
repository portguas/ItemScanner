import 'package:flutter/foundation.dart';

import '../services/scan_service.dart';

class HomeState extends ChangeNotifier {
  String status = 'Ready';
  String? currentTitle;
  Map<String, String> scalarData = {};
  Map<String, List<Map<String, dynamic>>> tableData = {};
  bool checkingZip = false;

  void setStatus(String value) {
    status = value;
    notifyListeners();
  }

  void setChecking(bool value) {
    checkingZip = value;
    notifyListeners();
  }

  void setDocument(DocumentData doc) {
    currentTitle = doc.title;
    scalarData = doc.scalar;
    tableData = doc.tables;
    notifyListeners();
  }

  void clearDisplay() {
    currentTitle = null;
    scalarData = {};
    tableData = {};
    notifyListeners();
  }
}
