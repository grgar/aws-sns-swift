import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import AwsSign
import SWXMLHash

public class AWSSNS {
    private let host: String
    private let session: URLSession
    private let accessKeyID: String
    private let secretAccessKey: String

    private let defaultParams = ["Version": "2010-03-31"]

    /// Initializes a new AWSSNS client, using the specified host, session, and access credentials.
    ///
    /// - Parameters:
    ///   - host: The host for the SNS, e.g `https://sns.us-west-2.amazonaws.com/`
    ///   - session: Optional parameter, specifying a `URLSession` to be used for all SNS related requests. If not provided, `URLSession(configuration: .default)` will be used.
    ///   - accessKeyId: The access key for using the SNS.
    ///   - secretAccessKey: The secret access key for using the SNS.
    public init(host: String, session: URLSession = URLSession(configuration: .default), accessKeyID: String, secretAccessKey: String) {
        var normalizedHost = host
        if normalizedHost.hasSuffix("/") {
            normalizedHost = String(normalizedHost.dropLast(1))
        }

        self.host = host
        self.session = session
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
    }

    /// Method used for publishing `String` messages.
    ///
    /// - Parameters:
    ///   - message: The message in string format.
    ///   - subject: The subject to be published.
    ///   - targetARN: The target ARN.
    ///   - topicARN: The topic ARN.
    ///   - structure: String specifying message structure.
    ///   - completion: Completion handler, providing a `Bool` parameter specifying whether the publish operation was successful, and an optional `error` in case the operation failed.
    public func publish(message: String, subject: String? = nil, targetARN: String? = nil, topicARN: String? = nil, structure: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        var params = defaultParams
        params["Action"] = "Publish"
        params["Message"] = message
        params["Subject"] = subject
        params["TargetArn"] = targetARN
        params["TopicArn"] = topicARN
        params["MessageStructure"] = structure

        let request: URLRequest
        do {
            request = try self.request(with: params)
        } catch {
            completion(false, error)
            return
        }

        session.dataTask(with: request, completionHandler: { data, response, error in
            let error = self.checkForError(response: response, data: data, error: error)
            completion(error == nil, error)
        }).resume()
    }

    /// Method used for publishing messages in dictionary (JSON) format.
    ///
    /// - Parameters:
    ///   - message: The message in in dictionary (JSON) format.
    ///   - subject: The subject to be published.
    ///   - targetARN: The target ARN.
    ///   - topicARN: The topic ARN.
    ///   - completion: Completion handler, providing a `Bool` parameter specifying whether the publish operation was successful, and an optional `error` in case the operation failed.
    public func publish(message: [String: Any], subject: String = "", targetARN: String = "", topicARN: String = "", completion: @escaping (Bool, Error?) -> Void) {
        let messageData: Data
        do {
            messageData = try JSONSerialization.data(withJSONObject: message, options: [])
        } catch {
            completion(false, error)
            return
        }
        guard let jsonString = String(data: messageData, encoding: .utf8) else {
            completion(false, AWSSNSError.generalError(reason: "Initializing string from message data failed."))
            return
        }

        publish(message: jsonString, subject: subject, targetARN: targetARN, topicARN: topicARN, structure: "json", completion: completion)
    }

    /// Method used for creating platform endpoints.
    ///
    /// - Parameters:
    ///   - token: Unique identifier created by the notification service for an app on a device.
    ///   - platformApplicationARN: PlatformApplicationARN returned from CreatePlatformApplication is used to create a an endpoint.
    ///   - customUserData: Arbitrary user data to associate with the endpoint. Amazon SNS does not use this data. The data must be in UTF-8 format and less than 2KB.
    ///   - completion: Completion handler, providing a `Bool` parameter specifying whether the publish operation was successful, returned `endpointARN`, and an optional `error` in case the operation failed.
    public func createPlatformEndpoint(token: String, platformApplicationARN: String, customUserData: String? = nil, completion: @escaping (Bool, String?, Error?) -> Void) {
        var params = defaultParams
        params["Action"] = "CreatePlatformEndpoint"
        params["Token"] = token
        params["PlatformApplicationArn"] = platformApplicationARN
        if let customUserData = customUserData {
            params["CustomUserData"] = customUserData
        }

        let request: URLRequest
        do {
            request = try self.request(with: params)
        } catch {
            completion(false, nil, error)
            return
        }

        session.dataTask(with: request, completionHandler: { data, response, error in
            let error = self.checkForError(response: response, data: data, error: error)
            if error == nil, let data = data, let responseBody = String(data: data, encoding: .utf8) {
                let xml = SWXMLHash.parse(responseBody)
                let endpointARN = xml["CreatePlatformEndpointResponse"]["CreatePlatformEndpointResult"]["EndpointArn"].element?.text
                completion(true, endpointARN, nil)
            } else {
                completion(false, nil, error)
            }
        }).resume()
    }

