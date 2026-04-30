import AVFoundation
import Foundation

final class TVAudioRouteObserver {

    private let onChanged: (AudioRoute) -> Void
    private var observer: NSObjectProtocol?

    init(onChanged: @escaping (AudioRoute) -> Void) {
        self.onChanged = onChanged
    }

    func start() {
        if observer != nil { return }
        observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.onChanged(TVAudioRouteMapper.currentRoute())
        }
    }

    func stop() {
        if let o = observer {
            NotificationCenter.default.removeObserver(o)
            observer = nil
        }
    }

    deinit { stop() }
}
