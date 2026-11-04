/// Check-in state provider (PRD sections 4.5, 4.6).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:provider/provider.dart';

import '../models/check_in/check_in_model.dart';
import '../services/check_in/check_in_service.dart';

class CheckInProvider extends ChangeNotifier {
  CheckInProvider(this._checkInService);

  final CheckInService _checkInService;

  List<CheckInModel> _checkIns = [];
  bool _isLoading = false;
  String? _error;

  List<CheckInModel> get checkIns => _checkIns;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

  Future<void> syncPendingCheckIns() async {
    await _checkInService.syncPendingCheckIns();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
