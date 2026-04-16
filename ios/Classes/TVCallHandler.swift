import Flutter
import UIKit
import AVFoundation
import TwilioVoice
import CallKit

// MARK: - CallDelegate
extension SwiftTwilioVoicePlugin: CallDelegate {
    public func callDidStartRinging(call: Call) {
        let direction = callOutgoing ? "Outgoing" : "Incoming"
        let from = call.from ?? identity
        let to = call.to ?? callTo
        sendPhoneCallEvents(description: "Ringing|\(from)|\(to)|\(direction)", isError: false)
    }

    public func callDidConnect(call: Call) {
        let direction = callOutgoing ? "Outgoing" : "Incoming"
        let from = call.from ?? identity
        let to = call.to ?? callTo
        sendPhoneCallEvents(description: "Connected|\(from)|\(to)|\(direction)", isError: false)
        callKitCompletionCallback?(true)
        toggleAudioRoute(toSpeaker: false)
    }

    public func call(call: Call, isReconnectingWithError error: Error) {
        sendPhoneCallEvents(description: "Reconnecting", isError: false)
    }

    public func callDidReconnect(call: Call) {
        sendPhoneCallEvents(description: "Reconnected", isError: false)
    }

    public func callDidFailToConnect(call: Call, error: Error) {
        sendPhoneCallEvents(description: "LOG|Call failed to connect: \(error.localizedDescription)", isError: false)
        sendPhoneCallEvents(description: "Call Ended", isError: false)
        if error.localizedDescription.contains("Access Token expired") {
            if let deviceToken = deviceToken {
                sendPhoneCallEvents(description: "DEVICETOKEN|\(String(decoding: deviceToken, as: UTF8.self))", isError: false)
            }
        }
        callKitCompletionCallback?(false)
        callKitProvider.reportCall(with: call.uuid!, endedAt: Date(), reason: .failed)
        callDisconnected()
    }

    public func callDidDisconnect(call: Call, error: Error?) {
        sendPhoneCallEvents(description: "Call Ended", isError: false)
        if let error = error {
            sendPhoneCallEvents(description: "Call Failed: \(error.localizedDescription)", isError: true)
        }
        if !userInitiatedDisconnect {
            var reason = CXCallEndedReason.remoteEnded
            sendPhoneCallEvents(description: "LOG|User initiated disconnect", isError: false)
            if error != nil { reason = .failed }
            callKitProvider.reportCall(with: call.uuid!, endedAt: Date(), reason: reason)
        }
        callDisconnected()
    }
}

// MARK: - Call operation helpers
extension SwiftTwilioVoicePlugin {
    func callDisconnected() {
        sendPhoneCallEvents(description: "LOG|Call Disconnected", isError: false)
        if call != nil {
            sendPhoneCallEvents(description: "LOG|Setting call to nil", isError: false)
            call = nil
        }
        callInvite = nil
        callOutgoing = false
        userInitiatedDisconnect = false
    }

    func makeCall(to: String) {
        if let activeCall = call {
            userInitiatedDisconnect = true
            performEndCallAction(uuid: activeCall.uuid!)
        } else {
            let uuid = UUID()
            checkRecordPermission { permissionGranted in
                if !permissionGranted {
                    let alertController = UIAlertController(
                        title: String(format: NSLocalizedString("mic_permission_title", comment: ""), SwiftTwilioVoicePlugin.appName),
                        message: NSLocalizedString("mic_permission_subtitle", comment: ""),
                        preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("btn_continue_no_mic", comment: ""), style: .default) { _ in
                        self.performStartCallAction(uuid: uuid, handle: to)
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("btn_settings", comment: ""), style: .default) { _ in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [.universalLinksOnly: false], completionHandler: nil)
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("btn_cancel", comment: ""), style: .cancel))
                    guard let vc = UIApplication.shared.keyWindow?.topMostViewController() else { return }
                    vc.present(alertController, animated: true)
                } else {
                    self.performStartCallAction(uuid: uuid, handle: to)
                }
            }
        }
    }

    func answerCall(callInvite: CallInvite) {
        let answerCallAction = CXAnswerCallAction(call: callInvite.uuid)
        let transaction = CXTransaction(action: answerCallAction)
        callKitCallController.request(transaction) { error in
            if let error = error {
                self.sendPhoneCallEvents(description: "LOG|AnswerCallAction transaction request failed: \(error.localizedDescription)", isError: false)
            }
        }
    }
}

// MARK: - handle() method routing helpers
extension SwiftTwilioVoicePlugin {
    func handleMakeCall(args: [String: AnyObject]) {
        guard let callTo = args["To"] as? String, let callFrom = args["From"] as? String else { return }
        callArgs = args
        callOutgoing = true
        if let token = args["accessToken"] as? String { accessToken = token }
        self.callTo = callTo
        identity = callFrom
        makeCall(to: callTo)
    }

    func handleConnect(args: [String: AnyObject]) {
        callArgs = args
        callOutgoing = true
        if let token = args["accessToken"] as? String { accessToken = token }
        callTo = args["To"] as? String ?? ""
        identity = args["From"] as? String ?? ""
        makeCall(to: callTo)
    }

    func handleToggleMute(args: [String: AnyObject], result: FlutterResult) {
        guard let muted = args["muted"] as? Bool else { return }
        if let call = call {
            call.isMuted = muted
            sendEvent(muted ? "Mute" : "Unmute")
            result(true)
        } else {
            result(FlutterError(code: "MUTE_ERROR", message: "No call to be muted", details: nil))
        }
    }

    func handleSendDigits(args: [String: AnyObject]) {
        guard let digits = args["digits"] as? String else { return }
        call?.sendDigits(digits)
    }

    func handleHoldCall(args: [String: AnyObject]) {
        guard let shouldHold = args["shouldHold"] as? Bool, let call = call else { return }
        let hold = call.isOnHold
        if shouldHold && !hold {
            call.isOnHold = true
            sendEvent("Hold")
        } else if !shouldHold && hold {
            call.isOnHold = false
            sendEvent("Unhold")
        }
    }

    func handleToggleHold(args: [String: AnyObject]) {
        guard let call = call else { return }
        let isOnHold = call.isOnHold
        call.isOnHold = !isOnHold
        sendEvent(!isOnHold ? "Hold" : "Unhold")
    }

    func handleAnswer(result: FlutterResult) {
        if let ci = callInvite {
            sendPhoneCallEvents(description: "LOG|answer method invoked", isError: false)
            answerCall(callInvite: ci)
            result(true)
        } else {
            result(FlutterError(code: "ANSWER_ERROR", message: "No call invite to answer", details: nil))
        }
    }

    func handleHangUp() {
        if let call = call {
            sendPhoneCallEvents(description: "LOG|hangUp method invoked", isError: false)
            userInitiatedDisconnect = true
            performEndCallAction(uuid: call.uuid!)
        } else if let ci = callInvite {
            performEndCallAction(uuid: ci.uuid)
        }
    }
}
