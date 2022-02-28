//
//  DataNetworkService.swift
//  ReceiptTracker-v2
//
//  Created by Chen Yu Hang on 24/2/22.
//

import Foundation
import FirebaseStorage


class SecureUrlSessionRequest {
    private var _urlRequest: URLRequest?
    
    var urlRequest: URLRequest? {
        get {
            return self._urlRequest
        }
    }
}

extension SecureUrlSessionRequest {
    
    func createUrlRequest(url: URL) {
        self._urlRequest = URLRequest(url: url)
    }
    
    private func SetProperty(key: String?, value: String?) throws {
        guard var _ = self._urlRequest else {
            throw SecureUrlSessionRequest.SecureUrlSessionRequestError.SecureUrlSessionRequestUrlRequestIsMissing
        }
        
        guard let key = key else {
            throw SecureUrlSessionRequest.SecureUrlSessionRequestError.SecureUrlSessionRequestPropertyKeyIsMissing
        }
        
        guard let value = value else {
            throw SecureUrlSessionRequest.SecureUrlSessionRequestError.SecureUrlSessionRequestPropertyValueIsMissing
        }
        
        self._urlRequest!.addValue(value, forHTTPHeaderField: key)
    }
    
    func setHttpMethod(httpType: String) {
        do {
            guard var _ = self._urlRequest else {
                throw SecureUrlSessionRequest.SecureUrlSessionRequestError.SecureUrlSessionRequestUrlRequestIsMissing
            }
            self._urlRequest!.httpMethod = httpType
        } catch {
            debugPrint("ERROR", "SecureUrlSessionRequest", "setHttpMethod", error.localizedDescription, separator: ":")
        }
    }
    
    func setBodyContent(content: Data) {
        do {
            guard var _ = self._urlRequest else {
                throw SecureUrlSessionRequest.SecureUrlSessionRequestError.SecureUrlSessionRequestUrlRequestIsMissing
            }
            self._urlRequest!.httpBody = content
        } catch {
            debugPrint("ERROR", "SecureUrlSessionRequest", "setBodyContent", error.localizedDescription, separator: ":")
        }
    }
    
    func SetAuthorization(secretId: String) {
        do {
            try self.SetProperty(key: "Authorization", value: secretId)
        } catch {
            debugPrint("ERROR", "SecureUrlSessionRequest", "SetAuthorization", error.localizedDescription, separator: ":")
        }
    }
    
    func SetContentType(contentType: String) {
        do {
            try self.SetProperty(key: "Content-Type", value: contentType)
        } catch {
            debugPrint("ERROR", "SecureUrlSessionRequest", "SetContentType", error.localizedDescription, separator: ":")
        }
    }
    
    func SetOtherProperty(key: String, value: String) {
        do {
            try self.SetProperty(key: key, value: value)
        } catch {
            debugPrint("ERROR", "SecureUrlSessionRequest", "SetOtherProperty", error.localizedDescription, separator: ":")
        }
    }
}

extension SecureUrlSessionRequest {
    enum SecureUrlSessionRequestError: Swift.Error {
        case SecureUrlSessionRequestUrlRequestIsMissing
        case SecureUrlSessionRequestPropertyValueIsMissing
        case SecureUrlSessionRequestPropertyKeyIsMissing
        case unknown
    }
}


class Util {

    private init() {
        
    }
}

