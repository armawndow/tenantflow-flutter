class WorkItem {
  final String id;
  final String title;
  final String description;
  final int status;
  final int version;
  const WorkItem(
    this.id,
    this.title,
    this.description,
    this.status,
    this.version,
  );
  factory WorkItem.fromJson(Map<String, dynamic> value) {
    final id = value['id'];
    final title = value['title'];
    final description = value['description'] ?? '';
    final status = value['status'];
    final version = value['version'];
    if (id is! String ||
        title is! String ||
        description is! String ||
        status is! int ||
        status < 0 ||
        status > 2 ||
        version is! int ||
        version < 1) {
      throw const FormatException('The API returned an invalid work item.');
    }
    return WorkItem(id, title, description, status, version);
  }
  String get statusLabel => const ['Open', 'In progress', 'Done'][status];
}

class CreateCommand {
  final String title;
  final String description;
  final String key;
  const CreateCommand(this.title, this.description, this.key);
}

// Retains the same key when the same submission is retried after a network failure.
class CreateSession {
  final String Function() generateKey;
  CreateCommand? _pending;
  CreateSession(this.generateKey);
  CreateCommand prepare(String title, String description) {
    title = title.trim();
    description = description.trim();
    if (title.isEmpty || title.length > 200 || description.length > 2000) {
      throw ArgumentError(
        'Enter a title up to 200 characters and description up to 2,000.',
      );
    }
    if (_pending?.title != title || _pending?.description != description) {
      _pending = CreateCommand(title, description, generateKey());
    }
    return _pending!;
  }

  void complete() {
    _pending = null;
  }
}
