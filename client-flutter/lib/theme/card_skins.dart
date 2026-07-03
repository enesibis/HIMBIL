/// Mağazada satılan kart sırtı (kart arkası) tasarımı.
/// Görseller `design/design_handoff_kart_paketi/kart-sirtlari/` paketinden
/// (5:7 oranlı, 60x84 viewBox SVG) `assets/card_backs/`'e kopyalanmıştır.
class CardSkin {
  final String id;
  final String name;
  final int price;
  final String assetPath;

  const CardSkin({required this.id, required this.name, required this.price, required this.assetPath});

  bool get isFree => price == 0;
}

/// Fiyatlar `design_handoff_kart_paketi/README.md`'deki öneri tabloyla birebir.
class CardSkins {
  CardSkins._();

  static const all = [
    CardSkin(id: 'klasik', name: 'Klasik', price: 0, assetPath: 'assets/card_backs/klasik.svg'),
    CardSkin(id: 'karnaval', name: 'Karnaval', price: 0, assetPath: 'assets/card_backs/karnaval.svg'),
    CardSkin(id: 'retro', name: 'Retro Şerit', price: 200, assetPath: 'assets/card_backs/retro.svg'),
    CardSkin(id: 'karpuz', name: 'Karpuz Dilimi', price: 250, assetPath: 'assets/card_backs/karpuz.svg'),
    CardSkin(id: 'limonata', name: 'Limonata', price: 250, assetPath: 'assets/card_backs/limonata.svg'),
    CardSkin(id: 'cilek', name: 'Çilek Reçeli', price: 300, assetPath: 'assets/card_backs/cilek.svg'),
    CardSkin(id: 'petek', name: 'Bal Peteği', price: 300, assetPath: 'assets/card_backs/petek.svg'),
    CardSkin(id: 'tutti', name: 'Meyve Şöleni', price: 350, assetPath: 'assets/card_backs/tutti.svg'),
    CardSkin(id: 'uykucu', name: 'Uykucu Hımbıl', price: 400, assetPath: 'assets/card_backs/uykucu.svg'),
    CardSkin(id: 'kilim', name: 'Anadolu Kilim', price: 450, assetPath: 'assets/card_backs/kilim.svg'),
    CardSkin(id: 'gece', name: 'Gece Pazarı', price: 450, assetPath: 'assets/card_backs/gece.svg'),
    CardSkin(id: 'nazar', name: 'Nazar Boncuğu', price: 500, assetPath: 'assets/card_backs/nazar.svg'),
    CardSkin(id: 'altin', name: 'Altın Varak', price: 500, assetPath: 'assets/card_backs/altin.svg'),
    CardSkin(id: 'yildiz', name: 'Yıldız Tozu', price: 750, assetPath: 'assets/card_backs/yildiz.svg'),
    CardSkin(id: 'elmas', name: 'Elmas', price: 900, assetPath: 'assets/card_backs/elmas.svg'),
  ];

  static const defaultSkinId = 'klasik';

  static CardSkin byId(String id) => all.firstWhere((s) => s.id == id, orElse: () => all.first);
}
