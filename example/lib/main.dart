import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_twilio/flutter_twilio.dart';

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
  StreamSubscription<Call>? _sub;

  bool _initialized = false;
  bool _registered = false;
  ActiveCall? _active;
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
    super.dispose();
  }

  void _log(String line) {
    setState(() {
      _logs.insert(
        0,
        '${DateTime.now().toIso8601String().substring(11, 19)}  $line',
      );
      if (_logs.length > 200) _logs.removeRange(200, _logs.length);
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _initialize() async {
    try {
      FlutterTwilio.instance.init(
        accountSid: _accountSid.text.trim(),
        authToken: _authToken.text.trim(),
        twilioNumber: _twilioNumber.text.trim().isEmpty
            ? null
            : _twilioNumber.text.trim(),
      );

      _sub?.cancel();
      _sub = FlutterTwilio.instance.voice.events.listen(
        _onCallEvent,
        onError: _onVoiceError,
      );

      setState(() => _initialized = true);
      _log('init() OK');
    } catch (e) {
      _log('init() failed: $e');
    }
  }

  Future<void> _registerVoice() async {
    try {
      await FlutterTwilio.instance.voice
          .setAccessToken(_voiceAccessToken.text.trim());
      await FlutterTwilio.instance.voice.register();
      setState(() => _registered = true);
      _log('voice.register() OK');
    } on VoiceException catch (e) {
      _log('voice.register() VoiceException: ${e.code} — ${e.message}');
    } catch (e) {
      _log('voice.register() failed: $e');
    }
  }

  Future<void> _placeCall() async {
    try {
      final call = await FlutterTwilio.instance.voice.place(
        to: _toNumber.text.trim(),
        from: _twilioNumber.text.trim().isEmpty
            ? null
            : _twilioNumber.text.trim(),
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

  Future<void> _hangUp() async {
    try {
      await FlutterTwilio.instance.voice.hangUp();
      _log('voice.hangUp() OK');
    } on VoiceException catch (e) {
      _log('voice.hangUp() VoiceException: ${e.code} — ${e.message}');
    }
  }

  Future<void> _toggleMute() async {
    try {
      final next = !_isMuted;
      await FlutterTwilio.instance.voice.setMuted(next);
      setState(() => _isMuted = next);
      _log('voice.setMuted($next) OK');
    } on VoiceException catch (e) {
      _log('voice.setMuted VoiceException: ${e.code} — ${e.message}');
    }
  }

  Future<void> _toggleSpeaker() async {
    try {
      final next = !_isSpeaker;
      await FlutterTwilio.instance.voice.setSpeaker(next);
      setState(() => _isSpeaker = next);
      _log('voice.setSpeaker($next) OK');
    } on VoiceException catch (e) {
      _log('voice.setSpeaker VoiceException: ${e.code} — ${e.message}');
    }
  }

  Future<void> _toggleHold() async {
    try {
      final next = !_isOnHold;
      await FlutterTwilio.instance.voice.setOnHold(next);
      setState(() => _isOnHold = next);
      _log('voice.setOnHold($next) OK');
    } on VoiceException catch (e) {
      _log('voice.setOnHold VoiceException: ${e.code} — ${e.message}');
    }
  }

  Future<void> _sendSms() async {
    if (!_initialized) {
      _snack('Initialize first.');
      return;
    }

    final body = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
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
        );
      },
    );

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

  void _onCallEvent(Call call) {
    final active = call.active;
    _log(
      'event=${call.event.name}'
      '${active != null ? ' sid=${active.sid}' : ''}',
    );

    setState(() {
      _active = active;
      if (active != null) {
        _isMuted = active.isMuted;
        _isSpeaker = active.isOnSpeaker;
        _isOnHold = active.isOnHold;
      }
      if (call.event == CallEvent.callEnded ||
          call.event == CallEvent.disconnected) {
        _active = null;
        _isMuted = false;
        _isSpeaker = false;
        _isOnHold = false;
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

  bool get _canAct => _initialized && _active != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_twilio demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(_accountSid, 'Account SID'),
                    _field(_authToken, 'Auth Token', obscure: true),
                    _field(_twilioNumber, 'Twilio Number (From)'),
                    _field(
                      _voiceAccessToken,
                      'Voice Access Token',
                      obscure: true,
                    ),
                    _field(_toNumber, 'To Number'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _initialize,
                          child: const Text('Initialize'),
                        ),
                        FilledButton(
                          onPressed: _initialized ? _registerVoice : null,
                          child: const Text('Register Voice'),
                        ),
                        FilledButton(
                          onPressed: _registered ? _placeCall : null,
                          child: const Text('Place Call'),
                        ),
                        FilledButton.tonal(
                          onPressed: _canAct ? _hangUp : null,
                          child: const Text('Hang Up'),
                        ),
                        FilledButton.tonal(
                          onPressed: _canAct ? _toggleMute : null,
                          child: Text(_isMuted ? 'Unmute' : 'Mute'),
                        ),
                        FilledButton.tonal(
                          onPressed: _canAct ? _toggleSpeaker : null,
                          child: Text(
                            _isSpeaker ? 'Speaker off' : 'Speaker on',
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: _canAct ? _toggleHold : null,
                          child: Text(_isOnHold ? 'Resume' : 'Hold'),
                        ),
                        OutlinedButton(
                          onPressed: _initialized ? _sendSms : null,
                          child: const Text('Send SMS'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_active != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Active call: ${_active!.sid}'),
                              Text('from=${_active!.from}  to=${_active!.to}'),
                              Text('direction=${_active!.direction.name}'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Log', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(
              height: 180,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView.builder(
                  reverse: false,
                  itemCount: _logs.length,
                  itemBuilder: (_, i) => Text(
                    _logs[i],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
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
