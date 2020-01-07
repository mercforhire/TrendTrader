//
//  PreviewResponseBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-31.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class PreviewResponseBuilder {
    func buildPreviewResponseFrom(_ jsonData : Data) -> PreviewResponse? {
        let decoder: JSONDecoder = JSONDecoder()
        do {
            let previewResponse = try decoder.decode(PreviewResponse.self, from: jsonData)
            return previewResponse
        }
        catch(let error) {
            print("PreviewResponseBuilder:")
            print(error)
            print(String(data: jsonData, encoding: .utf8))
        }
        return nil
    }
}
