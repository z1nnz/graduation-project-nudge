import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../models/study_room_models.dart';
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
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          _FriendShowcaseHero(
            name: isCurrentUser ? '$name（你）' : name,
            signature: signature,
            avatarColor: avatarColor,
            avatarProfile: avatarProfile,
            fallbackText: roomNickname.isNotEmpty
                ? roomNickname[0]
                : (name.isNotEmpty ? name.characters.first : '?'),
            statusText: _statusText(),
            focusText: '今日 ${_formatMMSS(todayFocusSeconds)}',
            scoreText: '$score 分',
            roomName: roomName,
          ),

          const SizedBox(height: AppUI.sectionGap),

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
                        _characterLabel(avatarProfile),
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
                          avatarProfile,
                          'faceShape',
                          avatarProfile?.faceShapeIndex ?? 0,
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
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await context.read<AppState>().setPublicProfileFollowing(
                        id: friendId,
                        name: name,
                        signature: signature,
                        todayFocusSeconds: todayFocusSeconds,
                        isStudying: isStudying,
                        avatarColor: avatarColor,
                        avatarProfile: avatarProfile,
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
                              following ? '已追蹤 $name' : '已取消追蹤 $name',
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

                      await context.read<AppState>().sendEncouragementToFriend(
                        friendId,
                        type: type,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已送出$type給 $name')),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('已移除好友：$name')));
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('移除好友'),
            ),
          ],

          const SizedBox(height: 20),
        ],
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
