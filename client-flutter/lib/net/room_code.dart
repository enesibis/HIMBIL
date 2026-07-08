import 'dart:math';

/// Mirrors server/rooms/roomCode.ts's alphabet exactly (no shared code
/// between the two runtimes, so keep these in sync by hand): excludes
/// 0/O and 1/I so a code read aloud or hand-copied between phones doesn't
/// produce silent join failures.
const String roomCodeAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const int roomCodeLength = 6;

/// Generates a room code in the client's local/offline (bot-only) mode,
/// where there is no real server to assign one. Kept in the same format as
/// the server's real codes so the UI doesn't change shape once a screen is
/// wired to `HimbilNetClient`.
String generateLocalRoomCode([Random? random]) {
  final rng = random ?? Random();
  return List.generate(roomCodeLength, (_) => roomCodeAlphabet[rng.nextInt(roomCodeAlphabet.length)]).join();
}
