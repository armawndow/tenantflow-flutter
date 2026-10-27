import 'dart:convert';
import 'package:http/http.dart' as http;
import 'work_item.dart';

abstract class WorkGateway {
  Future<List<WorkItem>> list();
  Future<WorkItem> create(CreateCommand command);
  Future<WorkItem> changeStatus(WorkItem item, int status);
}

class ApiException implements Exception {
  final int status;
  ApiException(this.status);
  @override
  String toString() => status == 401
      ? 'The demo API key was rejected.'
      : status == 412
      ? 'This item changed elsewhere. Refresh before editing again.'
      : status == 409
      ? 'This request key was used with different data. Edit and submit a new request.'
      : 'The API request failed ($status).';
}

class HttpWorkGateway implements WorkGateway {
  final Uri baseUri;
  final String apiKey;
  final http.Client client;
  HttpWorkGateway(this.baseUri, this.apiKey, this.client) {
    if (!['http', 'https'].contains(baseUri.scheme) ||
        !baseUri.hasAuthority ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        (baseUri.path.isNotEmpty && baseUri.path != '/')) {
      throw ArgumentError('Use an API origin, such as http://127.0.0.1:5086.');
    }
  }
  Map<String, String> get _headers => {
    'X-Api-Key': apiKey,
    'Content-Type': 'application/json',
  };
  WorkItem _item(String body) =>
      WorkItem.fromJson(jsonDecode(body) as Map<String, dynamic>);
  @override
  Future<List<WorkItem>> list() async {
    final response = await client
        .get(baseUri.resolve('/api/work-items'), headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw ApiException(response.statusCode);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((dynamic x) => WorkItem.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WorkItem> create(CreateCommand command) async {
    final response = await client
        .post(
          baseUri.resolve('/api/work-items'),
          headers: {..._headers, 'Idempotency-Key': command.key},
          body: jsonEncode({
            'title': command.title,
            'description': command.description,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 201) throw ApiException(response.statusCode);
    return _item(response.body);
  }

  @override
  Future<WorkItem> changeStatus(WorkItem item, int status) async {
    if (status < 0 || status > 2) throw ArgumentError('Unknown status.');
    final response = await client
        .put(
          baseUri.resolve('/api/work-items/${Uri.encodeComponent(item.id)}'),
          headers: {..._headers, 'If-Match': '"${item.version}"'},
          body: jsonEncode({
            'title': item.title,
            'description': item.description,
            'status': status,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw ApiException(response.statusCode);
    return _item(response.body);
  }
}

class DemoWorkGateway implements WorkGateway {
  final List<WorkItem> _items = [
    const WorkItem(
      'demo-1',
      'Review tenant isolation',
      'Illustrative work item. No customer data.',
      0,
      1,
    ),
    const WorkItem(
      'demo-2',
      'Document retry behavior',
      'Explain idempotency and stale update handling.',
      1,
      1,
    ),
  ];
  int _next = 3;
  final Map<String, WorkItem> _created = {};
  @override
  Future<List<WorkItem>> list() async => List<WorkItem>.of(_items);
  @override
  Future<WorkItem> create(CreateCommand command) async {
    if (_created.containsKey(command.key)) {
      final old = _created[command.key]!;
      if (old.title != command.title || old.description != command.description)
        throw ApiException(409);
      return old;
    }
    final item = WorkItem(
      'demo-${_next++}',
      command.title,
      command.description,
      0,
      1,
    );
    _created[command.key] = item;
    _items.add(item);
    return item;
  }

  @override
  Future<WorkItem> changeStatus(WorkItem item, int status) async {
    final index = _items.indexWhere((x) => x.id == item.id);
    if (index < 0) throw ApiException(404);
    if (_items[index].version != item.version) throw ApiException(412);
    if (status < 0 || status > 2) throw ArgumentError('Unknown status.');
    final updated = WorkItem(
      item.id,
      item.title,
      item.description,
      status,
      item.version + 1,
    );
    _items[index] = updated;
    return updated;
  }
}
