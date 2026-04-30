import AVFoundation
import XCTest
@testable import twilio_voice_sms

final class TVAudioRouteMapperTests: XCTestCase {

    func testEarpieceMapping() {
        XCTAssertEqual(TVAudioRouteMapper.fromPort(.builtInReceiver), .earpiece)
    }

    func testSpeakerMapping() {
        XCTAssertEqual(TVAudioRouteMapper.fromPort(.builtInSpeaker), .speaker)
    }

    func testBluetoothMapping() {
        XCTAssertEqual(TVAudioRouteMapper.fromPort(.bluetoothHFP), .bluetooth)
        XCTAssertEqual(TVAudioRouteMapper.fromPort(.bluetoothA2DP), .bluetooth)
        XCTAssertEqual(TVAudioRouteMapper.fromPort(.bluetoothLE), .bluetooth)
    }

    func testWiredMapping() {
        for p: AVAudioSession.Port in [.headphones, .usbAudio, .lineOut, .HDMI, .airPlay] {
            XCTAssertEqual(TVAudioRouteMapper.fromPort(p), .wired, "port=\(p.rawValue)")
        }
    }

    func testUnknownDefaultsToEarpiece() {
        XCTAssertEqual(TVAudioRouteMapper.fromPort(.virtual), .earpiece)
    }
}
