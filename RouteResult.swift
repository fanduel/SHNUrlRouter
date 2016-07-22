import Foundation

public enum RouteResult {
    case failed
    case succeeded
    case output(result: Any)
}
