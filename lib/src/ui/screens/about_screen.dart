import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tve_app.dart';
import '../tve_scope.dart';
import '../widgets/cards.dart';

/// À propos : texte HTML de l'API, contacts, réseaux sociaux, politique de confidentialité.
class TveAboutScreen extends StatelessWidget {
  const TveAboutScreen({super.key});

  static const _socialIcons = {
    'facebook': Icons.facebook_rounded,
    'twitter': Icons.alternate_email_rounded,
    'instagram': Icons.camera_alt_rounded,
    'youtube': Icons.smart_display_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    final s = tve.strings;
    final b = tve.group.branding;
    void open(String url) =>
        launchUrl(Uri.parse(url.startsWith('http') ? url : 'https://$url'), mode: LaunchMode.externalApplication);

    return ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom), children: [
      const Center(child: TveLogo(height: 80)),
      const SizedBox(height: 16),
      if (tve.group.aboutHtml != null) TveHtml(tve.group.aboutHtml!),
      const Divider(height: 32),
      Text(s.contact, style: Theme.of(context).textTheme.titleMedium),
      if (b.website != null)
        ListTile(leading: const Icon(Icons.language_rounded), title: Text(b.website!), onTap: () => open(b.website!)),
      if (b.email != null)
        ListTile(
          leading: const Icon(Icons.email_outlined),
          title: Text(b.email!),
          onTap: () => launchUrl(Uri(scheme: 'mailto', path: b.email)),
        ),
      if (b.phone != null)
        ListTile(
          leading: const Icon(Icons.phone_outlined),
          title: Text(b.phone!),
          onTap: () => launchUrl(Uri(scheme: 'tel', path: b.phone)),
        ),
      if (tve.group.social.all.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(s.followUs, style: Theme.of(context).textTheme.titleMedium),
        Wrap(spacing: 8, children: [
          for (final e in tve.group.social.all.entries)
            IconButton.filledTonal(
              tooltip: e.key,
              icon: Icon(_socialIcons[e.key] ?? Icons.link_rounded),
              onPressed: () => open(e.value),
            ),
        ]),
      ],
      const Divider(height: 32),
      ListTile(
        leading: const Icon(Icons.share_rounded),
        title: Text(s.share),
        onTap: () => SharePlus.instance.share(ShareParams(text: tve.shareText(tve.appName))),
      ),
      if (tve.group.privacyPolicyHtml != null)
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(s.privacyPolicy),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(s.privacyPolicy)),
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16), child: TveHtml(tve.group.privacyPolicyHtml!)),
            ),
          )),
        ),
      const SizedBox(height: 16),
      Text(
        [
          if (b.version != null) '${s.version} ${b.version}',
          if (b.developedBy != null) '${s.developedBy} ${b.developedBy}',
        ].join(' · '),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ]);
  }
}
