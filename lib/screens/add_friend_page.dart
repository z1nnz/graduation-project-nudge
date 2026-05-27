import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/avatar_profile.dart';
import '../models/friend_request.dart';
import '../models/social_friend_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final TextEditingController _idController = TextEditingController();
  SocialFriendProfile? _candidate;
  bool _searched = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  bool _searching = false;

  Future<void> _search(AppState appState) async {
    final query = _idController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searched = true;
      _searching = true;
      _candidate = null;
    });

    try {
      final candidate = await appState.searchFriendByNudgeId(query);
      setState(() {
        _candidate = candidate;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() {
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest(AppState appState) async {
    final candidate = _candidate;
    if (candidate == null) return;
    await appState.sendFriendRequest(candidate);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已送出好友邀請給 ${candidate.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accentColor = appState.currentIconColor;

    return Scaffold(
      backgroundColor: AppUI.scaffoldBackgroundOf(context),
      appBar: AppBar(title: const Text('加入好友')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppUI.pagePadding,
          8,
          AppUI.pagePadding,
          28,
        ),
        children: [
          _MyFriendCodeCard(
            nudgeId: appState.myNudgeId,
            accentColor: accentColor,
          ),
          const SizedBox(height: AppUI.sectionGap),
          _SearchByIdCard(
            controller: _idController,
            candidate: _candidate,
            searched: _searched,
            searching: _searching,
            accentColor: accentColor,
            primaryText: primaryText,
            secondaryText: secondaryText,
            onSearch: () => _search(appState),
            onSendRequest: () => _sendRequest(appState),
            onScannerTap: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('掃描好友 QR Code')),
                    body: MobileScanner(
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                          final String code = barcodes.first.rawValue!;
                          Navigator.pop(context, code);
                        }
                      },
                    ),
                  ),
                ),
              ).then((result) async {
                if (result != null && result is String) {
                  final candidate = await appState.searchFriendFromInvite(result);
                  if (candidate != null) {
                    setState(() {
                      _searched = true;
                      _candidate = candidate;
                      _idController.text = candidate.nudgeId;
                    });
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('無效的邀請連結或找不到該使用者')),
                    );
                  }
                }
              });
            },
          ),
          const SizedBox(height: AppUI.sectionGap),
          _RequestSection(
            title: '收到的邀請',
            emptyText: '目前沒有新的好友邀請。',
            requests: appState.incomingFriendRequests,
            accentColor: accentColor,
            primaryText: primaryText,
            secondaryText: secondaryText,
            onAccept: appState.acceptFriendRequest,
            onDecline: appState.declineFriendRequest,
          ),
          const SizedBox(height: AppUI.sectionGap),
          _RequestSection(
            title: '已送出的邀請',
            emptyText: '還沒有送出的邀請。',
            requests: appState.outgoingFriendRequests,
            accentColor: const Color(0xFF7C6AE6),
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ],
      ),
    );
  }
}

class _MyFriendCodeCard extends StatelessWidget {
  final String nudgeId;
  final Color accentColor;

