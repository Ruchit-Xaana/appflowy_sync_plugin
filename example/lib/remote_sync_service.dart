import 'dart:convert'; // for jsonEncode / jsonDecode
import 'dart:typed_data'; // for Uint8List

import 'package:appflowy_editor_sync_plugin/types/update_types.dart'; // for DbUpdate
import 'package:web_socket_channel/web_socket_channel.dart'; // for WebSocketChannel

class RemoteSyncService {
  final WebSocketChannel channel;
  // 1. New private broadcast stream member
  late final Stream<dynamic> _broadcastStream;

  RemoteSyncService(String docId)
    : channel = WebSocketChannel.connect(
        Uri.parse("ws://localhost:8080/sync/$docId"),
      ) {
    // 2. Initialize the broadcast stream upon construction
    _broadcastStream = channel.stream.asBroadcastStream();
  }

  /// Broadcast stream so multiple listeners are allowed
  Stream<List<DbUpdate>> get remoteUpdatesStream =>
  // 3. Use the broadcast stream here
  _broadcastStream
      .map((data) {
        final List<dynamic> decoded = jsonDecode(data);
        // Assuming DbUpdate and jsonDecode are correctly implemented elsewhere
        return decoded
            .map((u) => DbUpdate(update: Uint8List.fromList(List<int>.from(u))))
            .toList();
      })
      .where(
        (updates) => updates.isNotEmpty,
      ); // You might want to filter empty responses

  Future<List<DbUpdate>> getInitialUpdates() async {
    channel.sink.add(jsonEncode({"type": "initialRequest"}));

    // 4. Listen only to the broadcast stream here.
    // The initial request will trigger a single response, which we await.
    final response = await _broadcastStream.first;

    final List<dynamic> decoded = jsonDecode(response);
    // Assuming DbUpdate is correctly implemented
    return decoded
        .map((u) => DbUpdate(update: Uint8List.fromList(List<int>.from(u))))
        .toList();
  }

  Future<void> sendUpdate(Uint8List update) async {
    channel.sink.add(jsonEncode({"type": "update", "data": update.toList()}));
  }

  void dispose() => channel.sink.close();
}
