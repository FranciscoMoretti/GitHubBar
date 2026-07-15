import Foundation

public struct CommandResult: Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public protocol CommandRunning: Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]
    ) async -> CommandResult
}

public actor ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String] = [:]
    ) async -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, supplied in supplied }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandResult(exitCode: -1, standardOutput: "", standardError: "Command could not be started")
        }

        let output = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let error = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return CommandResult(exitCode: process.terminationStatus, standardOutput: output, standardError: error)
    }
}
