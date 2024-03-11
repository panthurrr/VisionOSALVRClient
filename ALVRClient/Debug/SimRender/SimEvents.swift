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
import RealityKit
import QuartzCore


extension EventHandler {
    func handleSimEvents() {
        while inputRunning {
//            Task {
                //Using real render sim frame now
              //  try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                            autoreleasepool {
                                 self.renderSimFrame()
                            }
//            }
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
            eventsThread?.start()
        }
    }
    func renderSimLoop() {
        EventHandler.shared.renderStarted = true
        while EventHandler.shared.renderStarted {
            self.renderSimFrame()
        }
    }
    
    
    func renderSimFrame() {
        let time = CACurrentMediaTime()
        world.sendTracking(targetTimestamp: time)
        
        renderLobby()
    }
    
    func renderLobby() {
        if EventHandler.shared.streamingActive {
            self.updateGameState()
        }
    }
    
    func updateGameState() {
        guard world.worldTracking.state == .running else { return }
        Task {
            if let device = world.getDevice() {
                let distanceFromCenter = world.deviceDistanceFromCenter(anchor: device)
                EventHandler.shared.updateDistanceFromCenter(distanceFromCenter)
//                if distanceFromCenter > 1 {
//                    print("Should update center to Device location but skipping for now")
////                    WorldTracker.shared.setCenter(device)
//                }
                
                let anchorDistance = world.deviceDistanceFromAnchor(anchor: device)
                EventHandler.shared.updateAnchorDistance(anchorDistance)

                let worldAnchorDistance = world.anchorDistanceFromOrigin(anchor: world.worldOriginAnchor)
                EventHandler.shared.updateWorldAnchorDistance(worldAnchorDistance)
            }
        }
    }
    
    @MainActor
    //This is cool
    func run(function: () async -> Void, withFrequency hz: UInt64) async {
        while true {
            if Task.isCancelled {
                return
            }
            
            // Sleep for 1 s / hz before calling the function.
            let nanoSecondsToSleep: UInt64 = NSEC_PER_SEC / hz
            do {
                try await Task.sleep(nanoseconds: nanoSecondsToSleep)
            } catch {
                // Sleep fails when the Task is cancelled. Exit the loop.
                return
            }
            
            await function()
        }
    }
    
     
}
