# T03 Developer 1 - Frontend Testing & Provider Verification

> Handover document untuk Developer 1  
> Start date: 2026-11-20  
> Estimated duration: 2-3 days

---

## Your Mission

1. Fix 23 failing Flutter tests
2. Verify EventProvider production mode
3. Ensure `flutter test` = 0 failures

---

## Current Status

```
✅ Flutter analyze: PASS
✅ Backend tests: PASS (27/27)
❌ Flutter tests: FAIL (23 tests)
```

---

## Failing Tests Location

| File | Count | Error Type |
|------|-------|------------|
| `apps/test/developer_2_flow_test.dart` | 4 | pumpAndSettle timeout |
| `apps/test/features/admin/operations/report_management_screen_test.dart` | 2 | pumpAndSettle timeout |
| Other admin/organizer test files | 17 | Various errors |

---

## Step-by-Step Execution

### Step 1: Analyze Failing Tests (2-3 hours)

```bash
cd apps
flutter test --no-pub 2>&1 | Select-String -Pattern "EXCEPTION|Error|failed" -Context 5
```

**Goal:** Identify root cause for each failing test

**Common errors:**
1. `pumpAndSettle timed out` - Animation/async not finishing
2. `MissingPluginException` - Plugin not available in test
3. `Assertion failures` - Expected != actual
4. `Widget not found` - Widget not rendered or wrong key

---

### Step 2: Fix Tests Batch 1 (3-4 hours)

**Priority:**
1. `developer_2_flow_test.dart` (4 tests)
2. `report_management_screen_test.dart` (2 tests)
3. Other critical tests (4 tests)

**Fix example for pumpAndSettle timeout:**

```dart
// Before:
await tester.pumpAndSettle();

// After:
await tester.pumpAndSettle(timeout: Duration(seconds: 5));
// OR
await tester.pump();
await tester.pump(Duration(seconds: 1));
```

**Fix example for MissingPluginException:**

```dart
setUp(() {
  const MethodChannel('plugins.flutter.io/flutter_secure_storage')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    return null;
  });
});
```

---

### Step 3: Fix Tests Batch 2 (3-4 hours)

Continue fixing remaining 13 tests using same approach.

---

### Step 4: Verify EventProvider (1-2 hours)

**Test mock mode:**
```bash
### Step 5: Run Full Test Suite (30 minutes)

```bash
cd apps
flutter test --no-pub
# Expected: All tests pass (0 failures)

flutter analyze --no-pub
# Expected: No issues found
```

---

### Step 6: Create Report (1-2 hours)

Create file: `task/DEVELOPER_1_REPORT.md`

**Report template:**
```markdown
# Developer 1 Report

## Summary
- Total failing tests: 23
- Fixed tests: 23
- Remaining failures: 0

## Test Fixes

### developer_2_flow_test.dart
- Test 1: [name]
  - Root cause: [cause]
  - Fix: [solution]
  - File: [path]

[Continue for all tests...]

## EventProvider Verification

### Mock Mode
- Command: `flutter test ... --dart-define=MOCK_MODE=true`
- Result: PASS/FAIL
- Repository: MockOrganizerEventRepository

### Production Mode
- Command: `flutter test ... --dart-define=MOCK_MODE=false`
- Result: PASS/FAIL
- Repository: ApiOrganizerEventRepository

### Factory Logic
- File: `organizer_event_repository_factory.dart`
- Status: Verified/Fixed
- Changes: [if any]

## Files Modified
1. `apps/test/developer_2_flow_test.dart` - Fixed 4 tests
2. [Continue for all files...]

## Test Results

### Before
flutter test --no-pub
00:15 +127 -23: Some tests failed.

### After
flutter test --no-pub
00:12 +150 -0: All tests passed!

## Issues Found
1. [Issue 1]
2. [Issue 2]

## Recommendations
## Integration Contract

### EventProvider Contract
```dart
class EventProvider extends ChangeNotifier {
  EventProvider({
    OrganizerEventRepository? repository,
    // ...
  }) : _repository = repository ?? createOrganizerEventRepository();
}

// Contract:
// - createOrganizerEventRepository() returns:
//   - ApiOrganizerEventRepository if AppConfig.mockMode == false
//   - MockOrganizerEventRepository if AppConfig.mockMode == true
// - Repository cannot be null
// - OwnerId must be available
```

