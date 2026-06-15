import Foundation

enum WikipediaError: LocalizedError, Sendable {
    case invalidURL
    case httpStatus(Int)
    case decoding(String)
    case transport(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Could not build the request URL."
        case .httpStatus(let code):
            "Wikipedia returned HTTP \(code)."
        case .decoding(let message):
            "Could not parse Wikipedia's response: \(message)"
        case .transport(let message):
            "Network error: \(message)"
        case .empty:
            "Wikipedia returned no data."
        }
    }
}
