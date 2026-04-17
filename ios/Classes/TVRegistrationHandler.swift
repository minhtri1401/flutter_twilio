import Foundation
import PushKit
import TwilioVoice

/// Plain Swift handler for Twilio registration bookkeeping.
///
/// Registration / unregistration results are surfaced through the emitter as
/// typed call events (`registered`, `unregistered`, `registrationFailed`).
/// The PKPushRegistry delegate lives on the plugin itself — it calls
/// `storeDeviceToken(...)` here after PushKit assigns the token.
final class TVRegistrationHandler {
    private let tag = "TVRegistrationHandler"
    private let kRegistrationTTLInDays = 365
    private let kCachedDeviceToken = "CachedDeviceToken"
    private let kCachedBindingDate = "CachedBindingDate"

    private let state: TVPluginState
    private let emitter: TVEventEmitter

    init(state: TVPluginState, emitter: TVEventEmitter) {
        self.state = state
        self.emitter = emitter
    }

    var deviceToken: Data? {
        get { UserDefaults.standard.data(forKey: kCachedDeviceToken) }
        set { UserDefaults.standard.setValue(newValue, forKey: kCachedDeviceToken) }
    }

    // MARK: - VoiceHostApi entry points

    /// Stores the access token for later [register] / outgoing call
    /// placement. If PushKit already supplied a device token, attempts to
    /// register with Twilio immediately so incoming pushes route correctly.
    func setAccessToken(_ token: String) throws {
        guard !token.isEmpty else {
            throw FlutterTwilioError.of("invalid_argument", "Access token must not be empty")
        }
        state.accessToken = token

        if let data = deviceToken {
            registerWithTwilio(accessToken: token, deviceToken: data)
        }
    }

    func register() throws {
        guard let token = state.accessToken else {
            throw FlutterTwilioError.of("not_initialized", "Access token not set")
        }
        guard let data = deviceToken else {
            // Without a PushKit token we can't hit Twilio yet; rely on the
            // PKPushRegistry callback to register once the token arrives.
            emitter.emitError(
                "registration_error",
                "PushKit device token not yet available; registration deferred"
            )
            return
        }
        registerWithTwilio(accessToken: token, deviceToken: data)
    }

    func unregister() throws {
        guard let token = state.accessToken else {
            throw FlutterTwilioError.of("not_initialized", "Access token not set")
        }
        guard let data = deviceToken else { return }
        TwilioVoiceSDK.unregister(accessToken: token, deviceToken: data) { [weak self] error in
            if let error = error {
                self?.emitter.emitError(
                    "registration_error",
                    error.localizedDescription,
                    ["nativeMessage": error.localizedDescription]
                )
            } else {
                self?.emitter.emit(.unregistered)
            }
        }
    }

    // MARK: - Internal helpers (called by PKPushRegistry delegate on plugin)

    /// PushKit signaled a new VoIP token. If we have an access token on hand,
    /// re-register with Twilio.
    func storeDeviceToken(_ token: Data) {
        guard registrationRequired() || deviceToken != token else { return }
        deviceToken = token
        UserDefaults.standard.set(Date(), forKey: kCachedBindingDate)
        if let access = state.accessToken {
            registerWithTwilio(accessToken: access, deviceToken: token)
        }
    }

    /// PushKit invalidated the token; wipe Twilio.
    func invalidateDeviceToken() {
        guard let token = state.accessToken, let data = deviceToken else { return }
        TwilioVoiceSDK.unregister(accessToken: token, deviceToken: data) { [weak self] error in
            if error == nil {
                self?.deviceToken = nil
                self?.emitter.emit(.unregistered)
            }
        }
    }

    private func registrationRequired() -> Bool {
        guard let lastBinding = UserDefaults.standard.object(forKey: kCachedBindingDate) as? Date else {
            return true
        }
        var components = DateComponents()
        components.setValue(kRegistrationTTLInDays / 2, for: .day)
        guard let expirationDate = Calendar.current.date(byAdding: components, to: lastBinding) else { return true }
        return expirationDate.compare(Date()) != .orderedDescending
    }

    private func registerWithTwilio(accessToken: String, deviceToken: Data) {
        TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: deviceToken) { [weak self] error in
            if let error = error {
                self?.emitter.emitError(
                    "registration_error",
                    error.localizedDescription,
                    ["nativeMessage": error.localizedDescription]
                )
                self?.emitter.emit(.registrationFailed)
            } else {
                UserDefaults.standard.set(Date(), forKey: self?.kCachedBindingDate ?? "CachedBindingDate")
                self?.emitter.emit(.registered)
            }
        }
    }
}
