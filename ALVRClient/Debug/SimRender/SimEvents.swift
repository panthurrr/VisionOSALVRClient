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
            autoreleasepool {
                 self.renderSimFrame()
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
    
    @MainActor
    func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
        deviceLocation.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
        print("Device location transformed")
    }
    
    @MainActor
    func select(_ origin: ImmersionOrigin?) {
        
        // But will this actually select?
        placementState.selectedOrigin = origin
    //    appState?.selectedFileName = origin?.descriptor.fileName
//        
//        if let origin {
//            // Add new preview entity.
//            placementLocation.addChild(origin.previewEntity)
//        }
    }
    
    @MainActor
    func getOrigin() {
        let object = placeableOriginsByFileName["Scene"]
        select(object)
    }
    
    @MainActor
    func placeSelectedOrigin(_ deviceAnchor: DeviceAnchor) {
        // Ensure there’s a placeable origin.
        self.getOrigin()
        
        guard let originToPlace = placementState.originToPlace else {
            print("No originToPlace")
            return }

        // Using device location's entity placement and location for now
        // Will need to update to not use Entity if possible
        let origin = originToPlace.materialize(Date())
//        origin.position = placementLocation.position
//        origin.orientation = placementLocation.orientation
        origin.position = deviceLocation.position
        origin.orientation = deviceLocation.orientation
        print("Device pos: \(deviceLocation.position)")
        print("Device ori: \(deviceLocation.orientation)")
        print("Origin pos: \(origin.position)")
        print("Origin ori: \(origin.orientation)")
        
//        Task {
//            await persistenceManager.attachOriginToWorldAnchor(origin)
//        }
        placementState.userPlacedAnOrigin = true
    }    
}
