import 'dart:async';

class PlanUpdateException implements Exception {
  const PlanUpdateException(this.message, {this.retryable = true});
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

/// Keeps a saved profile separate from its generation attempt. A lost save
/// response can be replayed with the same request key; a saved response is
/// never submitted again. Server jobs allow recovery after an app restart.
class PlanUpdateCoordinator {
  PlanUpdateCoordinator({
    required this.saveProfile,
    required this.readJob,
    required this.retryJob,
    required this.fetchProgram,
    this.jobId,
    this.pollInterval = const Duration(seconds: 3),
    this.pollTimeout = const Duration(seconds: 90),
  });

  final Future<Map<String, dynamic>> Function() saveProfile;
  final Future<Map<String, dynamic>> Function(int) readJob;
  final Future<void> Function(int) retryJob;
  final Future<Map<String, dynamic>> Function() fetchProgram;
  final Duration pollInterval;
  final Duration pollTimeout;
  int? jobId;
  Map<String, dynamic>? savedProfile;

  static Map<String, dynamic> _job(Map<String, dynamic> response) {
    final value = response['generation'];
    return value is Map ? Map<String, dynamic>.from(value) : response;
  }

  Future<void> run() async {
    if (jobId == null) {
      savedProfile ??= await saveProfile();
      final request = savedProfile!['training_generation'];
      if (request is Map) {
        jobId = int.tryParse('${request['job_id']}');
      }
      if (jobId == null) {
        throw const PlanUpdateException(
          'Could not confirm your training update. Reopen the training page to check its status.',
          retryable: false,
        );
      }
    }

    var job = _job(await readJob(jobId!));
    if (job['status'] == 'failed' && job['retryable'] == true) {
      await retryJob(jobId!);
      job = _job(await readJob(jobId!));
    }
    final deadline = DateTime.now().add(pollTimeout);
    while (true) {
      if (int.tryParse('${job['job_id']}') != jobId) {
        throw const PlanUpdateException(
          'Could not confirm this training update.',
          retryable: false,
        );
      }
      final status = job['status'];
      if (status == 'succeeded') {
        final program = await fetchProgram();
        if ('${program['program_id']}' != '${job['program_id']}') {
          throw const PlanUpdateException(
            'Your plan changed after this update. Your newer plan has been kept.',
            retryable: false,
          );
        }
        return;
      }
      if (status == 'failed' || status == 'superseded') {
        final canRetry = status == 'failed' && job['retryable'] == true;
        throw PlanUpdateException(
          canRetry
              ? 'Your profile was saved, but your training plan could not be updated. Please retry.'
              : 'Your plan needs review before another update. Your existing plan has been kept.',
          retryable: canRetry,
        );
      }
      if (status != 'queued' && status != 'running') {
        throw const PlanUpdateException(
          'Training update not found.',
          retryable: false,
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'The training update is still pending. Please check again.',
        );
      }
      await Future<void>.delayed(pollInterval);
      job = _job(await readJob(jobId!));
    }
  }
}
