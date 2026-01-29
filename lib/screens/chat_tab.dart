import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/conversation.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import '../models/group.dart';

/// Onglet Discussions avec liste de conversations et chat côte à côte
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final UserService _userService = UserService();
  final FirestoreService _firestoreService = FirestoreService();
  AppUser? _selectedUser;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  void _selectUser(AppUser user) {
    setState(() {
      _selectedUser = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('Non connecté'));
    }

    return Row(
      children: [
        // ========================================
        // BARRE LATÉRALE GAUCHE - LISTE DES CONVERSATIONS
        // ========================================
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Header de recherche
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher une conversation...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colorScheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Liste des conversations
              Expanded(
                child: StreamBuilder<List<AppUser>>(
                  stream: _userService.getAllUsers(currentUser.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Erreur: ${snapshot.error}'));
                    }

                    final users = snapshot.data ?? [];

                    if (users.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune conversation',
                              style: TextStyle(
                                color: colorScheme.outline,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final conversationId = _firestoreService
                            .getConversationId(currentUser.uid, user.id);

                        return _ConversationTile(
                          user: user,
                          conversationId: conversationId,
                          currentUserId: currentUser.uid,
                          isSelected: _selectedUser?.id == user.id,
                          onTap: () => _selectUser(user),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // ========================================
        // ZONE PRINCIPALE - CONVERSATION
        // ========================================
        Expanded(
          child: _selectedUser == null
              ? _buildEmptyState(context)
              : ChangeNotifierProvider(
                  key: ValueKey(_selectedUser!.id),
                  create: (_) => ChatProvider(
                    currentUserId: currentUser.uid,
                    currentUserName: currentUser.displayName ?? 'Utilisateur',
                    otherUser: _selectedUser!,
                  ),
                  child: ChatScreen(
                    onBack: () => setState(() => _selectedUser = null),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 120,
              color: colorScheme.outline.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Sélectionnez une conversation',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choisissez un contact dans la liste pour commencer à discuter',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tuile représentant une conversation avec compteur non lus
class _ConversationTile extends StatelessWidget {
  final AppUser user;
  final String conversationId;
  final String currentUserId;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.user,
    required this.conversationId,
    required this.currentUserId,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final firestoreService = FirestoreService();

    Widget _buildGroupsSection(BuildContext context, String currentUserId) {
      final firestoreService = FirestoreService();

      return StreamBuilder<List<Group>>(
        stream: firestoreService.getUserGroups(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Groupes (${groups.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                ),
              ),
              ...groups.map((group) => _GroupTile(group: group)),
            ],
          );
        },
      );
    }

    return StreamBuilder<Conversation?>(
      stream: firestoreService.getConversationStream(conversationId),
      builder: (context, snapshot) {
        final conversation = snapshot.data;
        final unreadCount = conversation?.getUnreadCount(currentUserId) ?? 0;
        final hasUnread = unreadCount > 0;

        return Material(
          color:
              isSelected ? colorScheme.secondaryContainer : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Avatar avec statut
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      // Indicateur en ligne
                      if (user.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  // Infos conversation
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom
                        Text(
                          user.displayName,
                          style: TextStyle(
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Dernier message ou statut
                        Text(
                          conversation?.lastMessage ?? 'Aucun message',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasUnread
                                ? colorScheme.onSurface
                                : colorScheme.outline,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Badge compteur non lus
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Widget pour afficher un groupe
class _GroupTile extends StatelessWidget {
  final Group group;

  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        group.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${group.memberIds.length} membres',
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.outline,
        ),
      ),
      trailing: group.unreadCounts.values.fold(0, (a, b) => a + b) > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${group.unreadCounts.values.fold(0, (a, b) => a + b)}',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: () {
        // TODO: Naviguer vers le chat du groupe
        print('Ouvrir le groupe: ${group.name}');
      },
    );
  }
}