extension Util {
    static func constructReceiptNotionJsonObj(receiptRecords: ReceiptRecords, databaseId: String?) throws -> [String: Any]{
        guard let databaseId = databaseId else {
            throw NotionService.NotionServiceError.NotionServiceErrorDatabaseIdMissing
        }
        
        guard let receiptId = receiptRecords.id else {
            throw NotionService.NotionServiceError.NotionServiceErrorReceiptRecordsIdMissing
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let jsonObject: [String: Any] = [
            "parent": [
                "database_id": databaseId
            ],
            "properties": [
                "Id": [
                    "title": [[
                        "text": [
                            "content": receiptId
                        ]
                    ]]
                ],
                "Store": [
                    "multi_select": [[
                        "name": receiptRecords.store
                    ]]
                ],
                "Purchase Date": [
                    "date": [
                        "start": dateFormatter.string(from: receiptRecords.purchaseDate)
                    ]
                ],
                "Category": [
                    "multi_select": [[
                        "name": receiptRecords.category
                    ]]
                ],
                "Price": [
                    "number": receiptRecords.price
                ],
                "Image": [
                    "url": receiptRecords.imageUrl
                ]
            ]
        ]

        if !JSONSerialization.isValidJSONObject(jsonObject) {
            throw NotionService.NotionServiceError.NotionServiceErrorInvalidJsonObject
        }
        
        return jsonObject
    }
    
    static func constructReceiptRecordFilterJsonObj() throws -> String? {
        
        var jsonfilter: JsonFilter = JsonFilter()
        jsonfilter.filter!.and[0].property = "Validity"
        jsonfilter.filter!.and[0].checkbox?.equals = false
        
        
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted

        do {
            let encodeJsonfilterObj = try jsonEncoder.encode(jsonfilter)
            let endcodeStringPJsonFilterObj = String(data: encodeJsonfilterObj, encoding: .utf8)!
            return endcodeStringPJsonFilterObj
        } catch {
            return nil
        }
    }
    
    static func convertJsonIntoDatabase(jsonInput: [String: Any]) -> ReceiptRecordsDatabase {
        func addOptionsList(receiptRecordsDatabase: inout ReceiptRecordsDatabase, multiSelctName: String, optionsList: [[String:String]]) {
            for ops in optionsList {
                if let color = ops["color"], let id = ops["id"], let name = ops["name"] {
                    receiptRecordsDatabase.addMultiSelect(multiSelectName: multiSelctName, color: color, id: id, name: name)
                }
            }
        }
        
        func getAndSetMultiSelectProperties(receiptRecordsDatabase: inout ReceiptRecordsDatabase, headerName: String, rawPropertiesHeader: [String:Any]) {
            if let multiSelectHeader = rawPropertiesHeader[headerName] as? [String:Any], let options = multiSelectHeader["multi_select"] as? [String:Any],
               let optionsList = options["options"] as? [[String: String]]{
                
                addOptionsList(receiptRecordsDatabase: &receiptRecordsDatabase, multiSelctName: headerName, optionsList: optionsList)
            }
        }
        
        var receiptRecordsDatabase: ReceiptRecordsDatabase = ReceiptRecordsDatabase()
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable zh_Hant_TW
        dateFormatter.dateFormat = "yyyy-mm-dd'T'HH:mm:ss.sssZ"
        
        // pares ID field
        if let id = jsonInput[ReceiptRecordsDatabase.ID_FIELD_NAME] as? String {
            receiptRecordsDatabase.id = id
        }
        
        // parse parent field
        if let parent = jsonInput[ReceiptRecordsDatabase.PARENT_FIELD_NAME] as? [String: Any],
           let parentType = parent[ReceiptRecordsDatabase.PARENT_TYPE_FIELD_NAME] as? String {
            receiptRecordsDatabase.parent = parentType
        }
        
        // parse created time field
        if let createdTime = jsonInput[ReceiptRecordsDatabase.CREATED_TIME_FIELD_NAME] as? String {
            receiptRecordsDatabase.createdTime = dateFormatter.date(from: createdTime)
        }
        
        // parse last edited time field
        if let lastEditedTime = jsonInput[ReceiptRecordsDatabase.LAST_EDITED_TIME_FIELD_NAME] as? String {
            receiptRecordsDatabase.lastEditedTime = dateFormatter.date(from: lastEditedTime)
        }

        // parse database title field
        if let titleHeader = jsonInput[ReceiptRecordsDatabase.TITLE_FIELD_NAME] as? [[String:Any]],
            let titleHeaderOption = titleHeader.first, let title = titleHeaderOption["plain_text"] as? String{
            receiptRecordsDatabase.databaseTitle = title
        }
        
        
        // Going through multi_select properties
        if let propertiesHeader = jsonInput[ReceiptRecordsDatabase.PROPERTIES_FIELD_NAME] as? [String:Any] {
            getAndSetMultiSelectProperties(receiptRecordsDatabase: &receiptRecordsDatabase, headerName: "Store", rawPropertiesHeader: propertiesHeader)
            getAndSetMultiSelectProperties(receiptRecordsDatabase: &receiptRecordsDatabase, headerName: "Category", rawPropertiesHeader: propertiesHeader)
        }
        
        return receiptRecordsDatabase
    }
    
    
    static func populateObjectIntoReceiptRecordObj(object: [String: Any]) -> [ReceiptRecords]{
        var receiptRecordsArray: [ReceiptRecords] = []
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable zh_Hant_TW
        dateFormatter.dateFormat = "yyyy-mm-dd"
        
        if let results = object["results"] as? [[String: Any]]{
            for result in results {
                var receiptRecord =  ReceiptRecords(id: result["id"] as! String,
                                                    store: "",
                                                    purchaseDate: Date(),
                                                    category: "",
                                                    price: 0,
                                                    imageUrl: "")
                
                if let properties = result["properties"] as? [String:Any] {
                    if let category = properties["Category"] as? [String: Any] {
                        if let multiSelect = category["multi_select"] as? [[String:Any]] {
                            if let value = multiSelect[0]["name"] as? String {
                                receiptRecord.category = value
                            }
                        }
                    }
                    if let store = properties["Store"] as? [String: Any] {
                        if let multiSelect = store["multi_select"] as? [[String:Any]] {
                            if let value = multiSelect[0]["name"] as? String {
                                receiptRecord.store = value
                            }
                        }
                    }
                    if let purchaseDate = properties["Purchase Date"] as? [String:Any] {
                        if let date = purchaseDate["date"] as? [String: Any] {
                            if let start = date["start"] as? String {
                                receiptRecord.purchaseDate = dateFormatter.date(from: start)!
                            }
                        }
                    }
                    
                    if let price = properties["Price"] as? [String:Any] {
                        if let number = price["number"] as? Int {
                            receiptRecord.price = number
                        }
                    }
                    
                    if let image = properties["Image"] as? [String:Any] {
                        if let url = image["url"] as? String {
                            receiptRecord.imageUrl = url
                        }
                    }
                }
                
                receiptRecordsArray.append(receiptRecord)
            }
        }
        return receiptRecordsArray
    }
}


///
/// Notion Service
///
class NotionService {
    
