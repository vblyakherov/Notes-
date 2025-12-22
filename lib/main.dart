import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const NotesApp());
}

class Note {
  const Note({
    this.id,
    required this.title,
    required this.body,
    required this.tags,
    required this.updatedAt,
    this.imagePath,
    this.imageBytes,
  });

  final int? id;
  final String title;
  final String body;
  final List<String> tags;
  final DateTime updatedAt;
  final String? imagePath;
  final Uint8List? imageBytes;

  Note copyWith({
    int? id,
    String? title,
    String? body,
    List<String>? tags,
    DateTime? updatedAt,
    String? imagePath,
    Uint8List? imageBytes,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'tags': jsonEncode(tags),
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'image_path': imagePath,
      'image_bytes': imageBytes,
    };
  }

  static Note fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      body: map['body'] as String,
      tags: (jsonDecode(map['tags'] as String) as List<dynamic>)
          .map((tag) => tag.toString())
          .toList(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      imagePath: map['image_path'] as String?,
      imageBytes: map['image_bytes'] as Uint8List?,
    );
  }
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const NotesHomePage(),
    );
  }
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key});

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  final NotesDatabase _database = NotesDatabase.instance;
  final List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _database.fetchNotes();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes
        ..clear()
        ..addAll(notes);
      _isLoading = false;
    });
  }

  void _sortNotes() {
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _openEditor({Note? note, int? index}) async {
    final Note? createdNote = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)),
    );

    if (createdNote != null) {
      final Note savedNote = createdNote.id == null
          ? await _database.insertNote(createdNote)
          : await _database.updateNote(createdNote);

      if (!mounted) {
        return;
      }

      setState(() {
        if (index != null) {
          _notes[index] = savedNote;
        } else {
          _notes.add(savedNote);
        }
        _sortNotes();
      });
    }
  }

  Future<bool> _confirmDelete(Note note) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: Text('«${note.title}» будет удалена без возможности восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _deleteNote(Note note, int index) async {
    if (note.id != null) {
      await _database.deleteNote(note.id!);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _notes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
      ),
      body: _notes.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Dismissible(
                  key: ValueKey(note.id ?? '${note.title}-${note.updatedAt.toIso8601String()}'),
                  background: _SwipeActionBackground(
                    alignment: Alignment.centerLeft,
                    color: Colors.red.shade50,
                    icon: Icons.delete_outline,
                    label: 'Удалить',
                  ),
                  secondaryBackground: _SwipeActionBackground(
                    alignment: Alignment.centerRight,
                    color: Colors.indigo.shade50,
                    icon: Icons.edit_outlined,
                    label: 'Редактировать',
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.endToStart) {
                      await _openEditor(note: note, index: index);
                      return false;
                    }

                    return _confirmDelete(note);
                  },
                  onDismissed: (direction) {
                    if (direction == DismissDirection.startToEnd) {
                      _deleteNote(note, index);
                    }
                  },
                  child: NoteCard(note: note),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: _notes.length,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        note.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (note.imagePath != null || note.imageBytes != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildPreviewThumbnail(),
                  ),
                ],
              ],
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: -4,
                children: note.tags
                    .map(
                      (tag) => Chip(
                        side: BorderSide.none,
                        label: Text('#$tag'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewThumbnail() {
    if (note.imageBytes != null) {
      return Image.memory(
        note.imageBytes!,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
      );
    }

    return Image.file(
      io.File(note.imagePath!),
      height: 64,
      width: 64,
      fit: BoxFit.cover,
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.note});

  final Note? note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagController = TextEditingController();

  final List<String> _tags = [];
  String? _imagePath;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    if (note != null) {
      _titleController.text = note.title;
      _bodyController.text = note.body;
      _tags.addAll(note.tags);
      _imagePath = note.imagePath;
      _imageBytes = note.imageBytes;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final selected = result.files.first;
      setState(() {
        _imagePath = selected.path;
        _imageBytes = selected.bytes;
      });
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) {
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _saveNote() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final note = Note(
      id: widget.note?.id,
      title: _titleController.text.trim(),
      body: _bodyController.text,
      tags: List.of(_tags),
      updatedAt: DateTime.now(),
      imagePath: _imagePath,
      imageBytes: _imageBytes,
    );

    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Новая заметка' : 'Редактирование'),
        actions: [
          IconButton(
            onPressed: _saveNote,
            icon: const Icon(Icons.check),
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Заголовок',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите заголовок';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Текст',
                  hintText: 'Можно вставлять форматированный текст — переносы строк сохранятся',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              _ImagePickerPreview(
                imagePath: _imagePath,
                imageBytes: _imageBytes,
                onPick: _pickImage,
              ),
              const SizedBox(height: 12),
              _TagEditor(
                tagController: _tagController,
                tags: _tags,
                onAddTag: _addTag,
                onRemoveTag: _removeTag,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerPreview extends StatelessWidget {
  const _ImagePickerPreview({
    required this.imagePath,
    required this.imageBytes,
    required this.onPick,
  });

  final String? imagePath;
  final Uint8List? imageBytes;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Добавить картинку'),
            ),
            if (imagePath != null || imageBytes != null) ...[
              const SizedBox(width: 12),
              Text(
                kIsWeb && imagePath == null ? 'Файл добавлен' : 'Файл: ${imagePath ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
        if (imagePath != null || imageBytes != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb && imageBytes != null
                ? Image.memory(imageBytes!, height: 180, fit: BoxFit.cover)
                : Image.file(io.File(imagePath!), height: 180, fit: BoxFit.cover),
          ),
        ],
      ],
    );
  }
}

class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.tagController,
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  final TextEditingController tagController;
  final List<String> tags;
  final VoidCallback onAddTag;
  final void Function(String) onRemoveTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Хештеги', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: tagController,
                decoration: const InputDecoration(
                  hintText: 'Например: работа, идеи',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onAddTag(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onAddTag,
              child: const Text('Добавить'),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: -4,
            children: tags
                .map(
                  (tag) => InputChip(
                    label: Text('#$tag'),
                    onDeleted: () => onRemoveTag(tag),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Пока нет заметок',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Создайте первую заметку, добавьте заголовок, текст, картинку и хештеги.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotesDatabase {
  NotesDatabase._();

  static final NotesDatabase instance = NotesDatabase._();

  static const String _tableNotes = 'notes';
  Database? _database;

  Future<Database> get database async {
    final existingDatabase = _database;
    if (existingDatabase != null) {
      return existingDatabase;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, 'notes.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableNotes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            tags TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            image_path TEXT,
            image_bytes BLOB
          )
        ''');
      },
    );
  }

  Future<List<Note>> fetchNotes() async {
    final db = await database;
    final maps = await db.query(
      _tableNotes,
      orderBy: 'updated_at DESC',
    );
    return maps.map(Note.fromMap).toList();
  }

  Future<Note> insertNote(Note note) async {
    final db = await database;
    final id = await db.insert(_tableNotes, note.toMap());
    return note.copyWith(id: id);
  }

  Future<Note> updateNote(Note note) async {
    final db = await database;
    await db.update(
      _tableNotes,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    return note;
  }

  Future<void> deleteNote(int id) async {
    final db = await database;
    await db.delete(
      _tableNotes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
