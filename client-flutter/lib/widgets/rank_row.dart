import 'package:flutter/material.dart';

import '../theme/text_styles.dart';

/// Bir sıralamadaki tek bir oyuncu satırı — bir isim ve o sıradaki puanı.
/// `MapEntry<String,int>`'in yerini alır; okunabilirliği düşüren anlamsız
/// key/value çiftinin yerine anlamlı alan adları verir.
class RankEntry {
  final String label;
  final int points;

  const RankEntry(this.label, this.points);
}

/// round_result, slam_celebration ve game_over ekranlarında tekrarlanan
/// "numaralı rozet + isim + puan" satırının ortak gövdesi. Üç ekran da
/// kendi görsel kimliğini (renk, punto, animasyon) korur; yalnız Row/badge
/// iskeleti burada birleşir.
class RankRow extends StatelessWidget {
  final int rank;
  final RankEntry entry;
  final Color badgeColor;
  final TextStyle nameStyle;
  final TextStyle pointsStyle;
  final Decoration decoration;
  final String pointsPrefix;
  final double badgeSize;
  final double badgeTextSize;
  final double gap;
  final double? width;
  final EdgeInsetsGeometry padding;

  const RankRow({
    super.key,
    required this.rank,
    required this.entry,
    required this.badgeColor,
    required this.nameStyle,
    required this.pointsStyle,
    required this.decoration,
    this.pointsPrefix = '',
    this.badgeSize = 28,
    this.badgeTextSize = 13,
    this.gap = 12,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: decoration,
      child: Row(
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$rank', style: AppText.nunito(size: badgeTextSize, weight: FontWeight.w800, color: Colors.white)),
          ),
          SizedBox(width: gap),
          // Uzun isimler ikinci satıra sarıp satır yüksekliğini değiştirmesin
          // (tur sonuçları ekranındaki "kayma" şikâyetinin kaynağı) — tek
          // satırda kırpılır, puan sütunu hep aynı hizada kalır.
          Expanded(child: Text(entry.label, style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('$pointsPrefix${entry.points}', style: pointsStyle),
        ],
      ),
    );
  }
}
