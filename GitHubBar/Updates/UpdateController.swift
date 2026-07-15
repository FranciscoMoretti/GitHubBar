import Foundation
import Observation

enum UpdatePresentation: Equatable {
    case disabled(message: String)
    case ready
    case checking
    case failed(message: String)
}

@MainActor
protocol UpdateControlling: AnyObject {
    var presentation: UpdatePresentation { get }
    var canCheckForUpdates: Bool { get }
    var onStateChange: ((UpdatePresentation, Bool) -> Void)? { get set }
    func checkForUpdates()
}

@MainActor
final class DisabledUpdateController: UpdateControlling {
    let presentation: UpdatePresentation = .disabled(
        message: "Automatic updates are disabled in this validation build."
    )
    let canCheckForUpdates = false
    var onStateChange: ((UpdatePresentation, Bool) -> Void)?

    func checkForUpdates() {}
}

@MainActor
@Observable
final class UpdateModel {
    private(set) var presentation: UpdatePresentation
    private(set) var canCheckForUpdates: Bool
    @ObservationIgnored private let controller: any UpdateControlling

    init(controller: any UpdateControlling) {
        self.controller = controller
        presentation = controller.presentation
        canCheckForUpdates = controller.canCheckForUpdates
        controller.onStateChange = { [weak self] presentation, canCheckForUpdates in
            self?.presentation = presentation
            self?.canCheckForUpdates = canCheckForUpdates
        }
    }

    func checkForUpdates() {
        guard controller.canCheckForUpdates else { return }
        controller.checkForUpdates()
        presentation = controller.presentation
        canCheckForUpdates = controller.canCheckForUpdates
    }
}

@MainActor
enum UpdateControllerFactory {
    static func make() -> any UpdateControlling {
        #if GITHUBBAR_STABLE
        SparkleUpdateController()
        #else
        DisabledUpdateController()
        #endif
    }
}