    /// Method used for fetching the list of platform applications (up top 100 applications per call).
    ///
    /// - Parameters:
    ///   - nextToken: Used when calling `listPlatformApplications` method to retrieve additional records that are available after the first page results.
    ///   - completion: Completion handler, providing a `Bool` parameter specifying whether the fetching operation was successful, returned `PlatformApplications` instance, and an optional `error` in case the operation failed.
    public func listPlatformApplications(nextToken: String? = nil, completion: @escaping (Bool, PlatformApplications?, Error?) -> Void) {
        var params = defaultParams
        params["Action"] = "ListPlatformApplications"
        if let nextToken = nextToken {
            params["NextToken"] = nextToken
        }

        let request: URLRequest
        do {
            request = try self.request(with: params)
        } catch {
            completion(false, nil, error)
            return
        }

        session.dataTask(with: request, completionHandler: { data, response, error in
            let error = self.checkForError(response: response, data: data, error: error)
            if error == nil, let data = data, let responseBody = String(data: data, encoding: .utf8),
               let applicationsResponse = PlatformApplications(xml: SWXMLHash.parse(responseBody))
            {
                completion(true, applicationsResponse, nil)
            } else {
                completion(false, nil, error)
            }
        }).resume()
    }

    /// Method used for fetching the list of PlatformApplicationEnpoints for the platform application (up top 100 endpoints per call).
    ///
    /// - Parameters:
    ///   - platformApplicationARN: ARN for given platform application.
    ///   - nextToken: Used when calling `listEndpointsBy` method to retrieve additional records that are available after the first page results.
    ///   - completion: Completion handler, providing a `Bool` parameter specifying whether the fetching operation was successful, returned `PlatformApplicationEnpoints` instance, and an optional `error` in case the operation failed.
    public func listEndpoints(for platformApplicationARN: String, nextToken: String? = nil, completion: @escaping (Bool, PlatformApplicationEnpoints?, Error?) -> Void) {
        var params = defaultParams
        params["PlatformApplicationArn"] = platformApplicationARN
        params["Action"] = "ListEndpointsByPlatformApplication"
        if let nextToken = nextToken {
            params["NextToken"] = nextToken
        }

        let request: URLRequest
        do {
            request = try self.request(with: params)
        } catch {
            completion(false, nil, error)
            return
        }

        session.dataTask(with: request, completionHandler: { data, response, error in
            let error = self.checkForError(response: response, data: data, error: error)
            if error == nil, let data = data, let responseBody = String(data: data, encoding: .utf8),
               let endpointsResponse = PlatformApplicationEnpoints(xml: SWXMLHash.parse(responseBody))
            {
                completion(true, endpointsResponse, nil)
            } else {
                completion(false, nil, error)
            }
        }).resume()
    }

    /// Deletes the endpoint for a device and mobile app from the SNS.
    ///
    /// - Parameters:
    ///   - endpointARN: EndpointARN of endpoint to delete.
    ///   - completion: Completion handler, providing a `Bool` parameter specifying whether the publish operation was successful, and an optional `error` in case the operation failed.
    public func deleteEndpoint(endpointARN: String, completion: @escaping (Bool, Error?) -> Void) {
        var params = defaultParams
        params["Action"] = "DeleteEndpoint"
        params["EndpointArn"] = endpointARN

        let request: URLRequest
        do {
            request = try self.request(with: params)
        } catch {
            completion(false, error)
            return
        }

        session.dataTask(with: request, completionHandler: { data, response, error in
            let error = self.checkForError(response: response, data: data, error: error)
            completion(error == nil, error)
        }).resume()
    }

