import 'dart:async';

import 'package:flutter/material.dart';
import 'package:twilio_voice_sms/twilio_voice_sms.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_twilio demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DemoHome(),
    );
  }
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key});

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  final _accountSid = TextEditingController();
  final _authToken = TextEditingController();
  final _twilioNumber = TextEditingController();
  final _voiceAccessToken = TextEditingController();
  final _toNumber = TextEditingController();

  final _logs = <String>[];
  final _scrollController = ScrollController();
  StreamSubscription<Call>? _sub;

  bool _initialized = false;
  bool _registered = false;
  bool _micGranted = false;

  /// Non-null when a call is live (connected/in-progress).
  ActiveCall? _active;

  /// Non-null when an incoming call is ringing but not yet answered.
  ActiveCall? _incoming;

  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isOnHold = false;

  @override
  void dispose() {
    _sub?.cancel();
    _accountSid.dispose();
    _authToken.dispose();
    _twilioNumber.dispose();
    _voiceAccessToken.dispose();
    _toNumber.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _initialize() async {
    try {
      FlutterTwilio.instance.init(
        accountSid: _accountSid.text.trim(),
        authToken: _authToken.text.trim(),
        twilioNumber: _nullableTwilioNumber,
      );

      _sub?.cancel();
      _sub = FlutterTwilio.instance.voice.events.listen(
        _onCallEvent,
        onError: _onVoiceError,
      );

      setState(() => _initialized = true);
      _log('init() OK');

      // Kick off a permission check so the user sees it in the UI.
      _micGranted = await FlutterTwilio.instance.voice.hasMicPermission();
      if (mounted) setState(() {});
    } catch (e) {
      _log('init() failed: $e');
    }
  }

  Future<void> _requestMicPermission() async {
    try {
      final granted =
          await FlutterTwilio.instance.voice.requestMicPermission();
      setState(() => _micGranted = granted);
      _log('requestMicPermission → $granted');
    } on VoiceException catch (e) {
      _log('requestMicPermission VoiceException: ${e.code} — ${e.message}');
    }
  }

  Future<void> _registerVoice() async {
    final token = _voiceAccessToken.text.trim();
    if (token.isEmpty) {
      _snack('Provide a Voice Access Token first.');
      return;
    }
    try {
      await FlutterTwilio.instance.voice.setAccessToken(token);
      await FlutterTwilio.instance.voice.register();
      setState(() => _registered = true);
      _log('voice.register() OK');
    } on VoiceException catch (e) {
      _log('voice.register() VoiceException: ${e.code} — ${e.message}');
    } catch (e) {
      _log('voice.register() failed: $e');
    }
  }

  Future<void> _unregisterVoice() async {
    try {
      await FlutterTwilio.instance.voice.unregister();
      setState(() => _registered = false);
      _log('voice.unregister() OK');
    } on VoiceException catch (e) {
      _log('voice.unregister() VoiceException: ${e.code} — ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Outbound call
  // ---------------------------------------------------------------------------

  Future<void> _placeCall() async {
    if (_toNumber.text.trim().isEmpty) {
      _snack('Enter a "To" number first.');
      return;
    }
    if (!_micGranted) {
      _snack('Grant microphone access first.');
      return;
    }
    try {
      final call = await FlutterTwilio.instance.voice.place(
        to: _toNumber.text.trim(),
        from: _nullableTwilioNumber,
      );
      setState(() {
        _active = call;
        _isMuted = call.isMuted;
        _isSpeaker = call.isOnSpeaker;
        _isOnHold = call.isOnHold;
      });
      _log('voice.place() → sid=${call.sid}');
    } on VoiceException catch (e) {
      _log('voice.place() VoiceException: ${e.code} — ${e.message}');
    } catch (e) {
      _log('voice.place() failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound call
  // ---------------------------------------------------------------------------

  Future<void> _answer() async {
    try {
      await FlutterTwilio.instance.voice.answer();
      _log('voice.answer() OK');
    } on VoiceException catch (e) {
      _log('voice.answer() VoiceException: ${e.code} — ${e.message}');
    }
  }

  Future<void> _reject() async {
    try {
      await FlutterTwilio.instance.voice.reject();
      _log('voice.reject() OK');
    } on VoiceException catch (e) {
      _log('voice.reject() VoiceException: ${e.code} — ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // In-call controls
  // ---------------------------------------------------------------------------

  Future<void> _hangUp() async {
    try {
      await FlutterTwilio.instance.voice.hangUp();
      _log('voice.hangUp() OK');
    } on VoiceException catch (e) {
      _log('voice.hangUp() VoiceException: ${e.code} — ${e.message}');
    }
  }

  Future<void> _toggleMute() => _voiceAction(
        'setMuted',
        () async {
          final next = !_isMuted;
          await FlutterTwilio.instance.voice.setMuted(next);
          if (mounted) setState(() => _isMuted = next);
        },
      );

  Future<void> _toggleSpeaker() => _voiceAction(
        'setSpeaker',
        () async {
          final next = !_isSpeaker;
          await FlutterTwilio.instance.voice.setSpeaker(next);
          if (mounted) setState(() => _isSpeaker = next);
        },
      );

  Future<void> _toggleHold() => _voiceAction(
        'setOnHold',
        () async {
          final next = !_isOnHold;
          await FlutterTwilio.instance.voice.setOnHold(next);
          if (mounted) setState(() => _isOnHold = next);
        },
      );

  Future<void> _sendDigit(String digit) => _voiceAction(
        'sendDigits',
        () => FlutterTwilio.instance.voice.sendDigits(digit),
      );

  Future<void> _voiceAction(String label, Future<void> Function() fn) async {
    try {
      await fn();
      _log('voice.$label OK');
    } on VoiceException catch (e) {
      _log('voice.$label VoiceException: ${e.code} — ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // SMS
  // ---------------------------------------------------------------------------

  Future<void> _sendSms() async {
    if (!_initialized) {
      _snack('Initialize first.');
      return;
    }
    if (_toNumber.text.trim().isEmpty) {
      _snack('Enter a "To" number first.');
      return;
    }

    final body = await _promptForSmsBody();
    if (body == null || body.isEmpty) return;

    try {
      final msg = await FlutterTwilio.instance.sms.send(
        to: _toNumber.text.trim(),
        body: body,
      );
      _log('sms.send() sid=${msg.sid} status=${msg.status}');
      _snack('Sent SMS: ${msg.sid}');
    } on TwilioSmsException catch (e) {
      _log(
        'sms.send() TwilioSmsException status=${e.statusCode} '
        'code=${e.twilioCode} — ${e.message}',
      );
      _snack('SMS failed: ${e.message}');
    } catch (e) {
      _log('sms.send() failed: $e');
      _snack('SMS failed: $e');
    }
  }

  Future<String?> _promptForSmsBody() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('SMS body'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Hello from Twilio'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Send'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Event stream
  // ---------------------------------------------------------------------------

  void _onCallEvent(Call call) {
    final active = call.active;
    _log(
      'event=${call.event.name}'
      '${active != null ? ' sid=${active.sid}' : ''}',
    );

    setState(() {
      switch (call.event) {
        case CallEvent.incoming:
        case CallEvent.ringing:
          if (active != null && active.direction == CallDirection.incoming) {
            _incoming = active;
          }
          break;

        case CallEvent.connected:
        case CallEvent.reconnected:
          _active = active;
          _incoming = null;
          if (active != null) {
            _isMuted = active.isMuted;
            _isSpeaker = active.isOnSpeaker;
            _isOnHold = active.isOnHold;
          }
          break;

        case CallEvent.callEnded:
        case CallEvent.disconnected:
        case CallEvent.declined:
        case CallEvent.missedCall:
          _active = null;
          _incoming = null;
          _isMuted = false;
          _isSpeaker = false;
          _isOnHold = false;
          break;

        default:
          if (active != null) {
            _active = active;
            _isMuted = active.isMuted;
            _isSpeaker = active.isOnSpeaker;
            _isOnHold = active.isOnHold;
          }
      }
    });
  }

  void _onVoiceError(Object e, StackTrace st) {
    if (e is VoiceException) {
      _log('stream VoiceException: ${e.code} — ${e.message}');
    } else {
      _log('stream error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? get _nullableTwilioNumber {
    final t = _twilioNumber.text.trim();
    return t.isEmpty ? null : t;
  }

  bool get _canControlCall => _initialized && _active != null;
  bool get _hasIncoming => _initialized && _incoming != null && _active == null;

  void _log(String line) {
    setState(() {
      _logs.insert(
        0,
        '${DateTime.now().toIso8601String().substring(11, 19)}  $line',
      );
      if (_logs.length > 200) _logs.removeRange(200, _logs.length);
    });
  }

  void _clearLogs() => setState(_logs.clear);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_twilio demo'),
        actions: [
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_outline),
            onPressed: _logs.isEmpty ? null : _clearLogs,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusBar(
                      initialized: _initialized,
                      registered: _registered,
                      micGranted: _micGranted,
                      active: _active,
                      incoming: _incoming,
                    ),
                    const SizedBox(height: 12),
                    _field(_accountSid, 'Account SID'),
                    _field(_authToken, 'Auth Token', obscure: true),
                    _field(_twilioNumber, 'Twilio Number (From)'),
                    _field(
                      _voiceAccessToken,
                      'Voice Access Token (JWT from your server)',
                      obscure: true,
                    ),
                    _field(_toNumber, 'To Number'),
                    const SizedBox(height: 12),
                    _PrimaryActions(
                      initialized: _initialized,
                      registered: _registered,
                      micGranted: _micGranted,
                      canPlaceCall: _registered && _active == null,
                      onInitialize: _initialize,
                      onRequestMic: _initialized ? _requestMicPermission : null,
                      onRegister: _initialized ? _registerVoice : null,
                      onUnregister: _registered ? _unregisterVoice : null,
                      onPlaceCall: (_registered && _active == null)
                          ? _placeCall
                          : null,
                      onSendSms: _initialized ? _sendSms : null,
                    ),
                    if (_hasIncoming)
                      _IncomingCallCard(
                        incoming: _incoming!,
                        onAnswer: _answer,
                        onReject: _reject,
                      ),
                    if (_active != null)
                      _InCallControls(
                        active: _active!,
                        isMuted: _isMuted,
                        isSpeaker: _isSpeaker,
                        isOnHold: _isOnHold,
                        onHangUp: _canControlCall ? _hangUp : null,
                        onToggleMute: _canControlCall ? _toggleMute : null,
                        onToggleSpeaker:
                            _canControlCall ? _toggleSpeaker : null,
                        onToggleHold: _canControlCall ? _toggleHold : null,
                        onDtmf: _canControlCall ? _sendDigit : null,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Log', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 180, child: _LogPanel(lines: _logs)),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

// ===========================================================================
// Small stateless sub-widgets (kept in-file so the example stays single-file).
// ===========================================================================

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.initialized,
    required this.registered,
    required this.micGranted,
    required this.active,
    required this.incoming,
  });

  final bool initialized;
  final bool registered;
  final bool micGranted;
  final ActiveCall? active;
  final ActiveCall? incoming;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _chip('init', initialized),
        _chip('registered', registered),
        _chip('mic', micGranted),
        if (incoming != null) _chip('incoming: ${incoming!.from}', true),
        if (active != null) _chip('in-call: ${active!.sid}', true),
      ],
    );
  }

  Widget _chip(String label, bool ok) => Chip(
        avatar: Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: ok ? Colors.green : Colors.grey,
        ),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      );
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.initialized,
    required this.registered,
    required this.micGranted,
    required this.canPlaceCall,
    required this.onInitialize,
    required this.onRequestMic,
    required this.onRegister,
    required this.onUnregister,
    required this.onPlaceCall,
    required this.onSendSms,
  });

  final bool initialized;
  final bool registered;
  final bool micGranted;
  final bool canPlaceCall;
  final VoidCallback onInitialize;
  final VoidCallback? onRequestMic;
  final VoidCallback? onRegister;
  final VoidCallback? onUnregister;
  final VoidCallback? onPlaceCall;
  final VoidCallback? onSendSms;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(onPressed: onInitialize, child: const Text('Initialize')),
        FilledButton.tonal(
          onPressed: micGranted ? null : onRequestMic,
          child: Text(micGranted ? 'Mic granted' : 'Request Mic'),
        ),
        FilledButton(
          onPressed: registered ? null : onRegister,
          child: const Text('Register Voice'),
        ),
        OutlinedButton(
          onPressed: onUnregister,
          child: const Text('Unregister'),
        ),
        FilledButton(
          onPressed: canPlaceCall ? onPlaceCall : null,
          child: const Text('Place Call'),
        ),
        OutlinedButton(
          onPressed: onSendSms,
          child: const Text('Send SMS'),
        ),
      ],
    );
  }
}

class _IncomingCallCard extends StatelessWidget {
  const _IncomingCallCard({
    required this.incoming,
    required this.onAnswer,
    required this.onReject,
  });

  final ActiveCall incoming;
  final VoidCallback onAnswer;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incoming call',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('from: ${incoming.from}'),
            Text('to:   ${incoming.to}'),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onAnswer,
                  icon: const Icon(Icons.call),
                  label: const Text('Answer'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onReject,
                  icon: const Icon(Icons.call_end),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InCallControls extends StatelessWidget {
  const _InCallControls({
    required this.active,
    required this.isMuted,
    required this.isSpeaker,
    required this.isOnHold,
    required this.onHangUp,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onToggleHold,
    required this.onDtmf,
  });

  final ActiveCall active;
  final bool isMuted;
  final bool isSpeaker;
  final bool isOnHold;
  final VoidCallback? onHangUp;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onToggleHold;
  final void Function(String digit)? onDtmf;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active call', style: Theme.of(context).textTheme.titleMedium),
            Text('sid:       ${active.sid}'),
            Text('from:      ${active.from}'),
            Text('to:        ${active.to}'),
            Text('direction: ${active.direction.name}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: onToggleMute,
                  child: Text(isMuted ? 'Unmute' : 'Mute'),
                ),
                FilledButton.tonal(
                  onPressed: onToggleSpeaker,
                  child: Text(isSpeaker ? 'Speaker off' : 'Speaker on'),
                ),
                FilledButton.tonal(
                  onPressed: onToggleHold,
                  child: Text(isOnHold ? 'Resume' : 'Hold'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onHangUp,
                  icon: const Icon(Icons.call_end),
                  label: const Text('Hang up'),
                ),
              ],
            ),
            if (onDtmf != null) ...[
              const SizedBox(height: 8),
              const Text('DTMF'),
              const SizedBox(height: 4),
              _DtmfPad(onDigit: onDtmf!),
            ],
          ],
        ),
      ),
    );
  }
}

class _DtmfPad extends StatelessWidget {
  const _DtmfPad({required this.onDigit});

  final void Function(String digit) onDigit;

  static const _rows = <List<String>>[
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['*', '0', '#'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final d in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: OutlinedButton(
                        onPressed: () => onDigit(d),
                        child: Text(d),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (_, i) => Text(
          lines[i],
          style: const TextStyle(
            color: Colors.greenAccent,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
