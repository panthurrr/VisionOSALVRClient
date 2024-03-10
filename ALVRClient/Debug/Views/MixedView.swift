//
//  RealityView.swift
//  ALVRClient
//
//  Created by Chris Metrailer on 3/5/24.
//

import RealityKit
import SwiftUI
import ARKit


@MainActor
struct MixedView: View {
    @Binding var settings: GlobalSettings
    
    @State private var placementManager = PlacementManager()
    @State private var events = EventHandler.shared
    
    var body: some View {
        RealityView { content in
            if let scene = try? await Entity(named: "Immersive") {
                content.add(scene)
            }
            content.add(events.rootEntity)
            Task {
                await placementManager.runARKitSession()
            }
            
            //Run ARKit session after opened Immersive Space?
            
        }
        .task {
            await events.world.initializeAr(arSession:events.arkitSession,
                                      worldTracking: WorldTrackingProvider(),
                                      handTracking:events.handTracking,
                                      sceneReconstruction:SceneReconstructionProvider(),
                                      planeDetection:PlaneDetectionProvider(),
                                      settings:settings)
        }
        .task {
            // Remove all anchors
            // await WorldTracker.shared.removeAllAnchors()
        }
        
        //PlacementManager logic paths
        //Process world anchorupdates
        //process devic anchorupdates
        //process planedetec updates
        //checkIfAnchoredObejctsNeedDetached
        //checkIfMovingObjectsCanBeAnchored
    }

}

#Preview {
    MixedView(settings: .constant(GlobalSettings.sampleData))

}
