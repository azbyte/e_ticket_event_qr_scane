import '../../core/config/app_config.dart';
import 'api_organizer_event_repository.dart';
import 'mock_organizer_event_repository.dart';
import 'organizer_event_repository.dart';

OrganizerEventRepository createOrganizerEventRepository() => AppConfig.mockMode
    ? MockOrganizerEventRepository.shared()
    : ApiOrganizerEventRepository();
