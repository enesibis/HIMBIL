/// Mağazada satılan avatar çerçevesi. Görseller
/// `design/design_handoff_cerceve_paketi/cerceveler-svg/` paketinden
/// (72x72 viewBox, avatar deliği ~26-34 yarıçap) `assets/frames/`'e
/// kopyalanmıştır. Avatar, kutunun ~%72'si çapında ortalanır; çerçeve
/// tam kutu boyutunda üstüne bindirilir (bkz. `UserAvatar`).
class AvatarFrameSkin {
  final String id;
  final String name;
  final int price;
  final String assetPath;

  const AvatarFrameSkin({required this.id, required this.name, required this.price, required this.assetPath});

  bool get isFree => price == 0;
}

/// Fiyatlar `design_handoff_cerceve_paketi/README.md`'deki tabloyla birebir.
class AvatarFrameSkins {
  AvatarFrameSkins._();

  static const all = [
    AvatarFrameSkin(id: 'standart', name: 'Standart', price: 0, assetPath: 'assets/frames/standart.svg'),
    AvatarFrameSkin(id: 'alev', name: 'Alev', price: 0, assetPath: 'assets/frames/alev.svg'),
    AvatarFrameSkin(id: 'simit', name: 'Susamlı Simit', price: 250, assetPath: 'assets/frames/simit.svg'),
    AvatarFrameSkin(id: 'karpuz', name: 'Karpuz Dilimi', price: 250, assetPath: 'assets/frames/karpuz.svg'),
    AvatarFrameSkin(id: 'papatya', name: 'Papatya', price: 300, assetPath: 'assets/frames/papatya.svg'),
    AvatarFrameSkin(id: 'konfeti', name: 'Konfeti', price: 300, assetPath: 'assets/frames/konfeti.svg'),
    AvatarFrameSkin(id: 'misket', name: 'Misket', price: 350, assetPath: 'assets/frames/misket.svg'),
    AvatarFrameSkin(id: 'lale', name: 'Lale Bahçesi', price: 400, assetPath: 'assets/frames/lale.svg'),
    AvatarFrameSkin(id: 'petek', name: 'Bal Peteği', price: 400, assetPath: 'assets/frames/petek.svg'),
    AvatarFrameSkin(id: 'kilim', name: 'Anadolu Kilim', price: 450, assetPath: 'assets/frames/kilim.svg'),
    AvatarFrameSkin(id: 'gece', name: 'Gece Yıldızları', price: 450, assetPath: 'assets/frames/gece.svg'),
    AvatarFrameSkin(id: 'nazar', name: 'Nazar Boncuğu', price: 500, assetPath: 'assets/frames/nazar.svg'),
    AvatarFrameSkin(id: 'tac', name: 'Altın Taç', price: 600, assetPath: 'assets/frames/tac.svg'),
    AvatarFrameSkin(id: 'yildiz', name: 'Yıldız Tozu', price: 750, assetPath: 'assets/frames/yildiz.svg'),
    AvatarFrameSkin(id: 'elmas', name: 'Elmas', price: 900, assetPath: 'assets/frames/elmas.svg'),
  ];

  static const defaultFrameId = 'standart';

  static AvatarFrameSkin byId(String id) => all.firstWhere((f) => f.id == id, orElse: () => all.first);
}
