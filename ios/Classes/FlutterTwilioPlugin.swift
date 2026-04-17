import Flutter
import UIKit
import AVFoundation
import PushKit
import TwilioVoice
import CallKit
import UserNotifications

public class FlutterTwilioPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, AVAudioPlayerDelegate {
    let callObserver = CXCallObserver()

    final let defaultCallKitIcon = "callkit_icon"
    final let callLoggingEnabledKey = "TV_CALL_LOGGING_ENABLED"
    var callKitIcon: String?

    var _result: FlutterResult?
    private var eventSink: FlutterEventSink?

    let kRegistrationTTLInDays = 365
    let kCachedDeviceToken = "CachedDeviceToken"
    let kCachedBindingDate = "CachedBindingDate"
    let kClientList = "TwilioContactList"
    var clients: [String: String]!

    var accessToken: String?
    var identity = "alice"
    var callTo: String = "error"
    var defaultCaller = "Unknown Caller"
    var deviceToken: Data? {
        get { UserDefaults.standard.data(forKey: kCachedDeviceToken) }
        set { UserDefaults.standard.setValue(newValue, forKey: kCachedDeviceToken) }
    }
    var callArgs: Dictionary<String, AnyObject> = [String: AnyObject]()

    var voipRegistry: PKPushRegistry
    var incomingPushCompletionCallback: (() -> Void)? = nil

    var callInvite: CallInvite?
    var call: Call?
    var callKitCompletionCallback: ((Bool) -> Void)? = nil
    var audioDevice: DefaultAudioDevice = DefaultAudioDevice()

    var callKitProvider: CXProvider
    var callKitCallController: CXCallController
    var userInitiatedDisconnect: Bool = false
    var callOutgoing: Bool = false

    var activeCalls: [UUID: CXCall] = [:]

    static var appName: String {
        return (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Define CFBundleName"
    }

    public override init() {
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        let configuration = CXProviderConfiguration(localizedName: FlutterTwilioPlugin.appName)
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        let defaultIcon = UserDefaults.standard.string(forKey: defaultCallKitIcon) ?? defaultCallKitIcon
        let callLoggingEnabled = UserDefaults.standard.optionalBool(forKey: callLoggingEnabledKey) ?? true
        configuration.includesCallsInRecents = callLoggingEnabled
        clients = UserDefaults.standard.object(forKey: kClientList) as? [String: String] ?? [:]
        callKitProvider = CXProvider(configuration: configuration)
        callKitCallController = CXCallController()
        super.init()
        callObserver.setDelegate(self, queue: DispatchQueue.main)
        callKitProvider.setDelegate(self, queue: nil)
        _ = updateCallKitIcon(icon: defaultIcon)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
        UNUserNotificationCenter.current().delegate = self
        let appDelegate = UIApplication.shared.delegate
        guard let controller = appDelegate?.window??.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }
        let registrar = controller.registrar(forPlugin: "twilio_voice")
        if let unwrappedRegistrar = registrar {
            let eventChannel = FlutterEventChannel(name: "twilio_voice/events", binaryMessenger: unwrappedRegistrar.messenger())
            eventChannel.setStreamHandler(self)
        }
    }

    deinit {
        callKitProvider.invalidate()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterTwilioPlugin()
        let methodChannel = FlutterMethodChannel(name: "twilio_voice/messages", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "twilio_voice/events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ flutterCall: FlutterMethodCall, result: @escaping FlutterResult) {
        _result = result
        let args = flutterCall.arguments as? Dictionary<String, AnyObject> ?? [:]
        switch flutterCall.method {
        case "tokens":                     handleTokens(args: args, result: result)
        case "makeCall":                   handleMakeCall(args: args); result(true)
        case "connect":                    handleConnect(args: args); result(true)
        case "toggleMute":                 handleToggleMute(args: args, result: result)
        case "isMuted":                    result(call?.isMuted ?? false)
        case "toggleSpeaker":              handleToggleSpeaker(args: args); result(true)
        case "isOnSpeaker":                result(isSpeakerOn())
        case "toggleBluetooth":            handleToggleBluetooth(args: args); result(true)
        case "isBluetoothOn":              result(isBluetoothOn())
        case "call-sid":                   result(call?.sid)
        case "isOnCall":                   result(call != nil)
        case "sendDigits":                 handleSendDigits(args: args); result(true)
        case "holdCall":                   handleHoldCall(args: args); result(true)
        case "isHolding":                  handleToggleHold(args: args); result(true)
        case "answer":                     handleAnswer(result: result)
        case "unregister":                 handleUnregister(args: args); result(true)
        case "hangUp":                     handleHangUp(); result(true)
        case "registerClient":             handleRegisterClient(args: args); result(true)
        case "unregisterClient":           handleUnregisterClient(args: args); result(true)
        case "defaultCaller":              handleDefaultCaller(args: args); result(true)
        case "hasMicPermission":           result(AVAudioSession.sharedInstance().recordPermission == .granted)
        case "requestMicPermission":       requestMicPermission(result: result)
        case "hasBluetoothPermission":     result(true)
        case "requestBluetoothPermission": result(true)
        case "showNotifications":          handleShowNotifications(args: args, result: result)
        case "updateCallKitIcon":          result(updateCallKitIcon(icon: args["icon"] as? String ?? defaultCallKitIcon))
        case "enableCallLogging":          result(updateEnableCallLogging(args["enabled"] as? Bool ?? true))
        default:                           result(FlutterMethodNotImplemented)
        }
    }

    // MARK: FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func sendPhoneCallEvents(description: String, isError: Bool) {
        NSLog(description)
        if isError {
            sendEvent(FlutterError(code: "unavailable", message: description, details: nil))
        } else {
            sendEvent(description)
        }
    }

    func sendEvent(_ event: Any) {
        guard let eventSink = eventSink else { return }
        DispatchQueue.main.async { eventSink(event) }
    }
}

// MARK: - Extensions
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

extension UserDefaults {
    public func optionalBool(forKey defaultName: String) -> Bool? {
        return value(forKey: defaultName) as? Bool
    }
}
