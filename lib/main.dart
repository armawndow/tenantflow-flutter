import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'gateway.dart';
import 'work_item.dart';

void main() => runApp(const TenantFlowApp());

class TenantFlowApp extends StatelessWidget {
  final WorkGateway? gateway;
  const TenantFlowApp({Key? key, this.gateway}) : super(key: key);
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'TenantFlow companion',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff3348df)),
      useMaterial3: true,
    ),
    home: WorkPage(gateway: gateway),
  );
}

class WorkPage extends StatefulWidget {
  final WorkGateway? gateway;
  const WorkPage({Key? key, this.gateway}) : super(key: key);
  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  late WorkGateway gateway;
  final http.Client client = http.Client();
  final title = TextEditingController();
  final description = TextEditingController();
  final origin = TextEditingController(
    text: const String.fromEnvironment(
      'TENANTFLOW_API_URL',
      defaultValue: 'http://127.0.0.1:5088',
    ),
  );
  final apiKey = TextEditingController(text: 'tenant-alpha-key');
  final session = CreateSession(
    () =>
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}',
  );
  List<WorkItem> items = [];
  String message = '';
  bool busy = false;
  bool demo = true;
  int selected = -1;
  @override
  void initState() {
    super.initState();
    gateway = widget.gateway ?? DemoWorkGateway();
    load();
  }

  @override
  void dispose() {
    client.close();
    for (final controller in [title, description, origin, apiKey]) {
      controller.dispose();
    }
    super.dispose();
  }

  String explain(Object error) => error is ApiException
      ? error.toString()
      : 'Request unavailable. Check the API connection and refresh; retrying a create keeps its request key.';
  Future<void> load() async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final loaded = await gateway.list();
      if (mounted) setState(() => items = loaded);
    } catch (error) {
      if (mounted) setState(() => message = explain(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> create() async {
    if (busy) return;
    try {
      final command = session.prepare(title.text, description.text);
      setState(() {
        busy = true;
        message = '';
      });
      await gateway.create(command);
      session.complete();
      title.clear();
      description.clear();
      await load();
    } catch (error) {
      if (mounted)
        setState(() {
          message = error is ArgumentError
              ? error.message.toString()
              : explain(error);
          busy = false;
        });
    }
  }

  Future<void> advance(WorkItem item) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await gateway.changeStatus(item, (item.status + 1) % 3);
      await load();
    } catch (error) {
      if (mounted)
        setState(() {
          message = explain(error);
          busy = false;
        });
    }
  }

  void connect() {
    try {
      gateway = HttpWorkGateway(
        Uri.parse(origin.text.trim()),
        apiKey.text.trim(),
        client,
      );
      demo = false;
      session.complete();
      items = [];
      load();
    } catch (_) {
      setState(
        () => message =
            'Enter an API origin without a path, query, or credentials.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff5f3ec),
    appBar: AppBar(
      title: const Text('tenantflow. / companion'),
      actions: [
        IconButton(
          tooltip: 'Refresh work items',
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Text(
              'FLUTTER PORTFOLIO DEMONSTRATION',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'A clear view of\nthe work ahead.',
              style: TextStyle(
                fontSize: 36,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              demo
                  ? 'Demo workspace · in-memory fixtures · no server connection'
                  : 'Local API workspace · tenant-scoped by server-side API key',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 18),
            ExpansionTile(
              title: const Text('Connect to the C# API'),
              children: [
                TextField(
                  controller: origin,
                  decoration: const InputDecoration(labelText: 'API origin'),
                ),
                TextField(
                  controller: apiKey,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Development fixture API key',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: busy ? null : connect,
                      child: const Text('Connect API'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              gateway = DemoWorkGateway();
                              demo = true;
                              session.complete();
                              load();
                            },
                      child: const Text('Use demo data'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              children: [-1, 0, 1, 2]
                  .map(
                    (value) => ChoiceChip(
                      label: Text(
                        value == -1
                            ? 'All work'
                            : const ['Open', 'In progress', 'Done'][value],
                      ),
                      selected: selected == value,
                      onSelected: (_) => setState(() => selected = value),
                    ),
                  )
                  .toList(),
            ),
            if (busy) const LinearProgressIndicator(),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: const TextStyle(color: Color(0xff8c2525)),
                  ),
                ),
              ),
            ...items
                .where((item) => selected == -1 || item.status == selected)
                .map(
                  (item) => Card(
                    margin: const EdgeInsets.only(top: 13),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(item.description),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${item.statusLabel} · v${item.version}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              TextButton(
                                onPressed: busy ? null : () => advance(item),
                                child: Text(
                                  item.status == 2 ? 'Reopen' : 'Advance',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            if (!busy &&
                items
                    .where((item) => selected == -1 || item.status == selected)
                    .isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No work items in this view.'),
              ),
            const SizedBox(height: 28),
            const Text(
              'Capture the next task',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
            ),
            TextField(
              controller: title,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Work item title'),
            ),
            TextField(
              controller: description,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: busy ? null : create,
                child: const Text('Create work item'),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'New demonstration by Armando Francisco Denardi. Flutter UI source targets web and mobile; this is separate from résumé employment history.',
              style: TextStyle(fontSize: 10, height: 1.7),
            ),
          ],
        ),
      ),
    ),
  );
}
