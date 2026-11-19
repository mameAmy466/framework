/// Framework Flutter aCAN pour l'API TVE v3.
///
/// Une nouvelle app = un [TveConfig] (variables) + un [TveDesign] (design) :
/// ```dart
/// void main() => runTveApp(
///   config: const TveConfig(group: 'leraltv'),
///   design: const TveDesign(primary: Color(0xFFE30613), googleFont: 'Poppins'),
/// );
/// ```
library;

// API
export 'src/api/tve_client.dart';
export 'src/api/tve_exception.dart';
// Modèles
export 'src/models/catalog.dart';
export 'src/models/common.dart';
export 'src/models/group.dart';
export 'src/models/json.dart' show Json;
export 'src/models/media.dart';
// Config & design
export 'src/config/tve_config.dart';
export 'src/config/tve_design.dart';
export 'src/config/tve_strings.dart';
// UI
export 'src/ui/tve_app.dart';
export 'src/ui/tve_home.dart';
export 'src/ui/tve_scope.dart';
export 'src/ui/screens/about_screen.dart';
export 'src/ui/screens/live_screen.dart';
export 'src/ui/screens/news_screen.dart';
export 'src/ui/screens/podcasts_screen.dart';
export 'src/ui/screens/radio_screen.dart';
export 'src/ui/screens/replay_screen.dart';
export 'src/ui/screens/schedule_screen.dart';
export 'src/ui/screens/search_screen.dart';
export 'src/ui/screens/shorts_screen.dart';
export 'src/ui/widgets/cards.dart';
export 'src/ui/widgets/paged_list.dart';
export 'src/ui/widgets/states.dart';
export 'src/ui/widgets/tve_audio.dart';
export 'src/ui/widgets/tve_image.dart';
export 'src/ui/widgets/tve_video_player.dart';
export 'src/ui/widgets/tve_youtube_player.dart';
