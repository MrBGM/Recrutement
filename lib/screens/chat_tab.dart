import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/conversation.dart';
import '../models/group.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';

/// Onglet Discussions avec liste de conversations et chat côte à côte
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final UserService _userService = UserService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  AppUser? _selectedUser;
  Group? _selectedGroup;
  String? _currentUserId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  void _selectUser(AppUser user) {
    setState(() {
      _selectedUser = user;
      _selectedGroup = null;
    });
  }

  void _selectGroup(Group group) {
    setState(() {
      _selectedGroup = group;
      _selectedUser = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedUser = null;
      _selectedGroup = null;
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
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une conversation...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
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

              // Liste des conversations (1-1 + groupes)
              Expanded(
                child: _buildConversationsList(currentUser.uid),
              ),
            ],
          ),
        ),

        // ========================================
        // ZONE PRINCIPALE - CONVERSATION
        // ========================================
        Expanded(
          child: _buildMainContent(currentUser),
        ),
      ],
    );
  }

  /// Construit la liste des conversations (1-1 et groupes)
  Widget _buildConversationsList(String currentUserId) {
    return CustomScrollView(
      slivers: [
        // Section Groupes
        SliverToBoxAdapter(
          child: _buildGroupsSection(currentUserId),
        ),
        // Section Conversations 1-1
        SliverToBoxAdapter(
          child: _buildUsersSection(currentUserId),
        ),
      ],
    );
  }

  /// Section des groupes
  Widget _buildGroupsSection(String currentUserId) {
    return StreamBuilder<List<Group>>(
      stream: _firestoreService.getUserGroups(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final groups = snapshot.data ?? [];

        // Filtrer par recherche
        final filteredGroups = _searchQuery.isEmpty
            ? groups
            : groups.where((g) =>
                g.name.toLowerCase().contains(_searchQuery)).toList();

        if (filteredGroups.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Groupes (${filteredGroups.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...filteredGroups.map((group) => _GroupTile(
              group: group,
              currentUserId: currentUserId,
              isSelected: _selectedGroup?.id == group.id,
              onTap: () => _selectGroup(group),
            )),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  /// Section des conversations 1-1
  Widget _buildUsersSection(String currentUserId) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<AppUser>>(
      stream: _userService.getAllUsers(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];

        // Filtrer par recherche
        final filteredUsers = _searchQuery.isEmpty
            ? users
            : users.where((u) =>
                u.displayName.toLowerCase().contains(_searchQuery) ||
                u.email.toLowerCase().contains(_searchQuery)).toList();

        if (filteredUsers.isEmpty && _searchQuery.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun résultat pour "$_searchQuery"',
                  style: TextStyle(color: colorScheme.outline),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (filteredUsers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Messages (${filteredUsers.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...filteredUsers.map((user) {
              final conversationId = _firestoreService
                  .getConversationId(currentUserId, user.id);

              return _ConversationTile(
                user: user,
                conversationId: conversationId,
                currentUserId: currentUserId,
                isSelected: _selectedUser?.id == user.id,
                onTap: () => _selectUser(user),
              );
            }),
          ],
        );
      },
    );
  }

  /// Contenu principal (chat ou état vide)
  Widget _buildMainContent(User currentUser) {
    // Chat de groupe sélectionné
    if (_selectedGroup != null) {
      return GroupChatScreen(
        key: ValueKey(_selectedGroup!.id),
        group: _selectedGroup!,
      );
    }

    // Chat 1-1 sélectionné
    if (_selectedUser != null) {
      return ChangeNotifierProvider(
        key: ValueKey(_selectedUser!.id),
        create: (_) => ChatProvider(
          currentUserId: currentUser.uid,
          currentUserName: currentUser.displayName ?? 'Utilisateur',
          otherUser: _selectedUser!,
        ),
        child: ChatScreen(
          onBack: _clearSelection,
        ),
      );
    }

    // État vide
    return _buildEmptyState(context);
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
              color: colorScheme.outline.withAlpha(77),
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
              'Choisissez un contact ou un groupe pour commencer à discuter',
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

/// Tuile représentant une conversation 1-1 avec compteur non lus
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
                    color: colorScheme.outlineVariant.withAlpha(77),
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

/// Tuile pour afficher un groupe
class _GroupTile extends StatelessWidget {
  final Group group;
  final String currentUserId;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupTile({
    required this.group,
    required this.currentUserId,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unreadCount = group.unreadCounts[currentUserId] ?? 0;
    final hasUnread = unreadCount > 0;

    return Material(
      color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withAlpha(77),
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar du groupe
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.secondaryContainer,
                backgroundImage: group.photoUrl != null
                    ? NetworkImage(group.photoUrl!)
                    : null,
                child: group.photoUrl == null
                    ? Icon(
                        Icons.group,
                        color: colorScheme.onSecondaryContainer,
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              // Infos groupe
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
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
                    Text(
                      group.lastMessage ?? '${group.memberIds.length} membres',
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
  }
}
