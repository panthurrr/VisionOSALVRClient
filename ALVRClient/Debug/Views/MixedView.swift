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
    
   // @State private var placementManager = PlacementManager()
    @State private var events = EventHandler.shared
    
    var body: some View {
        RealityView { content in
//            if let scene = try? await Entity(named: "Immersive") {
//                content.add(scene)
//            }
            //Most likely needing to change THIS rootEntity to a new one each time
            
            content.add(events.world.rootEntity)
            
            Task {
                await events.world.runARKitSession()
            }
            
            //Run ARKit session after opened Immersive Space?
            
        }
        .task {
          // events.reset()
        }
        .task {
            await events.world.initializeAr(arSession:ARKitSession(),
                                      worldTracking: WorldTrackingProvider(),
                                      handTracking:HandTrackingProvider(),
                                      sceneReconstruction:SceneReconstructionProvider(),
                                      planeDetection:PlaneDetectionProvider(),
                                      settings:settings)
        }
        .task {
            if settings.autoRecenter {
                await events.world.processWorldTrackingUpdatesRecentering()
            } else {
                await events.world.processWorldTrackingUpdates()
            }
        }
        .task {
            await events.world.processDeviceAnchorUpdates()
        }
        .task {
       //     events.world.removeAllAnchors()
          //  await events.world.deleteAnchorsForAnchoredOrigins()

        }
//        .onAppear() {
//            events.immersiveSpaceOpened(with: placementManager)
//        }
        
    }

}

#Preview {
    MixedView(settings: .constant(GlobalSettings.sampleData))

}
