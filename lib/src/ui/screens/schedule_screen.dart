import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../tve_scope.dart';
import '../widgets/cards.dart';
import '../widgets/states.dart';
import '../widgets/tve_image.dart';

/// Grille des programmes : sélection du jour (hier → J+7).
class TveScheduleScreen extends StatefulWidget {
  const TveScheduleScreen({super.key});

  @override
  State<TveScheduleScreen> createState() => _TveScheduleScreenState();
}

class _TveScheduleScreenState extends State<TveScheduleScreen> {
  static const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final tve = TveScope.of(context);
    final today = DateTime.now();
    final day = today.add(Duration(days: _offset));
    return Column(children: [
      SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            for (var o = -1; o <= 7; o++) ...[
              ChoiceChip(
                selected: o == _offset,
                onSelected: (_) => setState(() => _offset = o),
                label: Text(o == 0
                    ? tve.strings.today
                    : '${_days[today.add(Duration(days: o)).weekday - 1]} ${today.add(Duration(days: o)).day}'),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      Expanded(
        child: TveFuture<List<TveScheduleSlot>>(
          key: ValueKey(_offset),
          load: () => tve.api.listSchedule(date: day, channel: tve.channelFilter),
          builder: (context, slots, reload) {
            if (slots.isEmpty) return const TveEmptyView(icon: Icons.calendar_month_outlined);
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView.builder(
                itemCount: slots.length,
                itemBuilder: (context, i) {
                  final s = slots[i];
                  return ListTile(
                    selected: s.airing,
                    leading: TveImage(s.showLogo ?? s.showPoster, width: 56, height: 56, radius: 8),
                    title: Text(s.showTitle),
                    subtitle: Text(
                      '${formatTime(s.startsAt)} – ${formatTime(s.endsAt)}'
                      '${s.channel == null ? '' : ' · ${s.channel!.label}'}',
                    ),
                    trailing: s.airing ? const TveLiveBadge() : null,
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}
