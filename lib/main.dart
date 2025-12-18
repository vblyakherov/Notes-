import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const NotesApp());
}

class Note {
  const Note({
    required this.title,
    required this.body,
    required this.tags,
    this.imagePath,
    this.imageBytes,
  });

  final String title;
  final String body;
  final List<String> tags;
  final String? imagePath;
  final Uint8List? imageBytes;
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
  final List<Note> _notes = [
    const Note(
      title: 'Первая заметка',
      body: 'Это пример текста заметки. Добавьте свои мысли, планы или идеи.',
      tags: ['пример', 'черновик'],
    ),
  ];

  Future<void> _openEditor() async {
    final Note? createdNote = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NoteEditorPage()),
    );

    if (createdNote != null) {
      setState(() => _notes.insert(0, createdNote));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                return NoteCard(note: note);
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: _notes.length,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditor,
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
  const NoteEditorPage({super.key});

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
      title: _titleController.text.trim(),
      body: _bodyController.text,
      tags: List.of(_tags),
      imagePath: _imagePath,
      imageBytes: _imageBytes,
    );

    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая заметка'),
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
