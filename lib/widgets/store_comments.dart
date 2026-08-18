import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';

class StoreCommentsEntry extends StatefulWidget {
  const StoreCommentsEntry({super.key});

  @override
  State<StoreCommentsEntry> createState() => _StoreCommentsEntryState();
}

class _StoreCommentsEntryState extends State<StoreCommentsEntry> {
  final _firebase = FirebaseService();
  int _count = 0;
  int _likesTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final list = await _firebase.fetchVisibleStoreComments();
      if (!mounted) return;
      setState(() {
        _count = list.length;
        _likesTotal = list.fold(0, (s, c) => s + _firebase.commentLikeCount(c));
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () async {
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _CommentsSheet(),
            );
            _loadCounts();
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👨🏻‍💼 👩🏻‍💼', style: TextStyle(fontSize: 20, height: 1)),
                const SizedBox(width: 10),
                const Icon(Icons.chat_bubble_outline, size: 22, color: AppColors.textDark),
                const SizedBox(width: 4),
                Text('$_count', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                const Icon(Icons.favorite_border, size: 22, color: AppColors.textDark),
                const SizedBox(width: 4),
                Text('$_likesTotal', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Prompt post-compra si el usuario aún no comentó.
class StoreCommentPrompt extends StatefulWidget {
  const StoreCommentPrompt({super.key});

  @override
  State<StoreCommentPrompt> createState() => _StoreCommentPromptState();
}

class _StoreCommentPromptState extends State<StoreCommentPrompt> {
  final _firebase = FirebaseService();
  bool _open = false;
  bool _form = false;
  String? _checkedUid;

  Future<void> _check() async {
    final uid = context.read<AppProvider>().user?.uid;
    if (uid == null) return;
    try {
      final hasBuy = await _firebase.userHasPurchases(uid);
      final comment = await _firebase.getUserStoreComment(uid);
      if (!mounted) return;
      if (hasBuy && comment == null) setState(() => _open = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AppProvider>().user?.uid;
    if (uid != _checkedUid) {
      _checkedUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _check();
      });
    }
    if (!_open) return const SizedBox.shrink();
    return Positioned.fill(
      child: Material(
        color: const Color(0xB30F172A),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: const BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: SafeArea(
              top: false,
              child: _form
                  ? _CommentForm(
                      mode: 'create',
                      onCancel: () => setState(() => _open = false),
                      onSaved: () => setState(() => _open = false),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _handle(),
                        const Text(
                          '¿Deseas dejar un comentario?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cuéntanos cómo te fue con tu compra. Solo puedes publicar un comentario.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textLight),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => setState(() => _form = true),
                            child: const Text('Sí, quiero comentar'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => setState(() => _open = false),
                            child: const Text('Ahora no'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet();

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _firebase = FirebaseService();
  bool _loading = true;
  List<Map<String, dynamic>> _comments = [];
  Map<String, dynamic>? _mine;
  String? _formMode; // create | edit
  String? _likingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _firebase.fetchVisibleStoreComments();
      if (!mounted) return;
      final uid = context.read<AppProvider>().user?.uid;
      final mine = uid == null ? null : await _firebase.getUserStoreComment(uid);
      if (!mounted) return;
      setState(() {
        _comments = list;
        _mine = mine;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canEdit {
    final mine = _mine;
    if (mine == null) return false;
    final edits = (mine['editCount'] as num?)?.toInt() ?? 0;
    return edits < FirebaseService.commentMaxEdits && mine['hidden'] != true;
  }

  Future<void> _toggleLike(Map<String, dynamic> comment) async {
    final uid = context.read<AppProvider>().user?.uid;
    if (uid == null) {
      Navigator.pop(context);
      context.push('/login');
      return;
    }
    final id = comment['id']?.toString();
    if (id == null || _likingId != null) return;
    setState(() => _likingId = id);
    final wasLiked = _firebase.commentLikedByUser(comment, uid);
    final prevCount = _firebase.commentLikeCount(comment);
    setState(() {
      _comments = _comments.map((c) {
        if (c['id'] != id) return c;
        final likedBy = List.from(c['likedBy'] is List ? c['likedBy'] as List : []);
        if (wasLiked) {
          likedBy.remove(uid);
        } else {
          likedBy.add(uid);
        }
        return {...c, 'likedBy': likedBy, 'likeCount': (prevCount + (wasLiked ? -1 : 1)).clamp(0, 1 << 30)};
      }).toList();
    });
    try {
      final result = await _firebase.toggleStoreCommentLike(id, uid);
      if (!mounted) return;
      setState(() {
        _comments = _comments.map((c) {
          if (c['id'] != id) return c;
          return {...c, 'likeCount': result.likeCount};
        }).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = _comments.map((c) {
          if (c['id'] != id) return c;
          return {...c, 'likeCount': prevCount};
        }).toList();
      });
    } finally {
      if (mounted) setState(() => _likingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AppProvider>().user?.uid;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _handle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Comentarios',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _formMode != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: _CommentForm(
                      mode: _formMode!,
                      initial: _formMode == 'edit' ? _mine : null,
                      onCancel: () => setState(() => _formMode = null),
                      onSaved: () async {
                        setState(() => _formMode = null);
                        await _load();
                      },
                    ),
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Aún no hay comentarios públicos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textLight),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _comments.length + (uid != null && _mine == null ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (uid != null && _mine == null && i == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _formMode = 'create'),
                                    child: const Text('Escribe tu comentario'),
                                  ),
                                );
                              }
                              final idx = uid != null && _mine == null ? i - 1 : i;
                              final c = _comments[idx];
                              final isMine = _mine != null && c['id'] == _mine!['id'];
                              final liked = _firebase.commentLikedByUser(c, uid);
                              final likes = _firebase.commentLikeCount(c);
                              final name = (c['userName'] ?? 'Cliente').toString();
                              final img = c['userImg']?.toString();
                              final rating = (c['rating'] as num?)?.toInt() ?? 0;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundImage: img != null && img.isNotEmpty
                                                ? CachedNetworkImageProvider(img)
                                                : null,
                                            child: img == null || img.isEmpty
                                                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'C')
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                                Row(
                                                  children: List.generate(
                                                    5,
                                                    (s) => Icon(
                                                      Icons.star,
                                                      size: 14,
                                                      color: s < rating
                                                          ? AppColors.featured
                                                          : AppColors.border,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isMine && _canEdit)
                                            IconButton(
                                              onPressed: () => setState(() => _formMode = 'edit'),
                                              icon: const Icon(Icons.edit, size: 18),
                                              tooltip: 'Editar mi comentario',
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('${c['text'] ?? ''}'),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => _toggleLike(c),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              liked ? Icons.favorite : Icons.favorite_border,
                                              size: 18,
                                              color: liked ? AppColors.discount : AppColors.textMedium,
                                            ),
                                            const SizedBox(width: 4),
                                            Text('$likes'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _CommentForm extends StatefulWidget {
  const _CommentForm({
    required this.mode,
    required this.onCancel,
    required this.onSaved,
    this.initial,
  });

  final String mode;
  final Map<String, dynamic>? initial;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<_CommentForm> createState() => _CommentFormState();
}

class _CommentFormState extends State<_CommentForm> {
  final _firebase = FirebaseService();
  late final TextEditingController _text;
  late int _rating;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initial?['text']?.toString() ?? '');
    _rating = (widget.initial?['rating'] as num?)?.toInt() ?? 5;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<AppProvider>().user;
    if (user == null) return;
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      if (widget.mode == 'edit') {
        await _firebase.updateStoreComment(
          userId: user.uid,
          text: _text.text,
          rating: _rating,
        );
      } else {
        await _firebase.createStoreComment(
          userId: user.uid,
          userName: user.displayName,
          userImg: user.imageUrl,
          text: _text.text,
          rating: _rating,
        );
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editsLeft = widget.mode == 'edit'
        ? (FirebaseService.commentMaxEdits - ((widget.initial?['editCount'] as num?)?.toInt() ?? 0))
            .clamp(0, FirebaseService.commentMaxEdits)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Tu valoración', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Row(
          children: List.generate(
            5,
            (i) => IconButton(
              onPressed: () => setState(() => _rating = i + 1),
              icon: Icon(
                Icons.star,
                color: i < _rating ? AppColors.featured : AppColors.border,
              ),
            ),
          ),
        ),
        Text(
          'Comentario (${_text.text.length}/${FirebaseService.commentMaxLen})',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _text,
          maxLength: FirebaseService.commentMaxLen,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Cuéntanos tu experiencia (corto)…',
          ),
        ),
        if (editsLeft != null)
          Text(
            'Ediciones restantes: $editsLeft de ${FirebaseService.commentMaxEdits}',
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: AppColors.discount)),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : widget.onCancel,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving
                    ? 'Guardando…'
                    : widget.mode == 'edit'
                        ? 'Guardar cambios'
                        : 'Publicar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _handle() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
