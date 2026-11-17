import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;
  const LegalScreen({super.key, required this.title, required this.sections});

  static LegalScreen get privacy => AppLocale.isArabic ? _privacyAr : LegalScreen(title: tr("Privacy policy"), sections: const [
    ("What we collect", "Your name, contact details, profile photo, posts, messages, voice notes and the location attached to activities you submit for verification. If you allow it, daily steps and cycling distance from Health Connect or Apple Health, and the utility bills you scan."),
    ("Why we use it", "To run your account, verify environmental actions, award Eco Points, connect you with friends and teams, and keep the community safe. We never use your data for advertising."),
    ("Location", "Location is only read when you submit evidence, check in, scan a recycling station, report an issue or open the Eco Map. It is used to check you were at the activity site."),
    ("Health data", "Steps and cycling data are only used to award Eco Points. They are never sold, never shared and never used for ads. You can turn Health sync off at any time."),
    ("Calls", "Voice and video calls go directly between phones and are never recorded."),
    ("Sharing", "We never sell your data. Organisations you join see your verified impact in their team dashboard. Verifiers see the evidence you submit."),
    ("Your choices", "You can edit your profile, switch notifications off and delete your account at any time from Settings. Deleting removes your personal data; only anonymous impact totals remain."),
    ("Full policy", "Read the full policy at greenifyx-admin.netlify.app/privacy.html"),
    ("Contact", "Questions about your data: ramjankhan8824@gmail.com"),
  ]);

  static LegalScreen get terms => AppLocale.isArabic ? _termsAr : LegalScreen(title: tr("Terms of use"), sections: const [
    ("Be genuine", "Only submit evidence of actions you really took part in. Faked photos or locations lead to points being reversed and the account being suspended."),
    ("Be kind", "No harassment, hate speech or spam. Reported content is reviewed by moderators and may be removed."),
    ("Eco Points", "Points have no cash value. They can be redeemed for rewards while stocks last, and may be reversed if a verification is overturned."),
    ("Safety", "Follow the organiser's safety guidance at events. Do not enter restricted or protected areas to collect evidence."),
    ("Changes", "We may update these terms. Continuing to use GreenifyX means you accept the latest version."),
  ]);

  static const _privacyAr = LegalScreen(title: "سياسة الخصوصية", sections: [
    ("ما الذي نجمعه", "اسمك وبيانات التواصل وصورة ملفك ومنشوراتك ورسائلك ورسائلك الصوتية والموقع المرفق بالأنشطة التي ترسلها للتحقق. وإذا سمحت بذلك: خطوات المشي ومسافة ركوب الدراجة من Health Connect أو Apple Health، وفواتير الخدمات التي تصورها."),
    ("لماذا نستخدمه", "لتشغيل حسابك، والتحقق من الأعمال البيئية، ومنح النقاط، وربطك بالأصدقاء والفرق، والحفاظ على أمان المجتمع. لا نستخدم بياناتك للإعلانات أبداً."),
    ("الموقع", "لا نقرأ موقعك إلا عند إرسال دليل أو تسجيل الحضور أو مسح محطة إعادة التدوير أو إرسال بلاغ أو فتح الخريطة البيئية، للتأكد من وجودك في موقع النشاط."),
    ("بيانات الصحة", "تُستخدم الخطوات وبيانات ركوب الدراجة لمنح النقاط فقط. لا نبيعها ولا نشاركها ولا نستخدمها للإعلانات، ويمكنك إيقاف المزامنة في أي وقت."),
    ("المكالمات", "المكالمات الصوتية والمرئية تتم مباشرة بين الهواتف ولا تُسجَّل أبداً."),
    ("المشاركة", "لا نبيع بياناتك أبداً. تطّلع الجهات التي تنضم إليها على أثرك المُتحقق منه، ويطّلع المُدققون على الأدلة التي ترسلها."),
    ("خياراتك", "يمكنك تعديل ملفك وإيقاف الإشعارات وحذف حسابك في أي وقت من الإعدادات. الحذف يزيل بياناتك الشخصية، وتبقى فقط إجماليات الأثر بشكل مجهول."),
    ("السياسة الكاملة", "اقرأ السياسة الكاملة على greenifyx-admin.netlify.app/privacy.html"),
    ("التواصل", "لأي استفسار عن بياناتك: ramjankhan8824@gmail.com"),
  ]);

  static const _termsAr = LegalScreen(title: "شروط الاستخدام", sections: [
    ("كن صادقاً", "أرسل فقط أدلة على أعمال شاركت فيها فعلاً. الصور أو المواقع المزيفة تؤدي إلى سحب النقاط وإيقاف الحساب."),
    ("كن لطيفاً", "يُمنع التحرش وخطاب الكراهية والرسائل المزعجة. يراجع المشرفون المحتوى المُبلغ عنه وقد يحذفونه."),
    ("النقاط البيئية", "ليس للنقاط قيمة نقدية. يمكن استبدالها بالمكافآت حسب التوفر، وقد تُسحب إذا أُلغي التحقق."),
    ("السلامة", "اتبع إرشادات السلامة من المنظم في الفعاليات. لا تدخل مناطق محظورة أو محمية لجمع الأدلة."),
    ("التغييرات", "قد نحدّث هذه الشروط. استمرارك في استخدام GreenifyX يعني موافقتك على أحدث نسخة."),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final s in sections) ...[
            const SizedBox(height: 18),
            Text(s.$1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(s.$2, style: TextStyle(fontSize: 14.5, height: 1.5, color: AppColors.subtitle)),
          ],
        ],
      ),
    );
  }
}
