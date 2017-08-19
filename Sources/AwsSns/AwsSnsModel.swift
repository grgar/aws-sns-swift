import Foundation
import SWXMLHash

public struct PlatformApplications {
    let nextToken: String?
    let applicationArns: [String]
    
    init?(xml: XMLIndexer) {
        let responseXml = xml["ListPlatformApplicationsResponse"]["ListPlatformApplicationsResult"]
        let optionalArns = responseXml["PlatformApplications"]["member"].all.map { $0["PlatformApplicationArn"].element?.text }
        
        guard let applicationArns = optionalArns as? [String] else { return nil }
        self.applicationArns = applicationArns
        nextToken = responseXml["NextToken"].element?.text
    }
}

public struct PlatformApplicationEnpoints {
    let nextToken: String?
    let endpoints: [Endpoint]
    
    init?(xml: XMLIndexer) {
        let responseXml = xml["ListEndpointsByPlatformApplicationResponse"]["ListEndpointsByPlatformApplicationResult"]
        let optionalEndpoints = responseXml["Endpoints"]["member"].all.map { endpointXml in
            return Endpoint(xml: endpointXml)
        }
        
        guard let endpoints = optionalEndpoints as? [Endpoint] else { return nil }
        self.endpoints = endpoints
        nextToken = responseXml["NextToken"].element?.text
    }
}

public struct Endpoint {
    let arn: String
    let enabled: Bool
    
    init?(xml: XMLIndexer) {
        let enabledXml = xml["Attributes"]["entry"].all.filter { $0["key"].element?.text == "Enabled" }
        guard let arn = xml["EndpointArn"].element?.text,
            let enabled = enabledXml.first?["value"].element?.text else { return nil }
        
        self.arn = arn
        self.enabled = enabled == "true"
    }
}
