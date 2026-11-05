/// Support report state provider (PRD section 4.10).
///
/// Manages support tickets for attendees, admins, and support agents.
library;

import 'package:flutter/foundation.dart';

import '../models/report/support_report_model.dart';
import '../services/report/report_service.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider({ReportService? reportService})
      : _reportService = reportService ?? ReportService();

  final ReportService _reportService;

  List<SupportReportModel> _reports = [];
  SupportReportModel? _selectedReport;
  bool _isLoading = false;
  String? _error;

  List<SupportReportModel> get reports => _reports;
  SupportReportModel? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads reports with optional filters.
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

  /// Loads a specific report by ID or ticket number.
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

  /// Creates a new support report.
  Future<SupportReportModel?> createReport({
    required String contactEmail,
    required String category,
    required String description,
    String? orderReference,
    String? userId,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final payload = {
        'contact_email': contactEmail,
        'category': category,
        'description': description,
        'order_reference': orderReference ?? '',
        'user_id': userId,
      };
      final data = await _reportService.createReport(payload);
      final created = SupportReportModel.fromJson(data);
      _reports.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Updates report status (Admin action).
  Future<bool> updateStatus({
    required String reportId,
    required String status,
    String? note,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await _reportService.updateReportStatus(
        reportId: reportId,
        status: status,
        note: note,
      );
      await loadReports();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
