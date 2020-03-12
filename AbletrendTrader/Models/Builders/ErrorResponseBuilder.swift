//
//  ErrorResponseBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-30.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class ErrorResponseBuilder {
    func buildErrorResponseFrom(_ jsonData : Data) -> ErrorResponse? {
        let decoder: JSONDecoder = JSONDecoder()
        do {
            let errorResponse = try decoder.decode(ErrorResponse.self, from: jsonData)
            return errorResponse
        }
        catch(let error) {
        }
        return nil
    }
}
