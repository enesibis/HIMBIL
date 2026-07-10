import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/circle_back_button.dart';

/// Gizlilik politikası — store zorunluluğu (madde #53). Uygulama içi metin
/// olarak tutulur (henüz barındırılan bir web sayfası yok); mevcut veri
/// modelini yansıtır: bugün itibarıyla her şey cihazda `shared_preferences`
/// ile saklanıyor, sunucuya hiçbir kişisel veri gitmiyor. Aşama 3+ (gerçek
/// çok oyunculu) ve Aşama 7 (misafir hesap/envanter) devreye girdiğinde bu
/// metnin güncellenmesi gerekir — bkz. docs/yapılması-gerekenler.md #60.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CarnivalBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                CircleBackButton(onTap: () => Navigator.of(context).pop()),
                const SizedBox(height: 14),
                Text(context.l10n.settingsPrivacyPolicy, style: AppText.baloo(size: 21, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Son güncelleme: bu taslak, uygulamanın şu anki (ağsız/bot) sürümünü yansıtır.',
                  style: AppText.nunito(size: 12, weight: FontWeight.w700, color: Palette.textSecondary),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(_policyText, style: AppText.nunito(size: 13, weight: FontWeight.w600, color: Palette.textPrimary).copyWith(height: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _policyText = '''
Topladığımız veriler

Hımbıl şu an tamamen cihazınızda çalışır: isim, yaş, avatar seçimi, jeton bakiyesi, sahip olduğun kart sırtları/çerçeveler ve maç istatistiklerin (oyun/galibiyet sayısı, en iyi seri) yalnızca cihazının yerel depolamasında (shared_preferences) tutulur. Bu veriler bizim veya üçüncü bir tarafın sunucusuna gönderilmez.

Çevrimiçi çok oyunculu (yakında)

Gerçek zamanlı çok oyunculu özelliği etkinleştiğinde, oda kurma/katılma ve tur sonuçlarını işlemek için isim ve maç verilerin sunucumuza iletilecek. Rakiplerinin kartları hiçbir zaman senin cihazına, senin kartların da hiçbir zaman rakiplerinin cihazına gönderilmez — sunucu yalnızca sana ait olanı sana gösterir.

Misafir hesap ve kalıcı envanter (yakında)

İleride jeton/envanter bilgisi cihazdan sunucuya taşındığında, bu veriler bir misafir hesap kimliğiyle ilişkilendirilecek; bu kimlik reklam takibi veya üçüncü taraf paylaşımı için kullanılmaz.

Üçüncü taraf servisler

Uygulama çökme raporlarını (Sentry) ve temel kullanım analitiğini (tur süresi, hatalı slam oranı gibi toplu istatistikler) barındırmak için üçüncü taraf servisler kullanabiliriz; bunlar kişisel kimlik bilgisi değil, teknik/oyun-içi olay verisidir.

13 yaş altı kullanıcılar

Onboarding sırasında istenen yaş bilgisi bugün itibarıyla eşleştirme veya başka bir amaç için kullanılmıyor; yalnızca profilinde gösterilir. 13 yaş altı kullanıcılardan veri toplama politikamız (KVKK/COPPA uyumu) çevrimiçi özellikler etkinleşmeden önce netleştirilecektir.

İletişim

Bu metin hakkında sorular için uygulama mağazası listelemesindeki geliştirici iletişim bilgilerini kullanabilirsin.
''';
}
