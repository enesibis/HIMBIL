import 'package:app_links/app_links.dart';

/// Parses/exposes `himbil://join/<CODE>` invite links (madde #58) — a
/// friend tapping a shared link should land straight in the join flow with
/// the room code already filled in, instead of retyping it by hand.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();

  /// The room code from `himbil://join/<CODE>`, or null if [uri] isn't a
  /// recognized invite link.
  static String? roomCodeFrom(Uri uri) {
    if (uri.scheme != 'himbil' || uri.host != 'join') return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return segments.first.toUpperCase();
  }

  /// The room code the app was cold-started with, if any (e.g. the user
  /// tapped an invite link while the app wasn't running).
  Future<String?> getInitialRoomCode() async {
    final uri = await _appLinks.getInitialLink();
    return uri == null ? null : roomCodeFrom(uri);
  }

  /// Room codes from invite links opened while the app is already running.
  Stream<String> get roomCodeStream =>
      _appLinks.uriLinkStream.map(roomCodeFrom).where((code) => code != null).cast<String>();
}
