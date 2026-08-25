import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/media/photo_capture_service.dart';
import '../../core/utils/visit_assessment_scoring.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../shared/widgets/common.dart';
import '../../l10n/app_localizations.dart';

/// The field scorecard: one section per page, scored as the agent taps.
///
/// Section-per-page rather than one long scroll because these are answered
/// while walking around a meeting with the officials, on a small screen, in
/// sunlight. Losing your place in a 46-question list is a real failure mode.
///
/// The running score shown here is **provisional**. The server re-scores on
/// sync and its figure is the one that is stored; the point of computing it
/// locally is that the agent can tell the group how they did before leaving,
/// which is when the conversation is useful.
class VisitAssessmentScreen extends StatefulWidget {
  const VisitAssessmentScreen({
    super.key,
    required this.visitId,
    required this.groupName,
    this.repository,
    this.attachments,
    this.camera,
  });

  final String visitId;
  final String groupName;

  /// Injected in tests; built from the shared database otherwise.
  final AssessmentRepository? repository;
  final AttachmentRepository? attachments;
  final PhotoCaptureService? camera;

  @override
  State<VisitAssessmentScreen> createState() => _VisitAssessmentScreenState();
}

class _VisitAssessmentScreenState extends State<VisitAssessmentScreen> {
  late final AssessmentRepository _repository =
      widget.repository ?? AssessmentRepository();
  late final AttachmentRepository _attachments =
      widget.attachments ?? AttachmentRepository();
  late final PhotoCaptureService _camera = widget.camera ?? PhotoCaptureService();
  final _pageController = PageController();

  /// Photos already taken, by question key, so a tile can show its own.
  Map<String, List<LocalAttachment>> _photos = {};

  CachedSnapshot? _cached;
  Map<String, String> _choices = {};
  AssessmentScore? _score;
  bool _loading = true;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cached = await _repository.currentSnapshot();
      if (cached == null) {
        setState(() {
        final l10n = L10n.of(context);
          _loading = false;
          _error = l10n.visitAssessmentNoAssessmentFormHasBeenDownloaded;
        });
        return;
      }

      await _repository.beginAssessment(visitId: widget.visitId, snapshot: cached);
      final choices = await _repository.choicesFor(widget.visitId);
      final score = await _repository.rescore(widget.visitId);
      final photos = await _loadPhotos();

