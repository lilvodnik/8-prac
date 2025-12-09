import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _db = FirebaseFirestore.instance;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  Future<void> _createNote() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) return;

    final now = Timestamp.now();
    await _db.collection('notes').add({
      'title': title,
      'content': content,
      'createdAt': now,
      'updatedAt': now,
    });

    _titleCtrl.clear();
    _contentCtrl.clear();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _updateNote(DocumentReference ref, String title, String content) async {
    await ref.update({
      'title': title,
      'content': content,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> _deleteNote(DocumentReference ref) async {
    await ref.delete();
  }

  void _openCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Новая заметка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Заголовок')),
            TextField(controller: _contentCtrl, decoration: const InputDecoration(labelText: 'Текст')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(onPressed: _createNote, child: const Text('Сохранить')),
        ],
      ),
    );
  }

  void _openEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final contentCtrl = TextEditingController(text: data['content'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Редактировать'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Заголовок')),
            TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Текст')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              await _updateNote(doc.reference, titleCtrl.text.trim(), contentCtrl.text.trim());
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Обновить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesStream = _db.collection('notes').orderBy('createdAt', descending: true).snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Ошибка загрузки'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Пока нет заметок'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final title = data['title'] ?? '(без названия)';
              final content = data['content'] ?? '';

              return Card(
                child: ListTile(
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _openEditDialog(doc),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteNote(doc.reference),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
