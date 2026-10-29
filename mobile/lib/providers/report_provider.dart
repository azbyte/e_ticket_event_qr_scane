/// Support report state provider (PRD section 4.10).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:provider/provider.dart';

import '../models/report/support_report_model.dart';
import '../services/report/report_service.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider(this._reportService);

  final ReportService _reportService;

  List<SupportReportModel> _reports = [];
  SupportReportModel? _selectedReport;
  bool _isLoading = false;
  String? _error;

  List<SupportReportModel> get reports => _reports;
  SupportReportModel? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> loadReports({Map<String, dynamic>? query}) async {
    _setLoading(true);
    _error = null;
    try {
      final list = await _reportService.listReports(query: query);
      _reports = list.map((e) => SupportReportModel.fromJson(e)).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loadReport(String reportId) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _reportService.getReport(reportId);
      _selectedReport = SupportReportModel.fromJson(data);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateStatus({
    required String reportId,
    required String status,
    String? note,
  }) async {
    _error = null;
    try {
      final data = await _reportService.updateReportStatus(
        reportId: reportId,
        status: status,
        note: note,
      );
      _selectedReport = SupportReportModel.fromJson(data);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
