import XCTest
@testable import twilio_voice_sms

private final class FakeTone: TVTonePlayer {
    var startCount = 0
    var stopCount = 0
    override func play(flutterAssetKey: String?, bundledResource: String, looping: Bool) {
        startCount += 1
    }
    override func stop() {
        stopCount += 1
    }
}

final class TVRingbackControllerTests: XCTestCase {

    func testOutgoingConnectingStartsAndConnectedStops() {
        let tone = FakeTone()
        let ctrl = TVRingbackController(player: tone, enabled: true, customAssetKey: nil)
        ctrl.onCallEvent(.outgoingConnecting)
        ctrl.onCallEvent(.connected)
        XCTAssertEqual(tone.startCount, 1)
        XCTAssertEqual(tone.stopCount, 1)
    }

    func testOutgoingDisconnectMidRingStops() {
        let tone = FakeTone()
        let ctrl = TVRingbackController(player: tone, enabled: true, customAssetKey: nil)
        ctrl.onCallEvent(.outgoingConnecting)
        ctrl.onCallEvent(.disconnected)
        XCTAssertEqual(tone.startCount, 1)
        XCTAssertEqual(tone.stopCount, 1)
    }

    func testIncomingNeverStarts() {
        let tone = FakeTone()
        let ctrl = TVRingbackController(player: tone, enabled: true, customAssetKey: nil)
        ctrl.onCallEvent(.incomingRinging)
        ctrl.onCallEvent(.connected)
        XCTAssertEqual(tone.startCount, 0)
    }

    func testDisabledNeverStarts() {
        let tone = FakeTone()
        let ctrl = TVRingbackController(player: tone, enabled: false, customAssetKey: nil)
        ctrl.onCallEvent(.outgoingConnecting)
        XCTAssertEqual(tone.startCount, 0)
    }
}
