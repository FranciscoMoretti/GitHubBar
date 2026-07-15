#if GITHUBBAR_STABLE
import Sparkle

@MainActor
final class SparkleUpdateController: NSObject, UpdateControlling, SPUUpdaterDelegate {
    private(set) var presentation: UpdatePresentation = .ready {
        didSet { publish() }
    }
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
    var onStateChange: ((UpdatePresentation, Bool) -> Void)?

    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    override init() {
        super.init()
        _ = updaterController
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        presentation = .checking
        updaterController.checkForUpdates(nil)
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        if let error {
            presentation = .failed(message: error.localizedDescription)
        } else {
            presentation = .ready
        }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        presentation = .failed(message: error.localizedDescription)
    }

    private func publish() {
        onStateChange?(presentation, canCheckForUpdates)
    }
}
#endif
