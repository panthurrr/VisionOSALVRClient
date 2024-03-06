//
//  SimEvents.swift
//  ALVRClient
//
//  Created by Chris Metrailer on 3/5/24.
//
import Foundation
import Metal
import VideoToolbox
import Combine
import AVKit
import ARKit

extension EventHandler {
    func handleSimEvents() {
        while inputRunning {
            if (false) {
                Task {
                    let curTime = CACurrentMediaTime()
                    if (curTime > lastCheckedTime + 5) {
                        let distance = await WorldTracker.shared.queryDeviceDistanceFromAnchor()
                        EventHandler.shared.updateAnchorDistance(distance)
                        if (distance == -1) {
                            EventHandler.shared.lastCheckedTime = curTime
                        }
                    }
                }
            }
        }
    }
    
    func simStart() {
        if !inputRunning {
            print("Starting simEvent thread")
            inputRunning = true
            eventsThread = Thread {
                self.handleSimEvents()
            }
            eventsThread?.name = "Sim Events Thread"
         //   eventsThread?.start()
        }
    }
}
