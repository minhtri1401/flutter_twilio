import AVFoundation
import TwilioVoice

// MARK: - Audio routing
extension FlutterTwilioPlugin {
    func isSpeakerOn() -> Bool {
        for output in AVAudioSession.sharedInstance().currentRoute.outputs {
            if output.portType == .builtInSpeaker { return true }
        }
        return false
    }

    func isBluetoothOn() -> Bool {
        return AVAudioSession.sharedInstance().currentRoute.inputs.contains {
            $0.portType == .bluetoothHFP
        }
    }

    func toggleAudioRoute(toSpeaker: Bool) {
        audioDevice.block = { [weak self] in
            DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
            do {
                if toSpeaker {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                } else {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                }
            } catch {
                self?.sendPhoneCallEvents(description: "LOG|\(error.localizedDescription)", isError: false)
            }
        }
        audioDevice.block()
    }

    func toggleBluetooth(on: Bool) -> Bool {
        let session = AVAudioSession.sharedInstance()
        if on {
            guard let bluetoothInput = session.availableInputs?.first(where: {
                $0.portType == .bluetoothHFP
            }) else {
                sendPhoneCallEvents(description: "LOG|No Bluetooth HFP input available", isError: false)
                return false
            }
            audioDevice.block = { [weak self] in
                DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
                do {
                    try AVAudioSession.sharedInstance().setPreferredInput(bluetoothInput)
                } catch {
                    self?.sendPhoneCallEvents(description: "LOG|\(error.localizedDescription)", isError: false)
                }
            }
        } else {
            audioDevice.block = { [weak self] in
                DefaultAudioDevice.DefaultAVAudioSessionConfigurationBlock()
                do {
                    try AVAudioSession.sharedInstance().setPreferredInput(nil)
                } catch {
                    self?.sendPhoneCallEvents(description: "LOG|\(error.localizedDescription)", isError: false)
                }
            }
        }
        audioDevice.block()
        return true
    }

    func updateEnableCallLogging(_ value: Bool) -> Bool {
        let configuration = callKitProvider.configuration
        configuration.includesCallsInRecents = value
        UserDefaults.standard.set(value, forKey: callLoggingEnabledKey)
        return true
    }

    func updateCallKitIcon(icon: String) -> Bool {
        guard let newIcon = UIImage(named: icon) else { return false }
        let configuration = callKitProvider.configuration
        configuration.iconTemplateImageData = newIcon.pngData()
        callKitProvider.configuration = configuration
        UserDefaults.standard.set(icon, forKey: defaultCallKitIcon)
        return true
    }
}

// MARK: - handle() audio routing helpers
extension FlutterTwilioPlugin {
    func handleToggleSpeaker(args: [String: AnyObject]) {
        guard let speakerIsOn = args["speakerIsOn"] as? Bool else { return }
        toggleAudioRoute(toSpeaker: speakerIsOn)
        sendEvent(speakerIsOn ? "Speaker On" : "Speaker Off")
    }

    func handleToggleBluetooth(args: [String: AnyObject]) {
        guard let bluetoothOn = args["bluetoothOn"] as? Bool else { return }
        let success = toggleBluetooth(on: bluetoothOn)
        if success {
            sendEvent(bluetoothOn ? "Bluetooth On" : "Bluetooth Off")
        }
    }
}
