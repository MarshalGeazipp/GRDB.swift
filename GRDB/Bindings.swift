//
//  Bindings.swift
//  GRDB
//
//  Created by Gwendal Roué on 02/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

protocol BindingsImpl {
    func bindInStatement(statement: Statement)
    func dictionary(defaultColumnNames defaultColumnNames: [String]?) -> [String: DatabaseValueType?]
}

public struct Bindings {
    let impl: BindingsImpl
    
    public init<Sequence: SequenceType where Sequence.Generator.Element == Optional<DatabaseValueType>>(_ array: Sequence) {
        impl = BindingsArrayImpl(array: Array(array))
    }
    
    public init<Sequence: SequenceType where Sequence.Generator.Element == DatabaseValueType>(_ array: Sequence) {
        impl = BindingsArrayImpl(array: array.map { $0 })
    }
    
    public init(_ array: NSArray) {
        // This is a convenience initializer.
        //
        // Without it, the following code won't compile:
        //
        //    let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
        //    let persons = [
        //        ["Arthur", 41],
        //        ["Barbara"],
        //    ]
        //    for person in persons {
        //        statement.clearBindings()
        //        statement.bind(Bindings(person))  // Error
        //        try statement.execute()
        //    }
        var values = [DatabaseValueType?]()
        for item in array {
            values.append(Bindings.databaseValueFromAnyObject(item))
        }
        self.init(values)
    }
    
    public init(_ dictionary: [String: DatabaseValueType?]) {
        impl = BindingsDictionaryImpl(dictionary: dictionary)
    }
    
    public init(_ dictionary: NSDictionary) {
        // This is a convenience initializer.
        //
        // Without it, the following code won't compile:
        //
        //    let statement = try db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
        //    let persons = [
        //        ["name": "Arthur", "age": 41],
        //        ["name": "Barbara"],
        //    ]
        //    for person in persons {
        //        statement.clearBindings()
        //        statement.bind(Bindings(person))  // Error
        //        try statement.execute()
        //    }
        var values = [String: DatabaseValueType?]()
        for (key, item) in dictionary {
            if let key = key as? String {
                values[key] = Bindings.databaseValueFromAnyObject(item)
            } else {
                fatalError("Not a String key: \(key)")
            }
        }
        self.init(values)
    }
    
    func bindInStatement(statement: Statement) {
        impl.bindInStatement(statement)
    }
    
    func dictionary(defaultColumnNames defaultColumnNames: [String]?) -> [String: DatabaseValueType?] {
        return impl.dictionary(defaultColumnNames: defaultColumnNames)
    }
    
    private struct BindingsArrayImpl : BindingsImpl {
        let array: [DatabaseValueType?]
        init(array: [DatabaseValueType?]) {
            self.array = array
        }
        func bindInStatement(statement: Statement) {
            for (index, value) in array.enumerate() {
                statement.bind(value, atIndex: index + 1)
            }
        }
        func dictionary(defaultColumnNames defaultColumnNames: [String]?) -> [String : DatabaseValueType?] {
            guard let defaultColumnNames = defaultColumnNames else {
                fatalError("Missing column names")
            }
            guard defaultColumnNames.count == array.count else {
                fatalError("Columns count mismatch.")
            }
            var dictionary = [String : DatabaseValueType?]()
            for (column, value) in zip(defaultColumnNames, array) {
                dictionary[column] = value
            }
            return dictionary
        }
    }
    
    private struct BindingsDictionaryImpl : BindingsImpl {
        let dictionary: [String: DatabaseValueType?]
        init(dictionary: [String: DatabaseValueType?]) {
            self.dictionary = dictionary
        }
        func bindInStatement(statement: Statement) {
            for (key, value) in dictionary {
                statement.bind(value, forKey: key)
            }
        }
        func dictionary( defaultColumnNames defaultColumnNames: [String]?) -> [String : DatabaseValueType?] {
            return dictionary
        }
    }
    
    private static func databaseValueFromAnyObject(object: AnyObject) -> DatabaseValueType? {
        
        // IMPLEMENTATION NOTE:
        //
        // NSNumber, NSString, NSNull can't adopt DatabaseValueType because
        // Swift 2 won't make it possible.
        //
        // This is why this method exists. As a convenience for init(NSArray)
        // and init(NSDictionary), themselves conveniences for the library user.
        
        switch object {
        case let value as DatabaseValueType:
            return value
        case _ as NSNull:
            return nil
        case let string as NSString:
            return string as String
        case let number as NSNumber:
            let objCType = String.fromCString(number.objCType)!
            switch objCType {
            case "c":
                return Int64(number.charValue)
            case "C":
                return Int64(number.unsignedCharValue)
            case "s":
                return Int64(number.shortValue)
            case "S":
                return Int64(number.unsignedShortValue)
            case "i":
                return Int64(number.intValue)
            case "I":
                return Int64(number.unsignedIntValue)
            case "l":
                return Int64(number.longValue)
            case "L":
                return Int64(number.unsignedLongValue)
            case "q":
                return Int64(number.longLongValue)
            case "Q":
                return Int64(number.unsignedLongLongValue)
            case "f":
                return Double(number.floatValue)
            case "d":
                return number.doubleValue
            case "B":
                return number.boolValue
            default:
                fatalError("Not a DatabaseValueType: \(object)")
            }
        default:
            fatalError("Not a DatabaseValueType: \(object)")
        }
    }
}

extension Bindings : ArrayLiteralConvertible {
    public init(arrayLiteral elements: DatabaseValueType?...) {
        self.init(elements)
    }
}

extension Bindings : DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (String, DatabaseValueType?)...) {
        var dictionary = [String: DatabaseValueType?]()
        for (key, value) in elements {
            dictionary[key] = value
        }
        self.init(dictionary)
    }
}