    private var databaseId: String?
    private var secureUrlRequest: SecureUrlSessionRequest = SecureUrlSessionRequest()
    private let urlSession: URLSession = URLSession(configuration: .default)
    
    // Create the singleton for notion service object
    public static let shared: NotionService = NotionService()
    
    let NOTION_API_VERSION: String  = "v1"
    let NOTION_API_URL: String  = "https://api.notion.com"
    let NOTION_SECRET_KEY: String  = "secret_uN4aZgDV7XuKOnZocZKSnLti2dSN5g8GHw8Y4sVMJ48"
    let NOTION_VERSION: String = "2021-08-16"
    let NOTION_CONTENT_TYPE: String  = "application/json"
    
    private init() {
        
    }
}

extension NotionService {
    
    func setDatabaseId(databaseId: String) {
        self.databaseId = databaseId
    }
    
    func getDatabaseInfo(completion: @escaping (ReceiptRecordsDatabase?, Error?) -> Void) {
        do {
            guard let databaseId = self.databaseId else {
                throw NotionService.NotionServiceError.NotionServiceErrorDatabaseIdMissing
            }
            
            let requestedUrl: String = "\(NOTION_API_URL)/\(NOTION_API_VERSION)/databases/\(databaseId)"
            self.configureNotionRequest(requestedUrl: requestedUrl, httpType: "GET", data: nil)
            
            guard let localUrlRequest = self.secureUrlRequest.urlRequest else {
                completion(nil, NotionService.NotionServiceError.NotionServiceErrorInvalidUrlRequest)
                return
            }
            
            let task: URLSessionDataTask = self.urlSession.dataTask(with: localUrlRequest) {
                (data, response, error) in
                
                guard let response = response as? HTTPURLResponse else {
                    completion(nil, NotionService.NotionServiceError.NotionServiceErrorInvalidResponse)
                    return
                }
                
                if response.statusCode == 200 {
                    do {
                        if let data = data, let jsonObj = Optional(try JSONSerialization.jsonObject(with: data, options: [])), let object = jsonObj as? [String: Any]{
                            
                            let receiptRecordsDatabase: ReceiptRecordsDatabase = Util.convertJsonIntoDatabase(jsonInput: object)
                            completion(receiptRecordsDatabase, nil)
                        }
                    } catch {
                        completion(nil, NotionService.NotionServiceError.NotionServiceErrorInvalidJsonObject)
                    }
                } else {
                    completion(nil, NotionService.NotionServiceError.NotionServiceErrorRequestFailed)
                }
            }
            
            task.resume()
            
        } catch {
            debugPrint("ERROR", "NotionService", "getDatabaseInfo", error.localizedDescription, separator: ":")
            completion(nil, error)
        }
    }
    