    /// Retrieves the endpoint attributes for a device on one of the supported push notification services.
    ///
    /// - Parameters:
    ///   - endpointARN: EndpointARN of endpoint.
    ///   - completion: Completion handler, providing a `Bool` parameter specifying whether the get attributes operation was successful, returned `EndpointAttributes` instance and an optional `error` in case the operation failed.
    public func getEndpointAttributes(endpointARN: String, completion: @escaping (Bool, EndpointAttributes?, Error?) -> Void) {
        var params = defaultParams
        params["Action"] = "GetEndpointAttributes"
        params["EndpointArn"] = endpointARN

        let request: URLRequest
        do {
            request = try self.request(with: params)
        } catch {
            completion(false, nil, error)
            return
        }

        session.dataTask(with: request) { data, response, error in
            let error = self.checkForError(response: response, data: data, error: error)
            if error == nil, let data = data, let responseBody = String(data: data, encoding: .utf8),
               let attributes = EndpointAttributes(xml: SWXMLHash.parse(responseBody))
            {
                completion(true, attributes, nil)
            } else {
                completion(false, nil, error)
            }
        }.resume()
    }

    /// Sets the endpoint attributes for a device on one of the supported push notification services.
    ///
    /// - Parameters:
    ///   - endpointARN: EndpointARN of endpoint.
    ///   - attributes: Attributes dictionary (suppoerted keys by AWS SNS service: `CustomUserData`, `Enabled` and `Token`).
    ///   - completion: Completion handler, providing a `Bool` parameter specifying whether the get attributes operation was successful and an optional `error` in case the operation failed.
    public func setEndpointAttributes(endpointARN: String, attributes: [String: String], completion: @escaping (Bool, Error?) -> Void) {
        var params = defaultParams
        params["Action"] = "SetEndpointAttributes"
        params["EndpointArn"] = endpointARN

        for (index, entry) in attributes.enumerated() {
            params["Attributes.entry.\(index + 1).key"] = entry.key
            params["Attributes.entry.\(index + 1).value"] = entry.value
        }

        let request: URLRequest
        do {
            request = try self.request(with: params)
        } catch {
            completion(false, error)
            return
        }

        session.dataTask(with: request) { data, response, error in
            let error = self.checkForError(response: response, data: data, error: error)
            completion(error == nil, error)
        }.resume()
    }

    public func subscribe(endpointARN: String, topicARN: String, completion: @escaping (Bool, String?, Error?) -> Void) {
        var params = defaultParams
        params["Action"] = "Subscribe"
        params["EndpointArn"] = endpointARN
        params["TopicArn"] = topicARN

        let request: URLRequest
        do {
            request = try self.request(with: params)
        } catch {
            completion(false, nil, error)
            return
        }

        session.dataTask(with: request, completionHandler: { data, response, error in
            let error = self.checkForError(response: response, data: data, error: error)
            if error == nil, let data = data, let responseBody = String(data: data, encoding: .utf8) {
                let xml = SWXMLHash.parse(responseBody)
                let subscriptionARN = xml["SubscriptionArn"].element?.text
                completion(true, subscriptionARN, nil)
            } else {
                completion(false, nil, error)
            }
        }).resume()
    }

    private func request(with urlParams: [String: String?]) throws -> URLRequest {
        var urlComponents = URLComponents(string: host)!
        urlComponents.queryItems = urlParams.filter { $0.value != nil && $0.value?.isEmpty == false }
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        try urlRequest.sign(accessKeyId: accessKeyID, secretAccessKey: secretAccessKey)

        return urlRequest
    }

    private func checkForError(response: URLResponse?, data: Data?, error: Error?) -> Error? {
        if let error = error {
            return error
        }

        if (response as? HTTPURLResponse)?.statusCode ?? 999 > 299 {
            if let data = data, let text = String(data: data, encoding: .utf8) {
                return AWSSNSError.generalError(reason: text)
            } else {
                return AWSSNSError.generalError(reason: nil)
            }
        }

        return nil
    }
}

public enum AWSSNSError: Error {
    case generalError(reason: String?)
}

extension AWSSNSError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .generalError(reason):
            return "AWS SNS SDK error " + (reason ?? "No failure reason available")
        }
    }

    public var localizedDescription: String {
        return errorDescription!
    }
}
