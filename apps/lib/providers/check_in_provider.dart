/// Check-in state provider (PRD sections 4.5, 4.6, 4.7).
///
/// Manages check-in lists, attendee verification, QR token processing,
/// offline queue, and sync status for staff and organizers.
library;

import 'package:flutter/foundation.dart';

import '../models/check_in/check_in_model.dart';
import '../services/check_in/check_in_service.dart';
import '../services/scanner/scanner_service.dart';

class CheckInProvider extends ChangeNotifier {
  CheckInProvider(this._checkInService, {ScannerService? scannerService})
      : _scannerService = scannerService ?? ScannerService(checkInService: _checkInService);

  final CheckInService _checkInService;
  final ScannerService _scannerService;

  List<CheckInModel> _checkIns = [];
  List<Map<String, dynamic>> _attendees = [];
  bool _isLoading = false;
  String? _error;
  bool _isOfflineMode = false;
  Map<String, dynamic>? _lastScanResult;

  List<CheckInModel> get checkIns => _checkIns;
  List<Map<String, dynamic>> get attendees => _attendees;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOfflineMode => _isOfflineMode;
  Map<String, dynamic>? get lastScanResult => _lastScanResult;
  int get pendingOfflineCount => _checkInService.pendingOfflineCount;

  /// Toggles between online mode and local offline queue mode.
  void toggleOfflineMode(bool value) {
    _isOfflineMode = value;
    notifyListeners();
  }

  /// Loads check-in history records for an event.
  Future<bool> loadCheckIns({
    required String eventId,
    Map<String, dynamic>? query,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final list = await _checkInService.listCheckIns(
        eventId: eventId,
        query: query,
      );
      _checkIns = list.map((e) => CheckInModel.fromJson(e)).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Loads list of attendees for an event.
  Future<bool> loadAttendees({required String eventId}) async {
    _setLoading(true);
    _error = null;
    try {
      _attendees = await _checkInService.listAttendees(eventId: eventId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Validates and processes a scanned QR token.
  Future<Map<String, dynamic>> processTicketScan(
    String token, {
    required String staffId,
    String staffName = 'Staf Event',
    String eventId = 'evt-001',
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final validation = await _scannerService.validateTicket(token);

      if (validation['valid'] == true && validation['ticket'] != null) {
        final ticketData = validation['ticket'] as Map<String, dynamic>;
        final ticketId = ticketData['id'] as String? ?? ticketData['token'] as String;

        // Record check-in
        final recordResult = await _scannerService.recordCheckIn(
          ticketId: ticketId,
          eventId: eventId,
          staffId: staffId,
          staffName: staffName,
          isOffline: _isOfflineMode,
        );

        final result = {
          'status': _isOfflineMode ? 'queued_offline' : 'valid',
          'valid': true,
          'message': _isOfflineMode
              ? 'Tersimpan di antrean offline'
              : 'Check-in Berhasil',
          'ticket': ticketData,
          'check_in': recordResult['check_in'],
          'is_offline': _isOfflineMode,
        };
        _lastScanResult = result;
        await loadCheckIns(eventId: eventId);
        await loadAttendees(eventId: eventId);
        notifyListeners();
        return result;
      } else {
        final result = {
          'status': validation['status'] ?? 'invalid',
          'valid': false,
          'message': validation['message'] ?? 'Tiket tidak valid',
          'ticket': validation['ticket'],
          'is_offline': _isOfflineMode,
        };
        _lastScanResult = result;
        notifyListeners();
        return result;
      }
    } catch (e) {
      _error = e.toString();
      final errResult = {
        'status': 'error',
        'valid': false,
        'message': 'Terjadi kesalahan sistem saat pemindaian: $e',
        'is_offline': _isOfflineMode,
      };
      _lastScanResult = errResult;
      notifyListeners();
      return errResult;
    } finally {
      _setLoading(false);
    }
  }

  /// Performs manual check-in by ticket ID.
  Future<bool> manualCheckIn(
    String ticketId, {
    required String eventId,
    required String staffId,
    String staffName = 'Staf Event',
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final res = await _checkInService.recordCheckIn(
        ticketId: ticketId,
        eventId: eventId,
        staffId: staffId,
        staffName: staffName,
        isOffline: _isOfflineMode,
      );

      if (res['success'] == true) {
        await loadCheckIns(eventId: eventId);
        await loadAttendees(eventId: eventId);
        return true;
      } else {
        _error = res['message'] as String? ?? 'Gagal melakukan check-in';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Submits pending offline check-ins.
  Future<int> syncPendingCheckIns({String eventId = 'evt-001'}) async {
    _setLoading(true);
    _error = null;
    try {
      final count = await _checkInService.syncPendingCheckIns();
      await loadCheckIns(eventId: eventId);
      notifyListeners();
      return count;
    } catch (e) {
      _error = e.toString();
      return 0;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