### Repository Contract
```dart
abstract class OrganizerEventRepository {
  Future<List<EventModel>> listEvents({...});
  Future<EventModel> createEvent({...});
  Future<EventModel> updateEvent({...});
  Future<bool> deleteEvent(String eventId);
}

// Contract:
// - All methods return Future
## Timeline Estimate

| Task | Duration |
|------|----------|
| Analyze failing tests | 2-3 hours |
| Fix tests batch 1 | 3-4 hours |
| Fix tests batch 2 | 3-4 hours |
| Verify EventProvider | 1-2 hours |
| Create report | 1-2 hours |
| **TOTAL** | **10-15 hours (2-3 days)** |

---

## Success Criteria

### Must Have ✅
1. All 23 failing tests passing
2. `flutter test` = 0 failures
3. `flutter analyze` = 0 issues
4. EventProvider verified for production mode
5. DEVELOPER_1_REPORT.md complete

### Should Have 👍
1. Root cause documented for each fix
2. Recommendations for future improvements
3. Test coverage maintained

### Nice to Have 💡
1. Test code refactored for maintainability
2. Additional edge case tests

---

## Dependencies

### Required
1. Flutter test framework
2. Provider package
3. AppConfig
4. OrganizerEventRepository interface

### Blockers
✅ **NONE** - You can start immediately

---

## Escalation

### Questions?
1. Read T03_INTEGRATION_GUIDE.md
2. Read T03_DEVELOPER_2.md
3. Check HANDOVER_AI_T03.md

### Blockers?
1. Document in DEVELOPER_1_REPORT.md
2. Escalate to project lead
3. Continue with non-blocked work

### Need Developer 2 file changes?
1. DO NOT modify Developer 2 files
2. Report in DEVELOPER_1_REPORT.md
3. Coordinate with Developer 2

---

**Document created: 2026-11-20**  
**Status: READY TO START**

// - Errors thrown as OrganizerEventException
// - Data matches defined models
```

---

## Convergence Checklist

Before completing your work, ensure:

- [ ] All 23 failing tests fixed
- [ ] `flutter test` = 0 failures
- [ ] `flutter analyze` = 0 issues
- [ ] EventProvider works in mock mode
- [ ] EventProvider works in production mode
- [ ] No changes to UI Organizer files
- [ ] No changes to backend files
- [ ] No changes to migration files
- [ ] DEVELOPER_1_REPORT.md created
- [ ] Commit message clear and descriptive

---

## Mandatory Rules

1. ✅ Read handover document before starting
2. ✅ Check file conditions before modifying
3. ✅ Only modify YOUR files
4. ❌ DO NOT modify Developer 2 files
5. ❌ DO NOT refactor outside scope
6. ❌ DO NOT change database schema/config/API contracts
7. ❌ DO NOT replace Developer 2 implementations
8. ✅ Follow integration contracts
9. ✅ Test your implementation
10. ✅ Report all files created/modified/deleted
11. ✅ If you need changes to Developer 2 files, REPORT don't modify
12. ✅ Report out-of-scope issues, don't fix them
13. ❌ DO NOT claim done if tests fail
14. ❌ DO NOT change PRD or expand T03 scope
15. ❌ DO NOT make unnecessary changes

---

1. [Recommendation 1]
2. [Recommendation 2]
```

---

cd apps
flutter test test/services/api_mode_no_fallback_test.dart --dart-define=MOCK_MODE=true
```
Expected: PASS, uses MockOrganizerEventRepository

**Test production mode:**
```bash
flutter test test/services/api_mode_no_fallback_test.dart --dart-define=MOCK_MODE=false
```
Expected: PASS, uses ApiOrganizerEventRepository, NO fallback to mock

**Verify factory logic:**
```dart
// File: apps/lib/services/organizer_events/organizer_event_repository_factory.dart
OrganizerEventRepository createOrganizerEventRepository() {
  if (AppConfig.mockMode) {
    return MockOrganizerEventRepository();
  }
  return ApiOrganizerEventRepository();
}
```

If factory is wrong, fix it to match the logic above.

---

## Your Files (ALLOWED to modify)

✅ `apps/test/**/*.dart` - All test files  
✅ `apps/lib/providers/event_provider.dart` - Only for verification  
✅ `apps/lib/services/organizer_events/organizer_event_repository_factory.dart` - Only for verification

---

## Files You CANNOT Touch

❌ `apps/lib/features/organizer/**/*.dart` - UI already complete  
❌ `backend/**/*.js` - Backend already complete  
❌ `backend/prisma/migrations/**` - Developer 2 responsibility  
❌ `task/HANDOVER_AI_T03.md` - Developer 2 responsibility

---

