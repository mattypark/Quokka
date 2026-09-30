import SwiftUI
import UIKit

/// Everywhere a tap can push to.
///
/// Pushed rather than presented as sheets, the way Cosmos moves: an item, a playlist and a
/// creator are places you go into and back out of with a swipe, not cards laid over the grid.
/// Ids rather than models, so a pushed screen always reads the row as it is now.
enum Route: Hashable {
    case item(Int64)
    case playlist(Int64)
    case creator(String)
}

extension View {
    /// Registers every destination on a tab's stack. Each tab calls this once at its root.
    func quokkaRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .item(let id): ItemDetailView(itemID: id)
            case .playlist(let id): PlaylistDetailView(playlistID: id)
            case .creator(let name): CreatorView(author: name)
            }
        }
    }
}

/// How a page leaves Home's sky and comes back to it.
///
/// Set only on Home's stack, so everything pushed there -- and nothing pushed from the Library
/// or Studio -- goes through the root, which owns the liquid sky. Leaving Home's root drains
/// the sky into the page; landing back on it pours the sky over the page first. Anywhere
/// deeper it is an ordinary push or pop.
struct SkyPassage {
    let open: (Route) -> Void
    let back: () -> Void
}

extension EnvironmentValues {
    @Entry var skyPassage: SkyPassage? = nil
}

/// Keeps the edge swipe back working with the navigation bar hidden.
///
/// Every pushed screen draws its own grey back circle instead of the system bar, and hiding
/// the bar leaves the pop gesture without a delegate, so it silently stops. Handing it one
/// that allows the pop whenever there is somewhere to pop to restores it.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
