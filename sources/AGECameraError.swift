//
//  AGECameraError.swift
//
//  Created by CavanSu on 2019/9/30.
//  Copyright © 2019 Agora. All rights reserved.
//

import UIKit

public struct AGECameraError: Error {
    public enum ErrorType {
        case fail(String)
        case invalidParameter(String)
        case valueNil(String)
        case unknown
    }
    
    public var localizedDescription: String {
        switch type {
        case .fail(let reason):             return "\(reason)"
        case .invalidParameter(let para):   return "\(para)"
        case .valueNil(let para):           return "\(para) nil"
        case .unknown:                      return "unknown error"
        }
    }
    
    public var type: ErrorType
}
