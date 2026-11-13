import 'app_feedback.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_bootstrap.dart';
import 'database_service.dart';
import 'realtime.dart';
import 'supabase_config.dart';

class SupabaseRealtime with WidgetsBindingObserver {
  static final SupabaseRealtime instance = SupabaseRealtime._();
  SupabaseRealtime._();

  RealtimeChannel? _channel;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  bool _isConnected = false;

  String? get _me => kAuthEnabled ? Supabase.instance.client.auth.currentUser?.id : null;

  void initLifecycle() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isConnected) {
      _connect();
    }
  }

  static void start() {
    instance._connect();
  }

  void _connect() {
    final me = _me;
    if (me == null || _isConnected) return;

    _channel?.unsubscribe();
    _channel = Supabase.instance.client.channel('swifly-live-$me');

    _channel!
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'posts',
        callback: (p) => _onPostUpdate(p.newRecord),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        callback: (p) => _onNotification(p.newRecord),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(column: 'recipient', value: me, type: PostgresChangeFilterType.eq),
        callback: (p) => _onMessage(p.newRecord),
      )
      .onBroadcast(
        event: 'chat_typing',
        callback: (payload) {
          final handle = payload['handle'] as String?;
          final isTyping = payload['isTyping'] as bool? ?? false;
          if (handle != null && handle != '@$me') {
            Realtime.instance.publish(ChatTypingEvent(handle: handle, isTyping: isTyping));
          }
        },
      );

    _channel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isConnected = true;
        _retryCount = 0;
        _reconnectTimer?.cancel();
      } else if (status == RealtimeSubscribeStatus.closed || status == RealtimeSubscribeStatus.channelError) {
        _isConnected = false;
        _scheduleReconnect();
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 << _retryCount).clamp(2, 60));
    _retryCount++;
    _reconnectTimer = Timer(delay, _connect);
  }

  static void sendTyping(String handle, bool isTyping) {
    final channel = instance._channel;
    if (channel != null && instance._isConnected) {
      channel.sendBroadcastMessage(
        event: 'chat_typing',
        payload: {'handle': handle, 'isTyping': isTyping},
      );
    }
  }

  static Future<void> stop() async {
    instance._reconnectTimer?.cancel();
    instance._isConnected = false;
    await instance._channel?.unsubscribe();
    instance._channel = null;
  }

  void _onPostUpdate(Map<String, dynamic> r) {
    Realtime.instance.publish(PostChangedEvent(
      postId: '${r['id']}', likes: r['likes'] ?? 0, saves: r['saves'] ?? 0, shares: r['shares'] ?? 0,
    ));
  }

  void _onNotification(Map<String, dynamic> r) {
    if ('${r['user_id']}' == _me) {
      Realtime.instance.publish(NotificationAddedEvent(r));
    }
  }

  void _onMessage(Map<String, dynamic> r) {
    if ('${r['sender']}' != _me) {
      Realtime.instance.publish(MessageReceivedEvent(r));
    }
  }
}
