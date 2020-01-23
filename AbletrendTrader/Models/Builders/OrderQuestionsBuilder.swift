//
//  OrderQuestionsBuilder.swift
//  AbletrendTrader
//
//  Created by Leon Chen on 2019-12-29.
//  Copyright © 2019 LeonChen. All rights reserved.
//

import Foundation

class OrderQuestionsBuilder {
    func buildQuestionsFrom(_ jsonData : Data) -> [Question]? {
        let decoder: JSONDecoder = JSONDecoder()
        do {
            let orderQuestions = try decoder.decode([Question]?.self, from: jsonData)
            return orderQuestions
        }
        catch(let error) {
            print("OrderQuestionsBuilder:")
            print(error)
            print(String(data: jsonData, encoding: .utf8))
        }
        return nil
    }
}
