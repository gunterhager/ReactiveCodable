//
//  ReactiveCodable.swift
//  ReactiveCodable
//
//  Created by Gunter Hager on 01/08/2017.
//  Copyright © 2017 Gunter Hager. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

public let ReactiveCodableErrorDomain = "name.gunterhager.ReactiveCodable.ErrorDomain"

// Error sent by ReactiveCodable mapping methods
public enum ReactiveCodableError: Error {
    case decoding(DecodingError)
    case underlying(Error)
    case invalidRootKey
    
    public var nsError: NSError {
        switch self {
        case let .decoding(error):
            return error as NSError
        case let .underlying(error):
            return error as NSError
        default:
            return NSError(domain: ReactiveCodableErrorDomain, code: -1, userInfo: nil)
        }
    }
}

let userInfoRootKey = CodingUserInfoKey(rawValue: "rootKey")!

// MARK: Signal

extension SignalProtocol where Value == Data {
    /// Maps the given JSON object within the stream to an object of given `type`.
    ///
    /// - Parameters:
    ///   - type: The type of the object that should be returned
    ///   - decoder: A `JSONDecoder` to use. This allows configuring the decoder.
    /// - Returns: A new Signal emitting the decoded object.
    public func mapToType<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) -> Signal<T, ReactiveCodableError> {
        return signal
            .mapError { ReactiveCodableError.underlying($0) }
            .attemptMap { json -> Result<T, ReactiveCodableError> in
                return unwrapThrowableResult { try decoder.decode(type.self, from: json) }
                
                //                let info = [NSLocalizedFailureReasonErrorKey: "The provided `Value` could not be cast to `Data` or there is no value at the given `rootKeys`: \(String(describing: rootKeys))"]
                //                let error = NSError(domain: ReactiveCodableErrorDomain, code: -1, userInfo: info)
                //                return .failure(.underlying(error))
        }
    }
    
    
    public func mapToType<T: Decodable>(_ type: T.Type, rootKey: CodingKey, decoder: JSONDecoder = JSONDecoder()) -> Signal<T, ReactiveCodableError> {
        return signal
            .mapError { ReactiveCodableError.underlying($0) }
            .attemptMap { json -> Result<T, ReactiveCodableError> in
                guard let key = RootKey(key: rootKey) else { return .failure(ReactiveCodableError.invalidRootKey) }
                return unwrapThrowableResult {
                    decoder.userInfo = [userInfoRootKey: key]
                    let result = try decoder.decode(ContainerModel<T>.self, from: json)
                    return result.nestedModel
                }
        }
    }
    
}

// MARK: SignalProducer

extension SignalProducerProtocol where Value == Data {
    
    /// Maps the given JSON object within the stream to an object of given `type`
    ///
    /// - Parameters:
    ///   - type: The type of the object that should be returned
    ///   - decoder: A `JSONDecoder` to use. This allows configuring the decoder.
    /// - Returns: A new SignalProducer emitting the decoded object.
    public func mapToType<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) -> SignalProducer<T, ReactiveCodableError> {
        return producer.lift { $0.mapToType(type, decoder: decoder) }
    }
    
    public func mapToType<T: Decodable>(_ type: T.Type, rootKey: CodingKey, decoder: JSONDecoder = JSONDecoder()) -> SignalProducer<T, ReactiveCodableError> {
        return producer.lift { $0.mapToType(type, rootKey: rootKey, decoder: decoder) }
    }
    
}

// MARK: Helper

private func unwrapThrowableResult<T>(throwable: () throws -> T) -> Result<T, ReactiveCodableError> {
    do {
        return .success(try throwable())
    } catch {
        if let error = error as? DecodingError {
            return .failure(.decoding(error))
        } else {
            // For extra safety, but the above cast should never fail
            return .failure(.underlying(error))
        }
    }
}

// MARK: RootKey Helper

struct RootKey: CodingKey {
    
    var intValue: Int?
    var stringValue: String
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(key: CodingKey) {
        if let intValue = key.intValue {
            self.init(intValue: intValue)
        } else {
            self.init(stringValue: key.stringValue)
        }
    }
}

struct ContainerModel<T: Decodable>: Decodable {
    
    let nestedModel: T
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RootKey.self)
        guard let rootKey = decoder.userInfo[userInfoRootKey] as? RootKey else { throw ReactiveCodableError.invalidRootKey }
        self.nestedModel = try container.decode(T.self, forKey: rootKey)
    }
}
