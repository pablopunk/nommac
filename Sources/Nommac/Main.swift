import AppKit

@main
enum Main {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty && !launchedFromTerminal() {
            NommacApp.main()
            return
        }
        exit(NommacCLI.run(arguments))
    }

    private static func launchedFromTerminal() -> Bool {
        isatty(STDIN_FILENO) != 0 || isatty(STDOUT_FILENO) != 0
    }
}
