//
//  APIEndpoint.swift
//  Yapt
//
//  API endpoint definition
//

import Foundation

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: Data?
    let queryItems: [URLQueryItem]?

    init(path: String, method: HTTPMethod, body: Data? = nil, queryItems: [URLQueryItem]? = nil) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
    }

    func url(baseURL: String = Constants.API.baseURL) -> URL? {
        guard var components = URLComponents(string: baseURL + path) else {
            return nil
        }

        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return components.url
    }
}

// MARK: - Convenience Initializers for JSON
extension APIEndpoint {
    init<T: Encodable>(path: String, method: HTTPMethod, bodyObject: T) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bodyObject)

        self.init(path: path, method: method, body: data, queryItems: nil)
    }
}
