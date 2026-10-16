import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/walker_admin_model.dart';
import '../services/walker_admin_service.dart';
import '../utils/walker_admin_helpers.dart';
import '../widgets/kyc_document_viewer_dialog.dart';
import '../widgets/walker_activity_history_dialog.dart';
import '../widgets/walker_details_sections.dart';
import '../widgets/walker_security_dialog.dart';

const Color walkerOrange = Color(0xFFFF7900);
const Color walkerBackground = Color(0xFFFFFAF5);
const Color walkerText = Color(0xFF292524);
const Color walkerMuted = Color(0xFF78716C);
const Color walkerBorder = Color(0xFFE7E5E4);
const Color walkerGreen = Color(0xFF15803D);
const Color walkerRed = Color(0xFFB91C1C);
const Color walkerBlue = Color(0xFF1D4ED8);

class WalkerDetailsScreen extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> walkerData;

  const WalkerDetailsScreen({
    super.key,
    required this.uid,
    required this.walkerData,
  });

  @override
  State<WalkerDetailsScreen> createState() =>
      _WalkerDetailsScreenState();
}

class _WalkerDetailsScreenState extends State<WalkerDetailsScreen> {
  final WalkerAdminService _service = WalkerAdminService();

  bool _actionLoading = false;

  String _text(
    dynamic value, [
    String fallback = 'Not provided',
  ]) {
    return WalkerAdminHelpers.firstDisplayValue(
          {'value': value},
          ['value'],
        ) ??
        fallback;
  }

