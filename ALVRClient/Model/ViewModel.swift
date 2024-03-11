//
//  ViewModel.swift
//  ALVRClient
//

import SwiftUI

@Observable
class ViewModel {
    // Client
    var isShowingClient: Bool = false
    
    var immersiveSpaceID: String = "Mixed"
    
    var isDebugMode: Bool = true
    
    var isShowingDebugWindow: Bool = false
    var isShowingSimClient: Bool = false
    var enableRecenter: Bool = false
    var distanceFromAnchor: Float = 0
}
