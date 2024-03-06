//
//  ViewModel.swift
//  ALVRClient
//

import SwiftUI

@Observable
class ViewModel {
    // Client
    var isShowingClient: Bool = false
    
    var isDebugMode: Bool = true
    var isShowingDebugWindow: Bool = false
    var isShowingSimClient: Bool = false
    var distanceFromAnchor: Float = 0
}
