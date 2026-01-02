import 'package:flutter/material.dart';
import '../services/training_service.dart';
import '../core/account_storage.dart';
import '../widgets/app_toast.dart';
import '../main/main_layout.dart';
import '../localization/app_localizations.dart';

class GeneratingTrainingScreen extends StatefulWidget {
  const GeneratingTrainingScreen({super.key});

  @override
  State<GeneratingTrainingScreen> createState() =>
      _GeneratingTrainingScreenState();
}

class _GeneratingTrainingScreenState
    extends State<GeneratingTrainingScreen> {

  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _generateTraining();
  }

  Future<void> _generateTraining() async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        throw Exception("User not found");
      }

      await TrainingService.generateProgram(userId);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
            (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );

      _retryCount++;

      if (_retryCount < _maxRetries) {
        Future.delayed(
          Duration(seconds: 2 * _retryCount),
              () {
            if (mounted) _generateTraining();
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 24),
              Text(
                t.translate("generating_training"),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}