    func getAllReceiptRecords(completion: @escaping ([ReceiptRecords]?, Error?, String?) -> Void) {
        do {
            guard let databaseId = self.databaseId else {
                throw NotionService.NotionServiceError.NotionServiceErrorDatabaseIdMissing
            }
            let jsonObj: String = try Util.constructReceiptRecordFilterJsonObj( )!

            let requestedUrl: String = "\(NOTION_API_URL)/\(NOTION_API_VERSION)/databases/\(databaseId)/query"
            self.configureNotionRequest(requestedUrl: requestedUrl, httpType: "POST", data: jsonObj.data(using: .utf8))
            
            guard let localUrlRequest = self.secureUrlRequest.urlRequest else {
                completion(nil, NotionService.NotionServiceError.NotionServiceErrorInvalidUrlRequest, nil)
                return
            }
            
            let task: URLSessionDataTask = self.urlSession.dataTask(with: localUrlRequest) {
                (data, response, error) in
                
                guard let response = response as? HTTPURLResponse else {
                    completion(nil, NotionService.NotionServiceError.NotionServiceErrorInvalidResponse, nil)
                    return
                }
                
                if response.statusCode == 200 {
                    do {
                        if let data = data, let jsonObj = Optional(try JSONSerialization.jsonObject(with: data, options: [])), let object = jsonObj as? [String: Any]{
                            completion(Util.populateObjectIntoReceiptRecordObj(object: object), nil, "")
                        }
                    } catch {
                        completion(nil, NotionService.NotionServiceError.NotionServiceErrorInvalidJsonObject, "Invalid Json Parser")
                    }
                } else {
                    do {
                        if let data = data, let jsonObj = Optional(try JSONSerialization.jsonObject(with: data, options: [])), let object = jsonObj as? [String: Any]{
                            completion(nil, NotionService.NotionServiceError.NotionServiceErrorRequestFailed, object["message"] as? String)
                        }
                        else {
                            completion(nil, NotionService.NotionServiceError.NotionServiceErrorRequestFailed, "Invalid json data error message")
                        }
                    } catch {
                        completion(nil, NotionService.NotionServiceError.NotionServiceErrorRequestFailed, "Invalid Json Parser on error message")
                    }
                }
            }
            
            task.resume()
            
        } catch {
            debugPrint("ERROR", "NotionService", "getAllReceiptRecords", error.localizedDescription, separator: ":")
            completion(nil, error, "Invalid Database ID")
        }
    }
    
    
    func createNewReceiptRecords(receiptRecords: ReceiptRecords, completion: @escaping (Error?) -> Void) {
        
        do {
            let jsonObj = try Util.constructReceiptNotionJsonObj(receiptRecords: receiptRecords, databaseId: self.databaseId)
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObj, options: JSONSerialization.WritingOptions()) as Data
            let requestedUrl: String = "\(NOTION_API_URL)/\(NOTION_API_VERSION)/pages"
            self.configureNotionRequest(requestedUrl: requestedUrl, httpType: "POST", data: jsonData)

            guard let localUrlRequest = self.secureUrlRequest.urlRequest else {
                completion(NotionService.NotionServiceError.NotionServiceErrorInvalidUrlRequest)
                return
            }
            
            let task: URLSessionDataTask = self.urlSession.dataTask(with: localUrlRequest) {
                (data, response, error) in
                
                guard let response = response as? HTTPURLResponse else {
                    completion(NotionService.NotionServiceError.NotionServiceErrorInvalidResponse)
                    return
                }
                
                if response.statusCode == 200 {
                    completion(nil)
                } else {
                    completion(NotionService.NotionServiceError.NotionServiceErrorRequestFailed)
                }
            }
            
            task.resume()
            
        } catch {
            debugPrint("ERROR", "NotionService", "createNewReceiptRecords", error.localizedDescription, separator: ":")
            completion(error)
        }
    }
    
