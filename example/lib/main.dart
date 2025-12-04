// main.dart
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/appflowy_editor_sync_plugin.dart';
import 'package:appflowy_editor_sync_plugin/types/sync_db_attributes.dart';
import 'package:appflowy_editor_sync_plugin_example/desktop_editor.dart';
import 'package:appflowy_editor_sync_plugin_example/mobile_editor.dart';
import 'package:appflowy_editor_sync_plugin_example/remote_sync_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:universal_platform/universal_platform.dart';

part 'main.g.dart';

//
// ===================================================
// Models (no local DB)
// ===================================================
//
class DocumentItem {
  final String id;
  final String name;
  final DateTime createdAt;

  DocumentItem({required this.id, required this.name, required this.createdAt});

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
    id: json['id'].toString(),
    name: json['name'] ?? '',
    createdAt: DateTime.parse(json['createdAt']),
  );
}

//
// ===================================================
// Remote API (REST for list)
// ===================================================
//
class RemoteApi {
  static const base = "http://localhost:8080"; // Node.js backend
  static final Dio _dio = Dio(
    BaseOptions(baseUrl: base, headers: {"Content-Type": "application/json"}),
  );

  /// Fetch all documents
  static Future<List<DocumentItem>> getDocuments() async {
    final response = await _dio.get("/documents");
    final list = response.data as List<dynamic>;
    return list.map<DocumentItem>((e) => DocumentItem.fromJson(e)).toList();
  }

  /// Create a new document
  static Future<void> createDocument(String name) async {
    await _dio.post("/documents", data: {"name": name});
  }

  /// Delete a document by ID
  static Future<void> deleteDocument(String id) async {
    await _dio.delete("/documents/$id");
  }
}

//
// ===================================================
// Providers
// ===================================================
//

@riverpod
class Documents extends _$Documents {
  @override
  Future<List<DocumentItem>> build() async {
    return RemoteApi.getDocuments(); // Load from backend
  }

  Future<void> addDocument(String name) async {
    await RemoteApi.createDocument(name);
    ref.invalidateSelf(); // reload list
  }

  Future<void> deleteDocument(String id) async {
    await RemoteApi.deleteDocument(id);
    ref.invalidateSelf();
  }
}

//
// ===================================================
// Editor Sync Wrapper (REAL-TIME Collaboration)
// ===================================================
//
@riverpod
class EditorStateWrapper extends _$EditorStateWrapper {
  late final RemoteSyncService remote;

  @override
  FutureOr<EditorState> build(String docId) async {
    remote = RemoteSyncService(docId);

    final wrapper = EditorStateSyncWrapper(
      updatesBatcherDebounceDuration: const Duration(milliseconds: 400),
      syncAttributes: SyncAttributes(
        getInitialUpdates: () => remote.getInitialUpdates(),
        getUpdatesStream: remote.remoteUpdatesStream,
        saveUpdate: (Uint8List update) => remote.sendUpdate(update),
      ),
    );

    ref.onDispose(() {
      remote.dispose();
      wrapper.dispose();
    });

    return wrapper.initAndHandleChanges();
  }
}

//
// ===================================================
// Main App
// ===================================================
//
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppflowyEditorSyncUtilityFunctions.initAppFlowyEditorSync();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collaborative Editor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DocumentListView(),
    );
  }
}

//
// ===================================================
// Document List View
// ===================================================
//
class DocumentListView extends ConsumerWidget {
  const DocumentListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(ref),
        child: const Icon(Icons.add),
      ),
      body: docsAsync.when(
        data: (documents) {
          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, i) {
              final doc = documents[i];
              return ListTile(
                title: Text(doc.name),
                subtitle: Text(doc.createdAt.toString()),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentEditorScreen(docId: doc.id),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed:
                      () => ref
                          .read(documentsProvider.notifier)
                          .deleteDocument(doc.id),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text("Error: $err")),
      ),
    );
  }

  void _showCreateDialog(WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: ref.context,
      builder:
          (_) => AlertDialog(
            title: const Text('New Document'),
            content: TextField(controller: controller),
            actions: [
              TextButton(
                onPressed: Navigator.of(ref.context).pop,
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(documentsProvider.notifier)
                      .addDocument(controller.text);
                  Navigator.pop(ref.context);
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }
}

//
// ===================================================
// Editor Screen
// ===================================================
//
class DocumentEditorScreen extends ConsumerWidget {
  final String docId;

  const DocumentEditorScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorStateAsync = ref.watch(editorStateWrapperProvider(docId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Editing $docId'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: editorStateAsync.when(
        data: (editorState) {
          if (UniversalPlatform.isDesktopOrWeb) {
            return DesktopEditor(editorState: editorState);
          }
          return MobileEditor(editorState: editorState);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    );
  }
}
