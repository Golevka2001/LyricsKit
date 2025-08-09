import AppKit

public final class SpotifyLoginWindowController: NSWindowController {
    public init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadWindow() {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Spotify Login"
        window.setContentSize(NSSize(width: 800, height: 600))
        self.window = window
    }

    lazy var loginViewController = SpotifyLoginViewController()

    public override var windowNibName: NSNib.Name? { "" }

    public override func windowDidLoad() {
        contentViewController = loginViewController
        window?.center()
    }
}
