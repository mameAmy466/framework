import 'package:flutter/material.dart';

import '../config/tve_config.dart';
import 'screens/about_screen.dart';
import 'screens/live_screen.dart';
import 'screens/news_screen.dart';
import 'screens/podcasts_screen.dart';
import 'screens/radio_screen.dart';
import 'screens/replay_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/search_screen.dart';
import 'screens/shorts_screen.dart';
import 'tve_app.dart';
import 'tve_scope.dart';

/// Écran par défaut d'une section (peut être remplacé via `TveDesign.screens`).
Widget defaultSectionScreen(TveSection s) => switch (s) {
      TveSection.live => const TveLiveScreen(),
      TveSection.radio => const TveRadioScreen(),
      TveSection.replay => const TveReplayScreen(),
      TveSection.shorts => const TveShortsScreen(),
      TveSection.news => const TveNewsScreen(),
      TveSection.schedule => const TveScheduleScreen(),
      TveSection.podcasts => const TvePodcastsScreen(),
      TveSection.about => const TveAboutScreen(),
    };

/// Coquille de l'app : AppBar (logo + recherche) et barre de navigation.
class TveHome extends StatefulWidget {
  const TveHome({super.key});

  @override
  State<TveHome> createState() => _TveHomeState();
}

class _TveHomeState extends State<TveHome> {
  int? _index;

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    final s = tve.strings;
    final sections = tve.sections;
    final custom = tve.config.customTabs;

    final tabs = <({String label, IconData icon, WidgetBuilder builder})>[
      for (final sec in sections)
        (
          label: _label(sec, tve),
          icon: tve.design.iconFor(sec),
          builder: tve.design.screens[sec] ?? (_) => defaultSectionScreen(sec),
        ),
      for (final c in custom) (label: c.label, icon: c.icon, builder: c.builder),
    ];

    if (_index == null) {
      final initial = tve.config.initialSection ?? sectionFromApi(tve.group.mobile.defaultSection);
      final i = initial == null ? -1 : sections.indexOf(initial);
      _index = i < 0 ? 0 : i;
    }
    final index = _index!.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: const TveLogo(),
        actions: [
          if (tve.group.has('search'))
            IconButton(
              tooltip: s.search,
              icon: const Icon(Icons.search_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TveSearchScreen())),
            ),
        ],
      ),
      // Un seul écran monté à la fois : le lecteur vidéo s'arrête quand on change
      // d'onglet ; la radio continue (lecteur audio global, voir TveAudioController).
      body: KeyedSubtree(key: ValueKey(index), child: Builder(builder: tabs[index].builder)),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelBehavior: tabs.length > 5
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.icon), label: t.label)],
            ),
    );
  }

  String _label(TveSection sec, TveScope tve) {
    final s = tve.strings;
    return switch (sec) {
      TveSection.live => s.live,
      TveSection.radio => s.radio,
      TveSection.replay => s.replay,
      TveSection.shorts => s.shorts,
      TveSection.news => s.news,
      TveSection.schedule => s.schedule,
      TveSection.podcasts => s.podcasts,
      TveSection.about => s.about,
    };
  }
}
