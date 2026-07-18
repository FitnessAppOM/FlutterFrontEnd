import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_expert_client_dashboard_ui.dart';
import 'taqa_expert_dashboard_ui.dart';
import 'taqa_filled_button.dart';
import 'taqa_training_plan_ui.dart';

class TaqaTemplateAssignClient {
  const TaqaTemplateAssignClient({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.status,
    this.currentlyAssigned = false,
  });

  final int id;
  final String name;
  final String? avatarUrl;
  final String? status;
  final bool currentlyAssigned;
}

class TaqaTemplateAssignment {
  const TaqaTemplateAssignment({required this.clientIds});

  final List<int> clientIds;
}

class TaqaTemplatePreviewExercise {
  const TaqaTemplatePreviewExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.rir,
    required this.weight,
  });

  final String name;
  final String sets;
  final String reps;
  final String rir;
  final String weight;
}

class TaqaTemplatePreviewDay {
  const TaqaTemplatePreviewDay({
    required this.number,
    required this.label,
    required this.exercises,
  });

  final int number;
  final String label;
  final List<TaqaTemplatePreviewExercise> exercises;
}

Future<TaqaTemplateAssignment?> showTaqaTemplateAssignSheet({
  required BuildContext context,
  required String templateTitle,
  required List<TaqaTemplateAssignClient> clients,
}) {
  return showModalBottomSheet<TaqaTemplateAssignment>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => _TaqaTemplateAssignSheet(
      templateTitle: templateTitle,
      clients: clients,
    ),
  );
}

Future<void> showTaqaTemplatePreviewSheet({
  required BuildContext context,
  required String title,
  required List<TaqaTemplatePreviewDay> days,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => _TaqaTemplatePreviewSheet(title: title, days: days),
  );
}

Future<void> showTaqaTemplateAssignedClientsSheet({
  required BuildContext context,
  required String templateTitle,
  required List<TaqaTemplateAssignClient> clients,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => _TaqaTemplateAssignedClientsSheet(
      templateTitle: templateTitle,
      clients: clients,
    ),
  );
}

class _TaqaSheetHeader extends StatelessWidget {
  const _TaqaSheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: TaqaUiScale.w(36),
          height: TaqaUiScale.h(3),
          decoration: BoxDecoration(
            color: TaqaUiColors.charcoal.withValues(alpha: 0.25),
            borderRadius: TaqaUiScale.radius(2),
          ),
        ),
        SizedBox(height: TaqaUiScale.h(9)),
        SizedBox(
          height: TaqaUiScale.h(25),
          child: Center(child: TaqaClientDashboardTitleText(title)),
        ),
      ],
    );
  }
}

class _TaqaTemplateAssignSheet extends StatefulWidget {
  const _TaqaTemplateAssignSheet({
    required this.templateTitle,
    required this.clients,
  });

  final String templateTitle;
  final List<TaqaTemplateAssignClient> clients;

  @override
  State<_TaqaTemplateAssignSheet> createState() =>
      _TaqaTemplateAssignSheetState();
}

class _TaqaTemplateAssignSheetState extends State<_TaqaTemplateAssignSheet> {
  final Set<int> _selectedClientIds = <int>{};

