import Flutter
import UIKit
import AVFoundation
import PushKit
import TwilioVoice
import CallKit
import UserNotifications

/// Entry point for the `flutter_twilio` iOS plugin.
///
/// Implements the Pigeon-generated [VoiceHostApi] and delegates each typed
/// method to a single-purpose handler. All errors are translated via
/// [FlutterTwilioError] so Dart observers receive the stable codes documented
/// in the spec.
///
/// Asynchronous call-lifecycle events are pushed back to Dart via the
/// [VoiceFlutterApi] installed on the [TVEventEmitter] — never via a
/// [FlutterEventChannel].
///
/// ### Note on `@objc(FlutterTwilioPlugin)`
///
/// Swift normally mangles Objective-C class names with the module prefix
/// (`flutter_twilio.FlutterTwilioPlugin`). The explicit `@objc` annotation
/// pins the runtime name so Flutter's generated `GeneratedPluginRegistrant.m`
/// — which selects plugins by plain Objective-C class name — can resolve us
/// unambiguously, and so that a consumer app with a lingering `twilio_voice`
/// dependency in its tree cannot collide with our registration key (a
/// failure mode the upstream plugin hit as `Duplicate plugin key`).
@objc(FlutterTwilioPlugin)
public class FlutterTwilioPlugin: NSObject, FlutterPlugin, VoiceHostApi {

    // MARK: - Shared state

    let state = TVPluginState()
    let emitter = TVEventEmitter()
    let audioDevice: DefaultAudioDevice = DefaultAudioDevice()

    // MARK: - CallKit / PushKit infrastructure

    let callObserver = CXCallObserver()
    let callKitProvider: CXProvider
    let callKitCallController: CXCallController
    let voipRegistry: PKPushRegistry

    // MARK: - Handlers

    let audioHandler: TVAudioHandler
    let permissionHandler: TVPermissionHandler
    let callHandler: TVCallHandler
    let registrationHandler: TVRegistrationHandler

    // MARK: - Pigeon Flutter API

    private var flutterApi: VoiceFlutterApi?

    static var appName: String {
        (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "FlutterTwilio"
    }

    public override init() {
        // PushKit + CallKit configuration.
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        let configuration = CXProviderConfiguration(localizedName: FlutterTwilioPlugin.appName)
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.includesCallsInRecents = true
        callKitProvider = CXProvider(configuration: configuration)
        callKitCallController = CXCallController()

        // Build handlers — plain Swift, no MethodChannel plumbing.
        audioHandler = TVAudioHandler(state: state, emitter: emitter, audioDevice: audioDevice)
        permissionHandler = TVPermissionHandler()
        callHandler = TVCallHandler(
            state: state,
            emitter: emitter,
            audioHandler: audioHandler,
            permissionHandler: permissionHandler,
            callController: callKitCallController,
            callKitProvider: callKitProvider
        )
        registrationHandler = TVRegistrationHandler(state: state, emitter: emitter)

        super.init()

        callObserver.setDelegate(self, queue: DispatchQueue.main)
        callKitProvider.setDelegate(self, queue: nil)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
        UNUserNotificationCenter.current().delegate = self

        // The TwilioVoice `Call.Delegate` + `NotificationDelegate` conformances
        // live on the plugin; the call handler grabs us via `delegateOwner` so
        // `ConnectOptions` can point at the same instance.
        callHandler.delegateOwner = self

        // Active-call snapshot provider for incoming events.
        emitter.activeCallProvider = { [weak self] in
            self?.callHandler.getActiveCall()
        }
    }

    deinit {
        callKitProvider.invalidate()
    }

    /// Single-instance guard. Flutter's plugin registrar should only call this
    /// once per engine attach, but hot-restart + embedded-engine scenarios can
    /// trigger a second call; re-entering `VoiceHostApiSetup.setUp` with a
    /// fresh instance would orphan the previous Pigeon handler and leak the
    /// old `CXProvider`. Guard by discarding repeat calls.
    private static var registered = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        guard !registered else {
            NSLog("[flutter_twilio] register(with:) called twice; ignoring the second attach.")
            return
        }
        registered = true

        let instance = FlutterTwilioPlugin()
        VoiceHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        instance.flutterApi = VoiceFlutterApi(binaryMessenger: registrar.messenger())
        if let api = instance.flutterApi { instance.emitter.attach(api: api) }
        registrar.addApplicationDelegate(instance)
    }