      if (!mounted) return;
      setState(() {
        _cached = cached;
        _choices = choices;
        _score = score;
        _photos = photos;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not open the assessment: $error';
      });
    }
  }

  Future<void> _answer(
    AssessmentSectionSnapshot section,
    AssessmentQuestionSnapshot question,
    AssessmentChoice choice,
  ) async {
    // Tapping the selected answer again clears it. Unanswered and "No" are
    // different facts and an agent must be able to get back to unanswered.
    final isSame = _choices[question.key] == choice.key;

    if (isSame) {
      await _repository.clearAnswer(visitId: widget.visitId, questionKey: question.key);
    } else {
      await _repository.answer(
        visitId: widget.visitId,
        sectionKey: section.key,
        questionKey: question.key,
        choice: choice.key,
      );
    }

    final choices = await _repository.choicesFor(widget.visitId);
    final score = await _repository.rescore(widget.visitId);
    if (!mounted) return;
    setState(() {
      _choices = choices;
      _score = score;
    });
  }

  Future<Map<String, List<LocalAttachment>>> _loadPhotos() async {
    final all = await _attachments.forVisit(widget.visitId);
    final byQuestion = <String, List<LocalAttachment>>{};
    for (final photo in all) {
      final key = photo.questionKey;
      if (key == null) continue;
      byQuestion.putIfAbsent(key, () => []).add(photo);
    }
    return byQuestion;
  }

  /// Opens the camera for one question and queues what comes back.
  ///
  /// Capture is offered ONLY from a question, never as a general 'add photo'
  /// button. A picture with no claim attached to it is not evidence of
  /// anything, and the server refuses one anyway.
  Future<void> _capture(
    AssessmentSectionSnapshot section,
    AssessmentQuestionSnapshot question,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    final photo = await _camera.capture();
    // Null covers a cancelled capture and a refused camera permission alike.
    // Both are ordinary things for a person to do, not error states.
    if (photo == null) return;

    final saved = await _attachments.enqueue(
      visitId: widget.visitId,
      sectionKey: section.key,
      questionKey: question.key,
      localPath: photo.path,
      fileName: photo.fileName,
      mimeType: photo.mimeType,
      sizeBytes: photo.sizeBytes,
      capturedAt: photo.capturedAt,
    );

    if (!mounted) return;
    if (saved == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.visitAssessmentPhotoCapReached(
                AttachmentRepository.maxPerVisit),
          ),
        ),
      );
      return;
    }

    final photos = await _loadPhotos();
    if (!mounted) return;
    setState(() => _photos = photos);
  }

  Future<void> _discardPhoto(LocalAttachment photo) async {
    await _attachments.discard(photo.id);
    final photos = await _loadPhotos();
    if (!mounted) return;
    setState(() => _photos = photos);
  }

  /// This section's subtotal, or an empty one before the first score exists.
  AssessmentSectionResult _resultFor(AssessmentSectionSnapshot section, int index) {
    for (final result in _score?.sections ?? const <AssessmentSectionResult>[]) {
      if (result.sectionKey == section.key) return result;
    }
    return AssessmentSectionResult(
      sectionKey: section.key,
      title: section.title,
      position: index,
      earnedPoints: 0,
      applicablePoints: 0,
      percentage: null,
      questions: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.visitAssessmentAssessment)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.visitAssessmentAssessment)),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.cloud_download_outlined,
            title: l10n.visitAssessmentFormNotAvailable,
            message: error,
          ),
        ),
      );
    }

    final sections = _cached!.snapshot.orderedSections;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.visitAssessmentAssessment),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: _ScoreHeader(score: _score, sectionCount: sections.length, page: _page),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _page = page),
        itemCount: sections.length,
        itemBuilder: (context, index) => _SectionPage(
          section: sections[index],
          choices: _choices,
          sectionResult: _resultFor(sections[index], index),
          photos: _photos,
          onAnswer: (question, choice) => _answer(sections[index], question, choice),
          onCapture: (question) => _capture(sections[index], question),
          onDiscardPhoto: _discardPhoto,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _page == 0
                      ? null
                      : () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          ),
                  child: Text(l10n.back),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _page >= sections.length - 1
                      // Nothing is submitted from here: the answers are already
                      // on disk, and the visit's own Finish step queues them.
                      ? () => Navigator.of(context).pop(true)
                      : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          ),
                  child: Text(_page >= sections.length - 1 ? 'Done' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.score,
    required this.sectionCount,
    required this.page,
  });

  final AssessmentScore? score;
  final int sectionCount;
  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = score;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Both children must be able to shrink. Two bare Texts in a Row size
          // to their natural width and overflow the moment the band label is
          // long or the phone is narrow — 320px handsets are the field device,
          // and a large accessibility text scale narrows it further still.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Section ${page + 1} of $sectionCount',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (current != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${_trim(current.earnedPoints)} / ${_trim(current.maxPoints)}'
                    '${current.bandLabel == null ? '' : '  ·  ${current.bandLabel}'}',
                    style: theme.textTheme.labelLarge,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current == null || current.maxPoints == 0
                  ? 0
                  : (current.earnedPoints / current.maxPoints).clamp(0.0, 1.0),
              minHeight: 6,
            ),
          ),
          if (current != null && !current.complete) ...[
            const SizedBox(height: 4),
            Text(
              '${current.unansweredKeys.length} still to answer',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionPage extends StatelessWidget {
  const _SectionPage({
    required this.section,
    required this.choices,
    required this.sectionResult,
    required this.photos,
    required this.onAnswer,
    required this.onCapture,
    required this.onDiscardPhoto,
  });

  final AssessmentSectionSnapshot section;
  final Map<String, String> choices;
  final AssessmentSectionResult sectionResult;
  final Map<String, List<LocalAttachment>> photos;
  final void Function(AssessmentQuestionSnapshot, AssessmentChoice) onAnswer;
  final void Function(AssessmentQuestionSnapshot) onCapture;
  final void Function(LocalAttachment) onDiscardPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(section.title, style: theme.textTheme.titleLarge),
        if (section.description != null) ...[
          const SizedBox(height: 4),
          Text(section.description!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 4),
        Text(
          '${_trim(sectionResult.earnedPoints)} of '
          '${_trim(sectionResult.applicablePoints)} points in this section',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final question in section.questions)
          _QuestionTile(
            question: question,
            selected: choices[question.key],
            photos: photos[question.key] ?? const [],
            onAnswer: (choice) => onAnswer(question, choice),
            onCapture: () => onCapture(question),
            onDiscardPhoto: onDiscardPhoto,
          ),
      ],
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.question,
    required this.selected,
    required this.photos,
    required this.onAnswer,
    required this.onCapture,
    required this.onDiscardPhoto,
  });

  final AssessmentQuestionSnapshot question;
  final String? selected;
  final List<LocalAttachment> photos;
  final ValueChanged<AssessmentChoice> onAnswer;
  final VoidCallback onCapture;
  final void Function(LocalAttachment) onDiscardPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.prompt, style: theme.textTheme.titleSmall),
            if (question.guidance != null) ...[
              const SizedBox(height: 4),
              Text(question.guidance!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            // Wrap, not Row: "Not applicable" is a long label and these are
            // read on 320px screens. A Row would overflow.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in AssessmentChoice.values)
                  ChoiceChip(
                    label: Text(choice.label),
                    selected: selected == choice.key,
                    onSelected: (_) => onAnswer(choice),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(photos.isEmpty ? 'Add photo' : 'Add another'),
                ),
                if (photos.isNotEmpty)
                  Text(
                    '${photos.length} attached',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            if (photos.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _PhotoThumb(
                    photo: photos[index],
                    onDiscard: () => onDiscardPhoto(photos[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One captured photo, with its sync state showing.
///
/// The state matters to an agent: a photo still on the phone is one they may
/// need to keep the handset around for, and one already sent is safe.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.onDiscard});

  final LocalAttachment photo;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final file = photo.localPath.isEmpty ? null : File(photo.localPath);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 72,
            height: 72,
            child: file != null && file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                // The file is gone once the photo is safely on the server, so
                // this is the ordinary end state, not a broken image.
                : const ColoredBox(
                    color: Color(0x22000000),
                    child: Icon(Icons.cloud_done_outlined, size: 20),
                  ),
          ),
        ),
        if (!photo.isSynced)
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              tooltip: l10n.groupSetupWizardRemove,
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDiscard,
            ),
          ),
      ],
    );
  }
}

/// Points are doubles but almost always whole. "2" reads better than "2.0",
/// and a half mark still has to show as 1.5.
String _trim(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
