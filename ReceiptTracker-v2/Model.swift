//
//  Model.swift
//  ReceiptTracker-v2
//
//  Created by Chen Yu Hang on 28/2/22.
//

import Foundation
import UIKit

struct ReceiptRecordsDatabase {
    
    static let ID_FIELD_NAME: String = "id"
    static let PARENT_FIELD_NAME: String = "parent"
    static let PARENT_TYPE_FIELD_NAME: String = "type"
    static let CREATED_TIME_FIELD_NAME: String = "created_time"
    static let LAST_EDITED_TIME_FIELD_NAME: String = "last_edited_time"
    static let TITLE_FIELD_NAME: String = "title"
    static let TITLE_PLAIN_TEXT_FIELD_NAME: String = "plain_text"
    static let PROPERTIES_FIELD_NAME: String = "properties"
    
    
    var parent: String?
    var lastEditedTime: Date?
    var id: String?
    var databaseTitle: String?
    var createdTime: Date?
    
    struct MultiSelect {
        struct MultiSelectOption {
            var color: String?
            var id: String?
            var name: String?
        }
        
        var multiSelectOption: [MultiSelectOption] = []
        var name: String?
    }
    
    var multiSelectList: [String: MultiSelect] = [:]
        
    
    mutating func createMultiSelect(name: String) {
        multiSelectList[name] = MultiSelect()
        multiSelectList[name]?.name = name
    }
    
    mutating func addMultiSelect(multiSelectName: String, color: String, id: String, name: String) {
        if var _ = self.multiSelectList[multiSelectName] {
            self.multiSelectList[multiSelectName]!.multiSelectOption.append(
                MultiSelect.MultiSelectOption(color: color, id: id, name: name)
            )
        } else {
            self.createMultiSelect(name: multiSelectName)
            self.addMultiSelect(multiSelectName: multiSelectName, color: color, id: id, name: name)
        }
    }
}

struct ReceiptRecords {
    var id: String?
    var store: String = "No Store Specified"
    var purchaseDate: Date = Date()
    var category: String = "Not categorized"
    var price: Int = 0
    var imageUrl: String = ""
    var uiImage: UIImage?
    
    init(id: String, store: String, purchaseDate: Date, category: String, price: Int, imageUrl: String) {
        self.id = id
        self.store = store
        self.purchaseDate = purchaseDate
        self.category = category
        self.price = price
        self.imageUrl = imageUrl
    }
}


// Structure for filtering database query
struct JsonFilter: Encodable {
    
    struct JsonfilterObj: Encodable{
        
        struct CheckBoxProperty: Encodable{
            
            struct CheckBoxStruct: Encodable {
                var equals: Bool?
                
                init( ) {
                    self.equals = false
                }
            }
            
            var property: String?
            var checkbox: CheckBoxStruct?
            
            init( ) {
                self.property = ""
                self.checkbox  = CheckBoxStruct()
            }
        }

        var and = [CheckBoxProperty()]
    }
    
    var filter: JsonfilterObj?
    
    init() {
        self.filter = JsonfilterObj()
    }
}
