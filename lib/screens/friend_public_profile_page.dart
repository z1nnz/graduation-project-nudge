import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../models/study_room_models.dart';
import '../models/social_friend_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'study_room_detail_page.dart';

class FriendPublicProfilePage extends StatelessWidget {
  final String friendId;
  final String name;
  final String signature;
  final int todayFocusSeconds;
  final int score;
  final bool isStudying;
  final Color avatarColor;
  final bool isCurrentUser;
  final AvatarProfile? avatarProfile;
  final String? roomId;
  final String? roomName;
  final String roomNickname;
  final StudyMemberStatus memberStatus;

  const FriendPublicProfilePage({
    super.key,
    required this.friendId,
    required this.name,
    required this.signature,
    required this.todayFocusSeconds,
    required this.score,
    required this.isStudying,
    required this.avatarColor,
    this.isCurrentUser = false,
    this.avatarProfile,
    this.roomId,
    this.roomName,
    this.roomNickname = '',
    this.memberStatus = StudyMemberStatus.offline,
  });

  String _formatMMSS(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _statusText() {
    switch (memberStatus) {
      case StudyMemberStatus.studying:
        return '專注中';
      case StudyMemberStatus.resting:
        return '休息中';
      case StudyMemberStatus.offline:
        return '離線';
    }
  }

  String _characterLabel(AvatarProfile? profile) {
    if (profile == null) return '尚未建立角色';
    return AvatarCatalog.labelFor('faceShape', profile.faceShapeIndex);
  }

  String _partLabel(AvatarProfile? profile, String key, int index) {
    if (profile == null) return '未設定';
    return AvatarCatalog.labelFor(key, index);
  }

  Future<String?> _pickEncouragementType(BuildContext context) async {
    final options = ['加油', '很棒', '繼續保持'];

    return showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '選擇鼓勵類型',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppUI.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (type) => ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: const Icon(Icons.favorite_border),
                    title: Text(type),
                    onTap: () => Navigator.pop(context, type),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openRoom(BuildContext context) {
    if (roomId == null || roomId!.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudyRoomDetailPage(roomId: roomId!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final friend = isCurrentUser
        ? null
        : appState.getSocialFriendById(friendId);

    final isFollowing = friend?.isFollowing ?? false;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('好友公開頁')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('public_profiles')
            .doc(friendId)
            .snapshots(),
        builder: (context, snapshot) {
          int planetCount = 0;
          String currentName = name;
          String currentSignature = signature;
          AvatarProfile? currentProfile = avatarProfile;
          int currentFocusSeconds = todayFocusSeconds;
          String currentNudgeId = '';

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              planetCount = data['planetCount'] as int? ?? 0;
              currentName = data['nickname'] as String? ?? currentName;
              currentSignature =
                  data['signature'] as String? ?? currentSignature;
              currentFocusSeconds =
                  data['focusSeconds'] as int? ?? currentFocusSeconds;
              currentNudgeId =
                  data['username'] as String? ??
                  data['myNudgeId'] as String? ??
                  '';
              if (data['avatarProfile'] != null) {
                currentProfile = AvatarProfile.fromJson(
                  Map<String, dynamic>.from(data['avatarProfile'] as Map),
                );
              }
            }
          }

          final currentScore = (35 + (currentFocusSeconds / 60 / 2))
              .clamp(0, 100)
              .round();
          final isFriend = friend != null;
          final incomingReqs = appState.incomingFriendRequests
              .where(
                (req) =>
                    (currentNudgeId.isNotEmpty &&
                        req.nudgeId == currentNudgeId) ||
                    req.id.contains(friendId),
              )
              .toList();
          final canViewDetails =
              isCurrentUser || isFriend || incomingReqs.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(AppUI.pagePadding),
            children: [
              _FriendShowcaseHero(
                name: isCurrentUser ? '$currentName（你）' : currentName,
                signature: currentSignature,
                avatarColor: avatarColor,
                avatarProfile: currentProfile,
                fallbackText: roomNickname.isNotEmpty
                    ? roomNickname[0]
                    : (currentName.isNotEmpty
                          ? currentName.characters.first
                          : '?'),
                statusText: _statusText(),
                focusText: '今日 ${_formatMMSS(currentFocusSeconds)}',
                scoreText: '$currentScore 分',
                roomName: roomName,
              ),

              const SizedBox(height: AppUI.sectionGap),

              if (canViewDetails) ...[
                Card(
                  shape: AppUI.cardShape(),
                  child: Padding(
                    padding: const EdgeInsets.all(AppUI.innerPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.checkroom_outlined, color: avatarColor),
                            const SizedBox(width: 8),
                            Text(
                              '角色展示',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _characterLabel(currentProfile),
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _OutfitBreakdownGrid(
                          items: [
                            _OutfitPart(
                              icon: Icons.face_retouching_natural_outlined,
                              title: '角色',
                              value: _partLabel(
                                currentProfile,
                                'faceShape',
                                currentProfile?.faceShapeIndex ?? 0,
                              ),
                              color: const Color(0xFF7C6AE6),
                            ),
                            _OutfitPart(
                              icon: Icons.storefront_outlined,
                              title: '取得方式',
                              value: '造型商城',
                              color: const Color(0xFF4F8CFF),
                            ),
                            _OutfitPart(
                              icon: Icons.auto_awesome_outlined,
                              title: '展示類型',
                              value: '完整角色',
                              color: const Color(0xFFF59E0B),
                            ),
                            _OutfitPart(
                              icon: Icons.update_outlined,
                              title: '穿搭',
                              value: '部件換裝',
                              color: const Color(0xFF14B8A6),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppUI.cardGap),

                // 自律星球 (Self-Discipline Planet) Sync Entry
                Card(
                  shape: AppUI.cardShape(),
                  child: Padding(
                    padding: const EdgeInsets.all(AppUI.innerPadding),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: AppUI.softCardOf(
                            context,
                            const Color(0xFFA855F7),
                          ),
                          child: const Icon(
                            Icons.blur_circular_outlined,
                            color: Color(0xFFA855F7),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '自律星球',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '已在 Web 網頁端解鎖了 $planetCount 顆自律星球',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      color: Color(0xFFA855F7),
                                    ),
                                    SizedBox(width: 8),
                                    Text('自律星球參觀指引'),
                                  ],
                                ),
                                content: Text(
                                  isCurrentUser
                                      ? '您總共解鎖了 $planetCount 顆自律星球！\n請登入網頁端控制台，點擊側邊欄「自律星球」或個人頁面，即可進入 3D 星球環繞畫面進行操作與養成。'
                                      : '好友 $currentName 目前已解鎖 $planetCount 顆自律星球！\n請前往網頁版個人名片頁，點擊「🪐 進入自律星球」，即可進入並參觀他的自律星球唷！',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('我知道了'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('查看'),
                        ),
                      ],
                    ),
                  ),
                ),

                if (roomName != null && roomName!.isNotEmpty) ...[
                  const SizedBox(height: AppUI.cardGap),
                  Card(
                    shape: AppUI.cardShape(),
                    child: Padding(
                      padding: const EdgeInsets.all(AppUI.innerPadding),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: AppUI.softCardOf(
                              context,
                              const Color(0xFF4F8CFF),
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              color: Color(0xFF4F8CFF),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '所在自律房',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  roomName!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => _openRoom(context),
                            child: const Text('進入'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Card(
                  shape: AppUI.cardShape(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 44,
                          color: secondaryText,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '自律資訊已隱藏',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '您與該用戶還不是好友。加為好友後即可解鎖查看自律行星與角色穿搭展示！',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppUI.cardGap),

              if (isCurrentUser)
                Card(
                  shape: AppUI.cardShape(),
                  child: Padding(
                    padding: const EdgeInsets.all(AppUI.innerPadding),
                    child: Text(
                      '這是你自己的公開頁，好友看到的角色外觀會和目前穿搭一致。',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                        height: 1.45,
                      ),
                    ),
                  ),
                )
              else if (isFriend) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await context
                              .read<AppState>()
                              .setPublicProfileFollowing(
                                id: friendId,
                                name: currentName,
                                signature: currentSignature,
                                todayFocusSeconds: currentFocusSeconds,
                                isStudying: isStudying,
                                avatarColor: avatarColor,
                                avatarProfile: currentProfile,
                                isFollowing: !isFollowing,
                              );
                          if (context.mounted) {
                            final following =
                                context
                                    .read<AppState>()
                                    .getSocialFriendById(friendId)
                                    ?.isFollowing ??
                                false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  following
                                      ? '已追蹤 $currentName'
                                      : '已取消追蹤 $currentName',
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          isFollowing
                              ? Icons.check_circle_outline
                              : Icons.person_add_alt_1,
                        ),
                        label: Text(isFollowing ? '已追蹤' : '追蹤'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final type = await _pickEncouragementType(context);
                          if (type == null || !context.mounted) return;

                          await context
                              .read<AppState>()
                              .sendEncouragementToFriend(friendId, type: type);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已送出$type給 $currentName')),
                            );
                          }
                        },
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('送出鼓勵'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<AppState>().removeSocialFriend(friendId);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已移除好友：$currentName')),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('移除好友'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ] else ...[
                // Friendship actions for non-friends
                Builder(
                  builder: (context) {
                    final incomingReqs = appState.incomingFriendRequests
                        .where(
                          (req) =>
                              (currentNudgeId.isNotEmpty &&
                                  req.nudgeId == currentNudgeId) ||
                              req.id.contains(friendId),
                        )
                        .toList();
                    final outgoingReqs = appState.outgoingFriendRequests
                        .where(
                          (req) =>
                              (currentNudgeId.isNotEmpty &&
                                  req.nudgeId == currentNudgeId) ||
                              req.id.contains(friendId),
                        )
                        .toList();

                    if (incomingReqs.isNotEmpty) {
                      final req = incomingReqs.first;
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await appState.declineFriendRequest(req.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已拒絕好友邀請')),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.close,
                                color: Colors.redAccent,
                              ),
                              label: const Text(
                                '拒絕邀請',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await appState.acceptFriendRequest(req.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '已成功與 $currentName 成為好友！ 🎉',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('接受邀請'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    } else if (outgoingReqs.isNotEmpty) {
                      return SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: null, // Disabled
                          icon: const Icon(Icons.hourglass_empty),
                          label: const Text('已送出好友邀請，等待回覆中'),
                        ),
                      );
                    } else {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final candidate = SocialFriendProfile(
                              id: friendId,
                              nudgeId: currentNudgeId.isEmpty
                                  ? 'NDG_${friendId.substring(0, 6).toUpperCase()}'
                                  : currentNudgeId,
                              name: currentName,
                              signature: currentSignature,
                              todayFocusSeconds: currentFocusSeconds,
                              isStudying: isStudying,
                              avatarColor: avatarColor,
                              avatarProfile: currentProfile,
                              isFollowing: false,
                              encouragementCount: 0,
                            );
                            await appState.sendFriendRequest(candidate);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已向 $currentName 送出好友邀請！'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('加為好友'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: avatarColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  final String text;

  const _HeroTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _FriendShowcaseHero extends StatelessWidget {
  final String name;
  final String signature;
  final Color avatarColor;
  final AvatarProfile? avatarProfile;
  final String fallbackText;
  final String statusText;
  final String focusText;
  final String scoreText;
  final String? roomName;

  const _FriendShowcaseHero({
    required this.name,
    required this.signature,
    required this.avatarColor,
    required this.avatarProfile,
    required this.fallbackText,
    required this.statusText,
    required this.focusText,
    required this.scoreText,
    required this.roomName,
  });

  @override
  Widget build(BuildContext context) {
    final profile = avatarProfile;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppUI.heroGradient(avatarColor),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        signature,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeroTag(text: statusText),
                          _HeroTag(text: focusText),
                          _HeroTag(text: scoreText),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 136,
                  height: 168,
                  decoration: BoxDecoration(
                    color: (profile?.backgroundColor ?? Colors.white)
                        .withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.62),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: profile != null
                      ? AvatarPreview(
                          profile: profile,
                          size: 136,
                          showBackgroundRing: false,
                        )
                      : Center(
                          child: Text(
                            fallbackText,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (roomName != null && roomName!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ShowcasePill(
              icon: Icons.meeting_room_outlined,
              text: '正在活躍於 $roomName',
              color: Colors.white,
              forceLightText: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _OutfitPart {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _OutfitPart({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
}

class _OutfitBreakdownGrid extends StatelessWidget {
  final List<_OutfitPart> items;

  const _OutfitBreakdownGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.55,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: AppUI.softCardOf(context, item.color),
          child: Row(
            children: [
              Icon(item.icon, color: item.color, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: AppUI.textSecondaryOf(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppUI.textPrimaryOf(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShowcasePill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool forceLightText;

  const _ShowcasePill({
    required this.icon,
    required this.text,
    required this.color,
    this.forceLightText = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = forceLightText ? Colors.white : color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: forceLightText ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: forceLightText
                    ? Colors.white
                    : AppUI.textPrimaryOf(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
