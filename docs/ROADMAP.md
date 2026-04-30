# Roadmap

## Major-release work (target 0.3.0 / 1.0.0)

### Live transcription hooks
- New `TranscriptApi` surface: `Stream<TranscriptSegment> transcripts`,
  `start()`/`stop()` controls.
- Pluggable backend via a `TranscriptionProvider` interface — bundled adapter
  for Twilio Voice Intelligence; consumer can plug Whisper / Deepgram /
  AssemblyAI.
- Native-side: stream raw PCM frames out of the Twilio SDK's audio device.
  Android via a custom `AudioDevice`; iOS via tapping `AVAudioEngine` on the
  Twilio audio session.
- Open questions: on-device vs cloud, redaction, opt-in UI, latency budget.

### Multi-party conference + transfer
- New methods: `addParticipant(to:)`, `removeParticipant(sid:)`,
  `transfer(to:, warm: bool)`, `Stream<List<Participant>> participants`.
- Server-side: requires consumer's TwiML app to support `<Conference>` +
  `<Dial>` callbacks. Not solvable purely in the SDK.
- Significant native work; both Twilio SDKs expose multi-party only via
  `Call.connect()` with conference TwiML, not as a direct multi-party API.
- Likely concurrent rewrite of `TVCallState` from "single active call" to a
  participant graph — almost certainly the headliner of 1.0.0.