    private func configureNotionRequest(requestedUrl: String, httpType: String, data: Data? ) {
        secureUrlRequest.createUrlRequest(url: URL(string: requestedUrl)!)
        secureUrlRequest.SetAuthorization(secretId: "Bearer \(self.NOTION_SECRET_KEY)")
        secureUrlRequest.SetContentType(contentType: self.NOTION_CONTENT_TYPE)
        secureUrlRequest.SetOtherProperty(key: "Notion-Version", value: self.NOTION_VERSION)
        secureUrlRequest.setHttpMethod(httpType: httpType)
        if let data = data {
            secureUrlRequest.setBodyContent(content: data)
        }
    }
    
    
}

extension NotionService {
    enum NotionServiceError: Swift.Error {
        case NotionServiceErrorDatabaseIdMissing
        case NotionServiceErrorReceiptRecordsIdMissing
        case NotionServiceErrorInvalidJsonObject
        case NotionServiceErrorInvalidResponse
        case NotionServiceErrorRequestFailed
        case NotionServiceErrorInvalidUrlRequest
        case NotoinServiceErrorSecretIdMissing
        case unknown
    }
}


///
/// Firebase Services
///
class FirebaseService {
    
    struct FirebaseImageUploadInfo {
        var parentFolderName: String?
        var imageName: String?
        var imageData: Data?
    }
    
    // Create the singleton for firebase service object
    public static let shared: FirebaseService = FirebaseService()
    
    // Related Firebase objects
    private var storageRef: StorageReference?
    
    private init() {
        
    }
}

extension FirebaseService {
    
    private func createOrReturnStorageRef() -> StorageReference? {
        
        guard let _ = self.storageRef else {
            self.storageRef = Storage.storage().reference()
            return self.storageRef
        }
        
        return self.storageRef
    }
    
    private func firebaseStorageDataUpload(data: Data, refString: String, completionBlock: @escaping ((FirebaseService.FirebaseServiceError?) -> Void)) {
        guard let localStorageRef = self.createOrReturnStorageRef() else { completionBlock(.FirebaseServiceStorageRefIsMissing); return }
        
        localStorageRef.child(refString).putData(data, metadata: nil) { _, error in
            guard error == nil else {
                completionBlock(.FirebaseServiceDataUploadFail)
                return
            }
            
            // Nothing happened, upload successful
            completionBlock(nil)
        }
    }
    
    private func firebaseStorageDownloadUrl(refString: String, completionBlock: @escaping ( (String?, FirebaseService.FirebaseServiceError?) -> Void)) {
        guard let localStorageRef = self.createOrReturnStorageRef() else { completionBlock(nil, .FirebaseServiceStorageRefIsMissing); return }
        
        localStorageRef.child(refString).downloadURL { url, error in
            guard error == nil else {
                completionBlock(nil, .FirebaseServiceDownloadUrlFail)
                return
            }
            
            guard let url = url else { completionBlock(nil, .FirebaseServiceDownloadUrlMissing); return }

            completionBlock(url.absoluteString, nil)
        }
    }
    
    func uploadImage(firebaseImageUploadInfo uploadInfo: FirebaseImageUploadInfo, completionBlock: @escaping ( (String?, FirebaseService.FirebaseServiceError?) -> Void)) {
        
        // Create the local storage reference if not yet created
        guard let imageName: String = uploadInfo.imageName else { completionBlock(nil, .FirebaseServiceImageNameIsMissing); return }
        guard let imageData: Data = uploadInfo.imageData else { completionBlock(nil, .FirebaseServiceImageNameIsMissing); return }
        
        // Reference path in the storage ref
        var refPathString: String?
        
        if let parentFolderName = uploadInfo.parentFolderName {
            refPathString = "\(parentFolderName)/\(imageName)"
        } else {
            refPathString = "\(imageName)"
        }
        
        // Upload the image using firebase service
        self.firebaseStorageDataUpload(data: imageData, refString: refPathString!) { error in
            
            guard error == nil else { completionBlock(nil, error); return }
            
            self.firebaseStorageDownloadUrl(refString: refPathString!, completionBlock: completionBlock)
        }
    }
}

extension FirebaseService {
    enum FirebaseServiceError: Swift.Error {
        case FirebaseServiceStorageRefIsMissing
        case FirebaseServiceImageNameIsMissing
        case FirebaseServiceImageDataIsMissing
        case FirebaseServiceDataUploadFail
        case FirebaseServiceDownloadUrlFail
        case FirebaseServiceDownloadUrlMissing
        case unknown
    }
}
