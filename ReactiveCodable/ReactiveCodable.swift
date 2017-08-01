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
    
    public var nsError: NSError {
        switch self {
        case let .decoding(error):
            return error as NSError
        case let .underlying(error):
            return error as NSError
        }
    }
}

// MARK: Signal

extension SignalProtocol where Value == Data {
    /// Maps the given JSON object within the stream to an object of given `type`.
    ///
    /// - parameter type: The type of the object that should be returned
    /// - parameter rootKeys: An array of keys that should be traversed in order to find a nested JSON object. The resulting object is subsequently used for further decoding.
    ///
    /// - returns: A new Signal emitting the decoded object.
    public func mapToType<T: Decodable>(_ type: T.Type, rootKeys: [String]? = nil) -> Signal<T, ReactiveCodableError> {
        return signal
            .mapError { ReactiveCodableError.underlying($0) }
            .attemptMap { json -> Result<T, ReactiveCodableError> in
                return unwrapThrowableResult { try JSONDecoder().decode(type.self, from: json) }
                
                //                let info = [NSLocalizedFailureReasonErrorKey: "The provided `Value` could not be cast to `Data` or there is no value at the given `rootKeys`: \(String(describing: rootKeys))"]
                //                let error = NSError(domain: ReactiveCodableErrorDomain, code: -1, userInfo: info)
                //                return .failure(.underlying(error))
        }
    }
    
}

// MARK: SignalProducer

extension SignalProducerProtocol where Value == Data {
    
    /// Maps the given JSON object within the stream to an object of given `type`
    ///
    /// - parameter type: The type of the object that should be returned
    /// - parameter rootKeys: An array of keys that should be traversed in order to find a nested JSON object. The resulting object is subsequently used for further decoding.
    ///
    /// - returns: A new SignalProducer emitting the decoded object.
    public func mapToType<T: Decodable>(_ type: T.Type, rootKeys: [String]? = nil) -> SignalProducer<T, ReactiveCodableError> {
        return producer.lift { $0.mapToType(type, rootKeys: rootKeys) }
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