    // MARK: - VoiceHostApi

    func setAccessToken(token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.registrationHandler.setAccessToken(token) }
    }

    func register(completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.registrationHandler.register() }
    }

    func unregister(completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.registrationHandler.unregister() }
    }

    func place(request: PlaceCallRequest, completion: @escaping (Result<ActiveCallDto, Error>) -> Void) {
        let extra: [String: String] = request.extraParameters?.reduce(
            into: [String: String]()
        ) { acc, pair in
            if let k = pair.key, let v = pair.value { acc[k] = v }
        } ?? [:]
        // place() is async — the continuation is resolved from
        // `callDidStartRinging` (success) / `callDidFailToConnect` (failure).
        Task { [callHandler] in
            do {
                let dto = try await callHandler.place(
                    to: request.to,
                    from: request.from,
                    extra: extra
                )
                completion(.success(dto))
            } catch let pe as PigeonError {
                completion(.failure(pe))
            } catch {
                let ns = error as NSError
                if ns.domain == "com.twilio.voice" || ns.domain.contains("Twilio") {
                    completion(.failure(FlutterTwilioError.fromTwilio(error)))
                } else {
                    completion(.failure(FlutterTwilioError.unknown(error)))
                }
            }
        }
    }

    func answer(completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.callHandler.answer() }
    }

    func reject(completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.callHandler.reject() }
    }

    func hangUp(completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.callHandler.hangUp() }
    }

    func setMuted(muted: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.callHandler.setMuted(muted) }
    }

    func setOnHold(onHold: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.callHandler.setOnHold(onHold) }
    }

    func setSpeaker(onSpeaker: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.audioHandler.setSpeaker(onSpeaker) }
    }

    func sendDigits(digits: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guardCall(completion) { try self.callHandler.sendDigits(digits) }
    }

    func getActiveCall(completion: @escaping (Result<ActiveCallDto?, Error>) -> Void) {
        guardCall(completion) { self.callHandler.getActiveCall() }
    }

    func hasMicPermission(completion: @escaping (Result<Bool, Error>) -> Void) {
        guardCall(completion) { self.permissionHandler.hasMicPermission() }
    }

    func requestMicPermission(completion: @escaping (Result<Bool, Error>) -> Void) {
        permissionHandler.requestMicPermission { granted in
            completion(.success(granted))
        }
    }

    // MARK: - Helpers

    private func guardCall<T>(
        _ completion: @escaping (Result<T, Error>) -> Void,
        _ body: () throws -> T
    ) {
        do {
            completion(.success(try body()))
        } catch let pe as PigeonError {
            completion(.failure(pe))
        } catch {
            let ns = error as NSError
            if ns.domain == "com.twilio.voice" || ns.domain.contains("Twilio") {
                completion(.failure(FlutterTwilioError.fromTwilio(error)))
            } else {
                completion(.failure(FlutterTwilioError.unknown(error)))
            }
        }
    }
}

// MARK: - UIWindow convenience (used by notification presentation code paths)
extension UIWindow {
    func topMostViewController() -> UIViewController? {
        return topViewController(for: rootViewController)
    }

    func topViewController(for rootViewController: UIViewController?) -> UIViewController? {
        guard let rootViewController = rootViewController else { return nil }
        guard let presentedViewController = rootViewController.presentedViewController else { return rootViewController }
        switch presentedViewController {
        case is UINavigationController:
            let nav = presentedViewController as! UINavigationController
            return topViewController(for: nav.viewControllers.last)
        case is UITabBarController:
            let tab = presentedViewController as! UITabBarController
            return topViewController(for: tab.selectedViewController)
        default:
            return topViewController(for: presentedViewController)
        }
    }
}