  void _toggleClient(TaqaTemplateAssignClient client) {
    if (client.currentlyAssigned) return;
    setState(() {
      if (!_selectedClientIds.add(client.id)) {
        _selectedClientIds.remove(client.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: 0.76,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          TaqaUiScale.w(16),
          TaqaUiScale.h(10),
          TaqaUiScale.w(17),
          TaqaUiScale.h(16) + bottomInset,
        ),
        decoration: BoxDecoration(
          color: TaqaUiColors.lightGray,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TaqaUiScale.r(15)),
          ),
        ),
        child: Column(
          children: [
            _TaqaSheetHeader(
              title:
                  'Assign ${widget.templateTitle.trim().isEmpty ? 'Template' : widget.templateTitle}',
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            Expanded(
              child: ListView.separated(
                itemCount: widget.clients.length,
                separatorBuilder: (_, _) => SizedBox(height: TaqaUiScale.h(10)),
                itemBuilder: (context, index) {
                  final client = widget.clients[index];
                  final selected = _selectedClientIds.contains(client.id);
                  final card = Container(
                    padding: EdgeInsets.all(TaqaUiScale.w(selected ? 1 : 0)),
                    decoration: BoxDecoration(
                      color: selected ? TaqaUiColors.lime : Colors.transparent,
                      borderRadius: TaqaUiScale.radius(15),
                    ),
                    child: TaqaExpertClientCard(
                      name: client.name,
                      avatarUrl: client.avatarUrl,
                      status: client.status,
                      showStatus: (client.status ?? '').trim().isNotEmpty,
                      subtitle: 'User ID: ${client.id}',
                      alerts: const [],
                      footer: client.currentlyAssigned
                          ? Text(
                              'CURRENT TEMPLATE',
                              style: TextStyle(
                                color: TaqaUiColors.charcoal,
                                fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                                fontSize: TaqaUiScale.sp(8),
                                height: 10 / 8,
                              ),
                            )
                          : null,
                      onTap: client.currentlyAssigned
                          ? null
                          : () => _toggleClient(client),
                    ),
                  );
                  return client.currentlyAssigned
                      ? Opacity(opacity: 0.55, child: card)
                      : card;
                },
              ),
            ),
            SizedBox(height: TaqaUiScale.h(10)),
            TaqaFilledButton(
              label: _selectedClientIds.isEmpty
                  ? 'Assign'
                  : 'Assign (${_selectedClientIds.length})',
              onTap: _selectedClientIds.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      TaqaTemplateAssignment(
                        clientIds: _selectedClientIds.toList(growable: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaqaTemplateAssignedClientsSheet extends StatelessWidget {
  const _TaqaTemplateAssignedClientsSheet({
    required this.templateTitle,
    required this.clients,
  });

  final String templateTitle;
  final List<TaqaTemplateAssignClient> clients;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final title = templateTitle.trim();
    return FractionallySizedBox(
      heightFactor: 0.76,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          TaqaUiScale.w(16),
          TaqaUiScale.h(10),
          TaqaUiScale.w(17),
          TaqaUiScale.h(16) + bottomInset,
        ),
        decoration: BoxDecoration(
          color: TaqaUiColors.lightGray,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TaqaUiScale.r(15)),
          ),
        ),
        child: Column(
          children: [
            _TaqaSheetHeader(
              title: title.isEmpty ? 'Assigned clients' : 'Assigned • $title',
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            Expanded(
              child: ListView.separated(
                itemCount: clients.length,
                separatorBuilder: (_, _) => SizedBox(height: TaqaUiScale.h(10)),
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return TaqaExpertClientCard(
                    name: client.name,
                    avatarUrl: client.avatarUrl,
                    status: client.status,
                    showStatus: (client.status ?? '').trim().isNotEmpty,
                    subtitle: 'User ID: ${client.id}',
                    alerts: const [],
                    footer: Text(
                      'CURRENT TEMPLATE',
                      style: TextStyle(
                        color: TaqaUiColors.charcoal,
                        fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                        fontSize: TaqaUiScale.sp(8),
                        height: 10 / 8,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaqaTemplatePreviewSheet extends StatelessWidget {
  const _TaqaTemplatePreviewSheet({required this.title, required this.days});

  final String title;
  final List<TaqaTemplatePreviewDay> days;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: 0.76,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          TaqaUiScale.w(16),
          TaqaUiScale.h(10),
          TaqaUiScale.w(17),
          TaqaUiScale.h(16) + bottomInset,
        ),
        decoration: BoxDecoration(
          color: TaqaUiColors.lightGray,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TaqaUiScale.r(15)),
          ),
        ),
        child: Column(
          children: [
            _TaqaSheetHeader(
              title: title.trim().isEmpty ? 'Template preview' : title,
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            Expanded(
              child: days.isEmpty
                  ? const Center(
                      child: TaqaClientDashboardBodyText(
                        'No day details available for this template.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: TaqaUiScale.h(24)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TaqaClientDashboardTitleText('Day ${day.number}'),
                              SizedBox(height: TaqaUiScale.h(4)),
                              TaqaClientDashboardBodyText(day.label),
                              SizedBox(height: TaqaUiScale.h(15)),
                              if (day.exercises.isEmpty)
                                const TaqaClientDashboardCard(
                                  child: TaqaClientDashboardBodyText(
                                    'No exercises',
                                  ),
                                )
                              else
                                ...day.exercises.map(
                                  (exercise) => TaqaTrainingExerciseCard(
                                    exerciseName: exercise.name,
                                    onExerciseTap: null,
                                    metricFields: [
                                      TaqaTrainingMetricValue(
                                        label: 'Sets',
                                        value: exercise.sets,
                                      ),
                                      TaqaTrainingMetricValue(
                                        label: 'Weight',
                                        value: exercise.weight,
                                      ),
                                      TaqaTrainingMetricValue(
                                        label: 'Reps',
                                        value: exercise.reps,
                                      ),
                                      TaqaTrainingMetricValue(
                                        label: 'RIR',
                                        value: exercise.rir,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
