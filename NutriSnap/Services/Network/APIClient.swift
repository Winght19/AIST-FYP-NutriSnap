import Foundation

// MARK: - API Errors

enum APIError: LocalizedError {
    case unauthenticated
    case invalidURL
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case serverError(String)   // carries the actual message from the server body

    var errorDescription: String? {
        switch self {
        case .unauthenticated: return "Session expired. Please sign in again."
        case .invalidURL: return "Invalid request URL."
        case .httpError(let code): return "Server returned an error (HTTP \(code))."
        case .decodingError(let e): return "Failed to parse server response: \(e.localizedDescription)"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}

// MARK: - APIClient

/// Single network gateway. Attaches JWT from Keychain, encodes/decodes with ISO 8601 dates.
/// All views and services use this — never URLSession directly.
final class APIClient {
    static let shared = APIClient()

    // Replace with your backend base URL before deploying.
    let functionsURL = "https://sqgwalooucvabofnjrcx.supabase.co/functions/v1"
    let restURL = "https://sqgwalooucvabofnjrcx.supabase.co/rest/v1"
    let supabaseAnonKey = "sb_publishable_ggAjJwrTalHfCM9w1-ZQKw_1ed6KuRg"

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase

        // Supabase Postgres returns two date formats:
        //   timestamptz → "2026-02-24T02:13:03.123456+00:00" (fractional seconds)
        //   date        → "1990-01-15"  (date-only)
        // Swift's built-in .iso8601 can't handle either of these.
        let isoWithFraction: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()
        let isoPlain: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()
        let dateOnly: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()

        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = isoWithFraction.date(from: string) { return date }
            if let date = isoPlain.date(from: string) { return date }
            if let date = dateOnly.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(string)"
            )
        }

        return d
    }()

    private init() {}

    // MARK: - Public Methods

    func get<T: Decodable>(_ endpoint: String, token: String?) async throws -> T {
        try await execute(endpoint: endpoint, method: "GET", bodyData: nil, token: token, isREST: false)
    }

    func post<T: Decodable, B: Encodable>(_ endpoint: String, body: B, token: String?) async throws -> T {
        let data = try encoder.encode(body)
        return try await execute(endpoint: endpoint, method: "POST", bodyData: data, token: token, isREST: false)
    }

    func put<T: Decodable, B: Encodable>(_ endpoint: String, body: B, token: String?) async throws -> T {
        let data = try encoder.encode(body)
        return try await execute(endpoint: endpoint, method: "PUT", bodyData: data, token: token, isREST: false)
    }

    // MARK: - REST Methods

    func restGet<T: Decodable>(_ endpoint: String, token: String? = nil) async throws -> T {
        try await execute(endpoint: endpoint, method: "GET", bodyData: nil, token: token, isREST: true)
    }

    /// Fetches data with an exact count via Supabase's `Prefer: count=exact` header.
    /// Returns the decoded response and the total count parsed from the `Content-Range` header.
    func restGetWithCount<T: Decodable>(_ endpoint: String, token: String? = nil) async throws -> (T, Int?) {
        let basePath = restURL
        guard let url = URL(string: basePath + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("count=exact", forHTTPHeaderField: "Prefer")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            if let body = try? JSONDecoder().decode([String: String].self, from: data),
               let message = body["error"] {
                throw APIError.serverError("HTTP \(http.statusCode): \(message)")
            }
            throw APIError.httpError(http.statusCode)
        }

        // Parse total count from Content-Range header (e.g. "0-29/542")
        var totalCount: Int? = nil
        if let rangeHeader = http.value(forHTTPHeaderField: "Content-Range"),
           let slashIndex = rangeHeader.lastIndex(of: "/") {
            let countStr = String(rangeHeader[rangeHeader.index(after: slashIndex)...])
            totalCount = Int(countStr)
        }

        do {
            let decoded = try decoder.decode(T.self, from: data)
            return (decoded, totalCount)
        } catch {
            if let raw = String(data: data, encoding: .utf8) {
                print("⚠️ DECODE FAILED for \(T.self)")
                print("⚠️ Raw JSON: \(raw.prefix(500))")
                print("⚠️ Error: \(error)")
            }
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Private Core

    private func execute<T: Decodable>(
        endpoint: String,
        method: String,
        bodyData: Data?,
        token: String?,
        isREST: Bool
    ) async throws -> T {
        let basePath = isREST ? restURL : functionsURL
        guard let url = URL(string: basePath + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Supabase requires the anon key in the apikey header for REST
        if isREST {
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        }

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if isREST {
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        if let bodyData {
            request.httpBody = bodyData
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }
            if http.statusCode == 401 {
                // Try to surface the real error message from the server body for debugging.
                if let body = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = body["error"] {
                    throw APIError.serverError(message)
                }
                throw APIError.unauthenticated
            }
            guard (200..<300).contains(http.statusCode) else {
                // Try to surface the real error message from the response body.
                if let body = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = body["error"] {
                    throw APIError.serverError("HTTP \(http.statusCode): \(message)")
                }
                throw APIError.httpError(http.statusCode)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                // Log the raw response and detailed error for debugging
                if let raw = String(data: data, encoding: .utf8) {
                    print("⚠️ DECODE FAILED for \(T.self)")
                    print("⚠️ Raw JSON: \(raw.prefix(500))")
                    print("⚠️ Error: \(error)")
                }
                throw APIError.decodingError(error)
            }
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.networkError(error)
        }
    }
}
