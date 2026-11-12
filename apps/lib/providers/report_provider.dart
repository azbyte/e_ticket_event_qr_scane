/// Support report state provider (PRD sections 4.10, 6.8, FR-94 s.d. FR-101).
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

  void clearSelectedReport() {
    _selectedReport = null;
    notifyListeners();
  }

  /// Loads reports with optional filters.
  Future<bool> loadReports({Map<String, dynamic>? query}) async {
    _setLoading(true);
    _error = null;
    try {
      final list = await _reportService.listReports(query: query);
      _reports = list.map((e) => SupportReportModel.fromJson(e)).toList();
      if (_selectedReport != null) {
        final match = _reports.where((r) => r.id == _selectedReport!.id);
        if (match.isNotEmpty) {
          _selectedReport = match.first;
        }
      }
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
    String? subject,
    String? priority,
    String? orderReference,
    String? userId,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final payload = {
        'contact_email': contactEmail,
        'category': category,
        'subject': subject ?? 'Laporan Baru',
        'description': description,
        'priority': priority ?? 'medium',
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
    String handledBy = 'Admin Platform',
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _reportService.updateReportStatus(
        reportId: reportId,
        status: status,
        note: note,
        handledBy: handledBy,
      );
      if (data['success'] == false) {
        _error = data['message']?.toString() ?? 'Gagal memperbarui status';
        return false;
      }
      await loadReports();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Updates report priority (FR-98).
  Future<bool> updatePriority({
    required String reportId,
    required String priority,
    String handledBy = 'Admin Platform',
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _reportService.updateReportPriority(
        reportId: reportId,
        priority: priority,
        handledBy: handledBy,
      );
      if (data['success'] == false) {
        _error = data['message']?.toString() ?? 'Gagal memperbarui prioritas';
        return false;
      }
      await loadReports();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Adds a public reply to reporter (FR-99).
  Future<bool> addReply({
    required String reportId,
    required String message,
    String senderName = 'Admin Platform',
    String senderRole = 'Admin Platform',
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _reportService.addReply(
        reportId: reportId,
        message: message,
        senderName: senderName,
        senderRole: senderRole,
      );
      if (data['success'] == false) {
        _error = data['message']?.toString() ?? 'Gagal mengirim balasan';
        return false;
      }
      await loadReports();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Adds an internal note strictly hidden from reporter (FR-99, FR-101).
  Future<bool> addInternalNote({
    required String reportId,
    required String note,
    String authorName = 'Admin Platform',
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _reportService.addInternalNote(
        reportId: reportId,
        note: note,
        authorName: authorName,
      );
      if (data['success'] == false) {
        _error = data['message']?.toString() ?? 'Gagal menambahkan catatan internal';
        return false;
      }
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
