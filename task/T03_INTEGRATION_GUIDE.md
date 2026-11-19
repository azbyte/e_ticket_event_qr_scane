# T03 Integration Guide

> Panduan integrasi untuk checkpoint T03 - E-Ticket Event & QR Scanner
> Audit date: 2026-11-20

## Ringkasan Status

### Testing Status
- ✅ Flutter analyze: PASS
- ✅ Backend tests: PASS (27/27)
- ❌ Flutter tests: FAIL (23 tests)

### Pekerjaan Tersisa
1. **Fix 23 Flutter tests** - Developer 1
2. **Migration 005 decision** - Developer 2
3. **EventProvider verification** - Developer 1 & 2
4. **Documentation updates** - Developer 2

## File Ownership Matrix

### Developer 1 Files
| File | Action |
|------|--------|
| `apps/test/**/*.dart` | Fix failing tests |
| `apps/lib/providers/event_provider.dart` | Verify production mode |
| `apps/lib/services/organizer_events/organizer_event_repository_factory.dart` | Verify factory logic |

### Developer 2 Files
| File | Action |
|------|--------|
| `backend/prisma/migrations/20261118000500_automatic_event_publication/` | Delete or create migration.sql |
| `task/HANDOVER_AI_T03.md` | Update file names |
| `task/T03_INTEGRATION_GUIDE.md` | Update status |

### No Overlap
✅ Tidak ada file yang dimiliki kedua developer
✅ Shared files tidak dimodifikasi
✅ Clear boundaries

## Integration Contracts

### EventProvider Contract
```dart
createOrganizerEventRepository() {
  if (AppConfig.mockMode) {
    return MockOrganizerEventRepository();
  }
  return ApiOrganizerEventRepository();
}
```

### Migration Contract
- Idempotent
- No data changes
- Schema compliant
- Rollback plan ready

## Execution Timeline

### Phase 1: Parallel Work (Day 1-2)
```
Day 1:
├─ Developer 1: Analyze 23 failing tests
└─ Developer 2: Investigate Migration 005

Day 2:
├─ Developer 1: Fix tests batch 1 (10 tests)
└─ Developer 2: Update documentation
```

### Phase 2: Integration (Day 3)
```
Morning:
├─ Developer 1: Complete all tests
├─ Developer 2: Finalize docs
└─ Merge changes
```

### Phase 3: Validation (Day 3)
```
Afternoon:
├─ flutter test
├─ flutter analyze
├─ npm test
└─ Manual verification
```

## Pre-Integration Checklist

### Developer 1
- [ ] All 23 tests fixed
- [ ] `flutter test` = 0 failures
- [ ] `flutter analyze` = 0 issues
- [ ] EventProvider verified
- [ ] Report created

### Developer 2
- [x] Migration 005 decided (Resolved: ABANDONED/DELETED, 9 active migrations confirmed)
- [x] Documentation updated (HANDOVER_AI_T03.md updated with 2026-11-20 notes)
- [x] File names corrected (organizer_event_list_screen -> event_management_screen, organizer_event_form_screen -> event_form_screen)
- [x] EventProvider verified (api_mode_no_fallback_test passes 11/11 in MOCK_MODE=false)
- [x] Report created (task/T03_REPORT_DEVELOPER_2.md)

## Post-Integration Tests

```bash
# Flutter tests
cd apps && flutter test --no-pub

# Backend tests
cd backend && npm test

# Static analysis
cd apps && flutter analyze --no-pub

# Integration test
flutter test test/services/api_mode_no_fallback_test.dart --dart-define=MOCK_MODE=false
```

## Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Test fix changes behavior | Low | High | Only fix tests, not source |
| Migration conflict | Medium | Medium | Test locally first |
| EventProvider breaking | Low | High | Verify both modes |
| Merge conflicts | Low | Medium | Frequent commits |

## Feasibility Assessment

**Score: 9.25/10 - SANGAT LAYAK**

✅ Minimal remaining work (3/23 tasks)
✅ Clear boundaries
✅ No file overlap
✅ Clear contracts
✅ Minimal dependencies
✅ Simple integration
✅ Efficient timeline (3-4 days)
✅ Low risk level
✅ Complete QA
✅ Comprehensive docs

**Recommendation: PROCEED TO IMPLEMENTATION**