  void _message(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? walkerRed : walkerGreen,
        ),
      );
  }

  String _statusLabel(WalkerAdminModel walker) {
    final status =
        WalkerAdminHelpers.normalizeStatus(walker.status);

    final verification =
        WalkerAdminHelpers.normalizeStatus(
      walker.verificationStatus,
    );

    if (status == 'approved' &&
        walker.isApproved &&
        verification == 'verified') {
      return walker.isActive
          ? 'Verified • Active'
          : 'Verified • Inactive';
    }

    if (status == 'rejected' || verification == 'rejected') {
      return 'Rejected';
    }

    if (status == 'suspended') {
      return 'Suspended';
    }

    if (status == 'correction_required' ||
        verification == 'correction_required') {
      return 'Correction Required';
    }

    return walker.displayStatus;
  }

  Color _statusColor(String status) {
    if (status.contains('Active') || status == 'Verified') {
      return walkerGreen;
    }

    if (status == 'Rejected' || status == 'Suspended') {
      return walkerRed;
    }

    if (status == 'Correction Required') {
      return const Color(0xFFB45309);
    }

    return walkerBlue;
  }

  bool _isSubmitted(WalkerAdminModel walker) {
    final status =
        WalkerAdminHelpers.normalizeStatus(walker.status);

    return walker.applicationSubmitted ||
        status == 'under_review' ||
        status == 'approved' ||
        status == 'rejected' ||
        status == 'correction_required' ||
        status == 'suspended';
  }

  bool _canApprove(WalkerAdminModel walker) {
    final status =
        WalkerAdminHelpers.normalizeStatus(walker.status);
    final verification =
        WalkerAdminHelpers.normalizeStatus(
      walker.verificationStatus,
    );

    return _isSubmitted(walker) &&
        !walker.isVerified &&
        !walker.isApproved &&
        status != 'approved' &&
        status != 'rejected' &&
        status != 'suspended' &&
        status != 'inactive' &&
        status != 'left' &&
        status != 'correction_required' &&
        verification != 'verified' &&
        verification != 'rejected';
  }

  bool _canSuspend(WalkerAdminModel walker) {
    return walker.isApproved &&
        walker.isVerified &&
        walker.isActive &&
        WalkerAdminHelpers.normalizeStatus(walker.status) ==
            'approved';
  }

  bool _canReactivate(WalkerAdminModel walker) {
    return WalkerAdminHelpers.normalizeStatus(walker.status) ==
            'suspended' &&
        walker.isApproved &&
        walker.isVerified;
  }

  bool _canRequestCorrection(WalkerAdminModel walker) {
    return _canApprove(walker);
  }

  Future<String?> _askReason({
    required String title,
    required String description,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Enter the reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: walkerOrange,
                ),
                onPressed: () {
                  final reason = controller.text.trim();

                  if (reason.length < 3) {
                    ScaffoldMessenger.of(dialogContext)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter a reason of at least 3 characters.',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, reason);
                },
                child: Text(actionLabel),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: walkerOrange,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  String _actionTitle(String action) {
    switch (action) {
      case 'approve':
        return 'Verify & Approve';
      case 'reject':
        return 'Reject Application';
      case 'suspend':
        return 'Suspend Walker';
      case 'reactivate':
        return 'Reactivate Walker';
      case 'correction':
        return 'Request Correction';
      default:
        return 'Update Walker';
    }
  }

  String _actionMessage(String action) {
    switch (action) {
      case 'approve':
        return 'Approve this walker and activate the account?';
      case 'reject':
        return 'Reject this application? The account will remain inactive.';
      case 'suspend':
        return 'Suspend this active walker account?';
      case 'reactivate':
        return 'Reactivate this previously approved walker?';
      case 'correction':
        return 'Mark this application as requiring correction?';
      default:
        return 'Continue with this action?';
    }
  }

  WalkerAdminAction? _serviceAction(String action) {
    switch (action) {
      case 'approve':
        return WalkerAdminAction.approve;
      case 'reject':
        return WalkerAdminAction.reject;
      case 'suspend':
        return WalkerAdminAction.suspend;
      case 'reactivate':
        return WalkerAdminAction.reactivate;
      case 'correction':
        return WalkerAdminAction.requestCorrection;
      default:
        return null;
    }
  }

  Future<void> _runAdminAction({
    required String action,
    String? reason,
  }) async {
    if (_actionLoading) return;

    final serviceAction = _serviceAction(action);

    if (serviceAction == null) {
      _message('Unknown action.', error: true);
      return;
    }

    final cleanReason = reason?.trim();

    if (['reject', 'suspend', 'correction'].contains(action) &&
        (cleanReason == null || cleanReason.length < 3)) {
      _message(
        'Please enter a valid reason before continuing.',
        error: true,
      );
      return;
    }

    final confirmed = await _confirm(
      title: _actionTitle(action),
      message: _actionMessage(action),
      confirmLabel: action == 'approve'
          ? 'Approve'
          : action == 'correction'
              ? 'Request Correction'
              : action == 'reactivate'
                  ? 'Reactivate'
                  : action == 'suspend'
                      ? 'Suspend'
                      : 'Reject',
    );

    if (!confirmed || !mounted) return;

    setState(() => _actionLoading = true);

    try {
      await _service.runAdminAction(
        walkerId: widget.uid,
        action: serviceAction,
        reason: cleanReason,
      );

      _message('${_actionTitle(action)} successful.');
    } on WalkerAdminServiceException catch (e) {
      _message(e.message, error: true);
    } on FirebaseException catch (e) {
      _message(
        e.code == 'permission-denied'
            ? 'Permission denied. Check Admin authentication and Firestore Rules.'
            : 'Could not update walker. Please try again.',
        error: true,
      );
    } catch (_) {
      _message(
        'Action failed. Refresh the details and try again.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _startReasonAction({
    required String action,
  }) async {
    late String title;
    late String description;

    switch (action) {
      case 'reject':
        title = 'Reject Application';
        description =
            'Enter the reason for rejecting this application.';
        break;
      case 'suspend':
        title = 'Suspend Walker';
        description =
            'Explain why this walker is being suspended.';
        break;
      default:
        title = 'Request Correction';
        description =
            'Explain what information needs to be corrected.';
    }

    final reason = await _askReason(
      title: title,
      description: description,
      actionLabel: 'Continue',
    );

    if (reason == null || !mounted) return;

    await _runAdminAction(
      action: action,
      reason: reason,
    );
  }

  Future<void> _openDocument({
    required String title,
    required dynamic document,
  }) async {
    if (_actionLoading) return;

    if (!WalkerAdminHelpers.hasDocumentReference(document)) {
      _message('$title is not available.', error: true);
      return;
    }

    try {
      await showKycDocumentViewerDialog(
        context: context,
        title: title,
        document: document,
      );
    } catch (_) {
      if (!mounted) return;

      _message(
        'Could not open $title. Check the document reference and Storage permissions.',
        error: true,
      );
    }
  }

  Future<void> _openActivityHistory() async {
    if (_actionLoading) return;

    await showWalkerActivityHistoryDialog(
      context: context,
      walkerId: widget.uid,
      service: _service,
    );
  }

  void _showSecurityDetails(Map<String, dynamic> data) {
    showWalkerSecurityDialog(
      context: context,
      walkerId: widget.uid,
      walkerData: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: walkerBackground,
      body: SafeArea(
        child: StreamBuilder<WalkerAdminModel?>(
          stream: _service.watchWalker(widget.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _errorView(
                'Could not load walker details. Check your access and connection.',
              );
            }

            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: walkerOrange,
                ),
              );
            }

            final walker = snapshot.data;

            if (walker == null) {
              return _errorView('Walker record not found.');
            }

            return _buildContent(walker);
          },
        ),
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: walkerRed,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: walkerText),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(WalkerAdminModel walker) {
    final data = walker.rawData;
    final status = _statusLabel(walker);
    final active = walker.isActive;
    final submitted = _isSubmitted(walker);

    final normalizedStatus =
        WalkerAdminHelpers.normalizeStatus(walker.status);

    final verificationStatus =
        WalkerAdminHelpers.normalizeStatus(
      walker.verificationStatus,
    );

    final rejected = normalizedStatus == 'rejected' ||
        verificationStatus == 'rejected';

    final suspended = normalizedStatus == 'suspended';

    final screenWidth = MediaQuery.sizeOf(context).width;
    final wide = screenWidth >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 28 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBreadcrumb(),
              const SizedBox(height: 18),
              _buildPageHeader(
                walker: walker,
                submitted: submitted,
                rejected: rejected,
                suspended: suspended,
              ),
              const SizedBox(height: 22),
              _buildProfileCard(data, status, active),
              const SizedBox(height: 16),
              WalkerDetailsSections(
                walker: walker,
                onOpenDocument: (title, document) {
                  _openDocument(
                    title: title,
                    document: document,
                  );
                },
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Account Review',
                icon: Icons.shield_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _responsiveGrid([
                      _info('Account Status', status),
                      _info(
                        'Suspected',
                        data['isSuspected'] == true ? 'Yes' : 'No',
                      ),
                      _info('Last Updated', data['updatedAt']),
                    ]),
                    const SizedBox(height: 14),
                    const Text(
                      'The suspected flag is an administrative review marker, '
                      'not proof of wrongdoing.',
                      style: TextStyle(
                        fontSize: 12,
                        color: walkerMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _outlineAction(
                          'View Security Details',
                          Icons.security_outlined,
                          () => _showSecurityDetails(data),
                        ),
                        _outlineAction(
                          'Activity History',
                          Icons.history,
                          _openActivityHistory,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildFooterNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return const Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'DOJO WALK ADMIN',
          style: TextStyle(
            color: walkerOrange,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        Icon(
          Icons.chevron_right,
          size: 15,
          color: walkerMuted,
        ),
        Text(
          'WALKER MANAGER',
          style: TextStyle(
            color: walkerMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeader({
    required WalkerAdminModel walker,
    required bool submitted,
    required bool rejected,
    required bool suspended,
  }) {
    final actions = <Widget>[];

    if (rejected) {
      actions.add(
        _disabledAction(
          'Rejected Application',
          Icons.block_outlined,
        ),
      );
    } else if (suspended) {
      if (_canReactivate(walker)) {
        actions.add(
          _primaryAction(
            'Reactivate',
            Icons.play_arrow,
            () => _runAdminAction(action: 'reactivate'),
          ),
        );
      } else {
        actions.add(
          _disabledAction(
            'Reactivation Unavailable',
            Icons.block_outlined,
          ),
        );
      }
    } else if (_canSuspend(walker)) {
      actions.add(
        _primaryAction(
          'Suspend',
          Icons.pause_circle_outline,
          () => _startReasonAction(action: 'suspend'),
        ),
      );
    } else if (_canApprove(walker)) {
      actions.add(
        _primaryAction(
          'Verify & Approve',
          Icons.verified_outlined,
          () => _runAdminAction(action: 'approve'),
        ),
      );

      actions.add(
        _outlineAction(
          'Reject',
          Icons.close,
          () => _startReasonAction(action: 'reject'),
        ),
      );

      if (_canRequestCorrection(walker)) {
        actions.add(
          _outlineAction(
            'Request Correction',
            Icons.edit_note_outlined,
            () => _startReasonAction(action: 'correction'),
          ),
        );
      }
    } else if (!submitted) {
      actions.add(
        _disabledAction(
          'Application Not Submitted',
          Icons.hourglass_empty,
        ),
      );
    } else {
      actions.add(
        _disabledAction(
          'No Actions Available',
          Icons.lock_outline,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Walker Details',
          style: TextStyle(
            fontSize: 28,
            color: walkerText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Profile, verification & security',
          style: TextStyle(
            color: walkerMuted,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions,
        ),
        if (_actionLoading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(color: walkerOrange),
        ],
      ],
    );
  }

  Widget _buildProfileCard(
    Map<String, dynamic> data,
    String status,
    bool active,
  ) {
    final name = WalkerAdminHelpers.walkerName(data);

    final photo = WalkerAdminHelpers.photoUrl(data) ?? '';

    final hasPhoto = WalkerAdminHelpers.isHttpUrl(photo);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: walkerBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;

          final profile = Row(
            children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: const Color(0xFFFFE7D1),
                backgroundImage:
                    hasPhoto ? NetworkImage(photo) : null,
                child: hasPhoto
                    ? null
                    : const Icon(
                        Icons.person,
                        size: 32,
                        color: walkerOrange,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: walkerText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Walker ID: ${_text(data['walkerId'], widget.uid)}',
                      style: const TextStyle(
                        color: walkerMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registered: ${WalkerAdminHelpers.formatDate(data['createdAt'])}',
                      style: const TextStyle(
                        color: walkerMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final badges = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusPill(status, _statusColor(status)),
              if (data['isSuspected'] == true)
                _statusPill('Suspected • Review', walkerRed),
              _statusPill(
                active ? 'Account Active' : 'Account Inactive',
                active ? walkerGreen : walkerMuted,
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                profile,
                const SizedBox(height: 16),
                badges,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: profile),
              const SizedBox(width: 18),
              Flexible(child: badges),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: walkerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: walkerOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: walkerText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _responsiveGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800
            ? 3
            : constraints.maxWidth >= 480
                ? 2
                : 1;

        final width =
            (constraints.maxWidth - (columns - 1) * 18) / columns;

        return Wrap(
          spacing: 18,
          runSpacing: 20,
          children: children
              .map(
                (child) => SizedBox(
                  width: width,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _info(String label, dynamic value) {
    final displayValue =
        value is Timestamp || value is DateTime
            ? WalkerAdminHelpers.formatDateTime(value)
            : _text(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: walkerMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          displayValue,
          style: const TextStyle(
            color: walkerText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _primaryAction(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: walkerOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
      onPressed: _actionLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _outlineAction(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: walkerOrange,
        side: const BorderSide(color: walkerOrange),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
      onPressed: _actionLoading ? null : onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }

  Widget _disabledAction(
    String label,
    IconData icon,
  ) {
    return OutlinedButton.icon(
      onPressed: null,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildFooterNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: walkerOrange,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Walker details update live from Firestore. Admin actions '
              'and audit entries are handled by WalkerAdminService. '
              'Document replacement, editable profile fields and '
              'suspected-flag management require separate implementation '
              'and permissions.',
              style: TextStyle(
                color: walkerText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
