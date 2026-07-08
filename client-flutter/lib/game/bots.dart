/// Botların tek kaynağı: id, görünen isim, masadaki konum. Lobi ve oyun
/// ekranı ayrı ayrı isim listesi tutuyordu ve sırayla eşleşmiyordu
/// (bkz. yapılması-gerekenler #13); artık ikisi de buradan okur.
enum BotPosition { north, west, east }

class BotDefinition {
  final String id;
  final String name;
  final BotPosition position;

  const BotDefinition({required this.id, required this.name, required this.position});
}

class Bots {
  Bots._();

  static const List<BotDefinition> all = [
    BotDefinition(id: 'bot_north', name: 'Mehmet', position: BotPosition.north),
    BotDefinition(id: 'bot_west', name: 'Zeynep', position: BotPosition.west),
    BotDefinition(id: 'bot_east', name: 'Ayşe', position: BotPosition.east),
  ];

  static String labelFor(String id) => all.firstWhere((b) => b.id == id).name;
}