  const _MyFriendCodeCard({required this.nudgeId, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppUI.heroGradient(accentColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的好友 ID',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  nudgeId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CustomPaint(painter: _QrPlaceholderPainter(nudgeId)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroActionButton(
                  icon: Icons.copy_rounded,
                  label: '複製 ID',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: nudgeId));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('已複製 $nudgeId')));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroActionButton(
                  icon: Icons.qr_code_2_rounded,
                  label: '出示 QR',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('目前顯示的是本機 QR 佔位圖')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _SearchByIdCard extends StatelessWidget {
  final TextEditingController controller;
  final SocialFriendProfile? candidate;
  final bool searched;
  final bool searching;
  final Color accentColor;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onSearch;
  final VoidCallback onSendRequest;
  final VoidCallback onScannerTap;

  const _SearchByIdCard({
    required this.controller,
    required this.candidate,
    required this.searched,
    required this.searching,
    required this.accentColor,
    required this.primaryText,
    required this.secondaryText,
    required this.onSearch,
    required this.onSendRequest,
    required this.onScannerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '用 ID 加好友',
            style: TextStyle(
              color: primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '先輸入對方的 Nudge ID。之後接後端時，這裡會改成真正搜尋使用者。',
            style: TextStyle(color: secondaryText, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: '例如 NDG-MINA01',
              prefixIcon: const Icon(Icons.badge_outlined),
              suffixIcon: IconButton(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onSubmitted: (_) => onSearch(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: searching ? null : onSearch,
                  icon: searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_search_rounded),
                  label: Text(searching ? '搜尋中...' : '搜尋 ID'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: onScannerTap,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ],
          ),
          if (candidate != null) ...[
            const SizedBox(height: 14),
            _CandidateCard(candidate: candidate!, onSendRequest: onSendRequest),
          ] else if (searched) ...[
            const SizedBox(height: 14),
            _EmptyNotice(
              icon: Icons.search_off_rounded,
              text: '目前找不到這個 ID。你可以先試試 NDG-MINA01 或 NDG-RAY777。',
            ),
          ],
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final SocialFriendProfile candidate;
  final VoidCallback onSendRequest;

  const _CandidateCard({required this.candidate, required this.onSendRequest});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUI.isDark(context)
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          AvatarPreview(
            profile: candidate.avatarProfile ?? AvatarProfile.initial(),
            size: 58,
            showBackgroundRing: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.name,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  candidate.nudgeId,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  candidate.signature,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton(onPressed: onSendRequest, child: const Text('邀請')),
        ],
      ),
    );
  }
}

class _RequestSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<FriendRequest> requests;
  final Color accentColor;
  final Color primaryText;
  final Color secondaryText;
  final Future<void> Function(String requestId)? onAccept;
  final Future<void> Function(String requestId)? onDecline;

  const _RequestSection({
    required this.title,
    required this.emptyText,
    required this.requests,
    required this.accentColor,
    required this.primaryText,
    required this.secondaryText,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            _EmptyNotice(icon: Icons.inbox_outlined, text: emptyText)
          else
            ...requests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RequestTile(
                  request: request,
                  accentColor: accentColor,
                  onAccept: onAccept,
                  onDecline: onDecline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final FriendRequest request;
  final Color accentColor;
  final Future<void> Function(String requestId)? onAccept;
  final Future<void> Function(String requestId)? onDecline;

  const _RequestTile({
    required this.request,
    required this.accentColor,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final canRespond = onAccept != null && onDecline != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(
          alpha: AppUI.isDark(context) ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: accentColor.withValues(alpha: 0.18),
            child: Icon(Icons.person_rounded, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${request.nudgeId} · ${request.signature}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          if (canRespond) ...[
            IconButton(
              onPressed: () => onDecline!(request.id),
              icon: const Icon(Icons.close_rounded),
            ),
            IconButton.filled(
              onPressed: () => onAccept!(request.id),
              icon: const Icon(Icons.check_rounded),
            ),
          ] else
            _StatusPill(text: '等待回覆', color: accentColor),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppUI.textSecondaryOf(context), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppUI.textSecondaryOf(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _QrPlaceholderPainter extends CustomPainter {
  final String seed;

  _QrPlaceholderPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF111827);
    final cell = size.width / 9;

    void drawFinder(int x, int y) {
      final rect = Rect.fromLTWH(x * cell, y * cell, cell * 3, cell * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.35)),
        paint,
      );
      final clear = Paint()..color = Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(cell * 0.55),
          Radius.circular(cell * 0.18),
        ),
        clear,
      );
      canvas.drawCircle(
        Offset((x + 1.5) * cell, (y + 1.5) * cell),
        cell * 0.42,
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(6, 0);
    drawFinder(0, 6);

    var hash = seed.hashCode.abs();
    for (int y = 0; y < 9; y++) {
      for (int x = 0; x < 9; x++) {
        final inFinder =
            (x < 3 && y < 3) || (x > 5 && y < 3) || (x < 3 && y > 5);
        if (inFinder) continue;
        hash = (hash * 1103515245 + 12345) & 0x7fffffff;
        if (hash % 3 == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                x * cell + cell * 0.18,
                y * cell + cell * 0.18,
                cell * 0.64,
                cell * 0.64,
              ),
              Radius.circular(cell * 0.16),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPlaceholderPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}
