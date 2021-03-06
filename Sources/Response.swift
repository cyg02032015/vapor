import Foundation

public protocol ResponseWriter {
    func write(data: [UInt8])
}

/**
    Responses that redirect to a supplied URL.
 */
public class Redirect: Response {

    ///The URL string for redirect
    var redirectLocation: String

    /**
        Redirect headers return normal `Response` headers
        while adding `Location`.

        @return [String: String] Dictionary of headers
     */
    override func headers() -> [String: String] {
        var headers = super.headers()
        headers["Location"] = self.redirectLocation
        return headers
    }

    /**
        Creates a `Response` object that redirects
        to a given URL string.

        - parameter redirectLocation: The URL string for redirect
        
        - returns Response
     */
    public init(to redirectLocation: String) {
        self.redirectLocation = redirectLocation
        super.init(statusCode: 301, data: [], contentType: .None)
    }
}

/**
    Responses are objects responsible for returning
    data to the HTTP request such as the body, status 
    code and headers.
 */
public class Response {

    public enum SerializationError: ErrorType {
        case InvalidObject
        case NotSupported
    }

    typealias WriteClosure = (ResponseWriter) throws -> Void

    let statusCode: Int
    let data: [UInt8]
    let contentType: ContentType

    enum ContentType {
        case Text, Html, Json, None
    }

    enum Status {
        case OK, Created, Accepted
        case MovedPermanently
        case BadRequest, Unauthorized, Forbidden, NotFound
        case InternalServerError
        case Unknown
    }

    var status: Status {
        switch self.statusCode {
        case 200:
            return .OK
        case 201:
            return .Created
        case 202:
            return .Accepted
        case 301:
            return .MovedPermanently
        case 400:
            return .BadRequest
        case 401:
            return .Unauthorized
        case 403:
            return .Forbidden
        case 404:
            return .NotFound
        case 500:
            return .InternalServerError
        default: 
            return .Unknown
        }
    }
    var reasonPhrase: String {
        switch self.status {
        case .OK:
            return "OK"
        case .Created: 
            return "Created"
        case .Accepted: 
            return "Accepted"
        case .MovedPermanently: 
            return "Moved Permanently"
        case .BadRequest: 
            return "Bad Request"
        case .Unauthorized: 
            return "Unauthorized"
        case .Forbidden: 
            return "Forbidden"
        case .NotFound: 
            return "Not Found"
        case .InternalServerError: 
            return "Internal Server Error"
        case .Unknown:
            return "Unknown"
        }
    }

    func content() -> (length: Int, writeClosure: WriteClosure?) {
        return (self.data.count, { writer in
            writer.write(self.data) 
        })
    }

    func headers() -> [String: String] {
        var headers = ["Server" : "Vapor \(Server.VERSION)"]

        switch self.contentType {
        case .Json: 
            headers["Content-Type"] = "application/json"
        case .Html: 
            headers["Content-Type"] = "text/html"
        default:
            break
        }

        return headers
    }

    init(statusCode:Int, data: [UInt8], contentType: ContentType) {
        self.statusCode = statusCode
        self.data = data
        self.contentType = contentType
    }

    convenience init(error: String) {
        let object: [String: Any] = [
            "error": true,
            "message": error
        ]
        try! self.init(statusCode: 500, jsonObject: object as! AnyObject)
    }

    convenience init(statusCode: Int, html: String) {
        let serialised = "<html><meta charset=\"UTF-8\"><body>\(html)</body></html>"
        let data = [UInt8](serialised.utf8)
        self.init(statusCode: statusCode, data: data, contentType: .Html)
    }

    convenience init(statusCode: Int, text: String) {
        let data = [UInt8](text.utf8)
        self.init(statusCode: statusCode, data: data, contentType: .Text)
    }

    convenience init(statusCode: Int, jsonObject: AnyObject) throws {
        guard NSJSONSerialization.isValidJSONObject(jsonObject) else {
            throw SerializationError.InvalidObject
        }

        let json = try NSJSONSerialization.dataWithJSONObject(jsonObject, options: NSJSONWritingOptions.PrettyPrinted)
        let data = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(json.bytes), count: json.length))

        self.init(statusCode: statusCode, data: data, contentType: .Json)
    }
}


func ==(left: Response, right: Response) -> Bool {
    return left.statusCode == right.statusCode
}

