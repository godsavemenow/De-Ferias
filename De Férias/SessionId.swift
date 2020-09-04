//
//  SessionId.swift
//  testing
//
//  Created by Lucas Silva on 01/09/20.
//  Copyright © 2020 Lucas Silva. All rights reserved.
//

import Foundation

// MARK: - Welcome
struct SessionId: Codable {
    let sessionID: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
    }
}
