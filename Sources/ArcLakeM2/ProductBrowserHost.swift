import AppKit
import ArcLakeBrowsing
import ArcLakeCore
import SwiftUI
import WebKit

struct ProductBrowserHost: NSViewRepresentable {
  let browser: BrowserCoordinator
  let tabID: TabID

  func makeNSView(context: Context) -> BrowserMountView {
    BrowserMountView()
  }

  func updateNSView(_ view: BrowserMountView, context: Context) {
    view.mount(browser.webView(for: tabID))
  }

  static func dismantleNSView(_ view: BrowserMountView, coordinator: ()) {
    view.mount(nil)
  }
}

final class BrowserMountView: NSView {
  private weak var mountedWebView: WKWebView?

  func mount(_ next: WKWebView?) {
    guard mountedWebView !== next else { return }
    mountedWebView?.removeFromSuperview()
    mountedWebView = next
    guard let next else { return }
    next.frame = bounds
    next.autoresizingMask = [.width, .height]
    addSubview(next)
  }
}
