/*
Abstract:
The Entry content for a volume.
*/

import SwiftUI
import ARKit

struct Debug: View {
    @Binding var settings: GlobalSettings
    @ObservedObject var events = EventHandler.shared
   // @Binding var settings: GlobalSettings
    @Environment(ViewModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isRecentering = false
    let modelDescriptors: [ModelDescriptor]
    var selectedFileName: String? = nil
    var selectionHandler: ((ModelDescriptor) -> Void)? = nil
    @State private var recenterCount = 0


   // let saveAction: ()->Void

    var body: some View {
        @Bindable var model = model
        
        let updateSem = DispatchSemaphore(value: 1)

        
        VStack {
            Text("Debug Menu")
                .font(.system(size: 50, weight: .bold))
                .padding()

            
            Text("Debug Information:")
                .font(.system(size: 20, weight: .bold))
            
            let columns = [
                GridItem(alignment: .trailing),
                GridItem(alignment: .leading)
            ]

            LazyVGrid(columns: columns) {
                Text("Distance from Anchor:")
                Text(events.distanceFromAnchor.description)
                Text("Distance from WorldAnchor:")
                Text(events.distanceFromWorldAnchor.description)
                Text("Distance from Center:")
                Text(events.distanceFromCenter.description)
            }
            .frame(alignment: .center)
            
            HStack(spacing: 17) {
                Toggle(isOn: $model.isShowingSimClient) {
                        Label("Enter", systemImage: "visionpro")
                            .labelStyle(.titleAndIcon)
                            .padding(15)
                }
                Button("Set Center", action: {
                    print("Setting Center")
                    events.world.setCenter()
                })
                Toggle(isOn: $model.enableRecenter) {
                    Label("Recenter", systemImage: "visionpro")
                        .labelStyle(.titleOnly)
                        .padding(15)
                }
                Button("Remove WorldAnchors", action: {
                    print("Removing anchors")
                    events.world.removeAllAnchors()
                    Task {
                        await events.world.deleteAnchorsForAnchoredOrigins()
                    }
                })
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .glassBackgroundEffect(in: .rect(cornerRadius: 50))
            
            
            VStack(spacing: 20) {
                Text("Choose an object to place:")
                    .padding(10)

                Grid {
                    ForEach(0 ..< ((modelDescriptors.count + 1) / 2), id: \.self) { row in
                        GridRow {
                            ForEach(0 ..< 2, id: \.self) { column in
                                let descriptorIndex = row * 2 + column
                                if descriptorIndex < modelDescriptors.count {
                                    let descriptor = modelDescriptors[descriptorIndex]
                                    Toggle(isOn: binding(for: descriptor)) {
                                        Text(descriptor.displayName)
                                            .frame(maxWidth: .infinity, minHeight: 40)
                                            .lineLimit(1)
                                    }
                                    .toggleStyle(.button)
                                }
                            }
                        }
                    }
                }
            }

            //Enable Client
            .onChange(of: model.isShowingSimClient) { _, isShowing in
                if !events.isRecentering {
                    if isShowing {
                        openingImmersiveSpace()
                    } else {
                        dismissingImmersiveSpace()
                    }
                }
                
            }
            //Reset immersive space
            .onChange(of: events.distanceFromCenter) { _, newValue in
                DispatchQueue.main.async {
                    if model.isShowingSimClient && model.enableRecenter && newValue > 0.2 && !events.isRecentering {
                        if updateSem.wait(timeout: .now()) == .success {
                            recenterImmersiveSpace()
                            updateSem.signal()
                        }
                    }
                }
            }
        }
        
    }
    
    private func binding(for descriptor: ModelDescriptor) -> Binding<Bool> {
        Binding<Bool>(
            get: { selectedFileName == descriptor.fileName },
            set: { _ in
                if let selectionHandler {
                    selectionHandler(descriptor)
                }
            }
        )
    }
    
    func openingImmersiveSpace() {
        Task {
            if (model.immersiveSpaceID != "Mixed") {
                print("Initialize via Debug page")
                await events.world.initializeAr(arSession:ARKitSession(),
                                                worldTracking: WorldTrackingProvider(),
                                                handTracking:HandTrackingProvider(),
                                                sceneReconstruction:SceneReconstructionProvider(),
                                                planeDetection:PlaneDetectionProvider(),
                                                settings:settings)
                await events.world.runARKitSession()
            }
            print("Manually opened Immersive Space")
            events.alvrInitialized = true
            await openImmersiveSpace(id: model.immersiveSpaceID)
            events.streamingActive = true
            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            events.world.resetPlayspace()
            events.world.setCenter()
        }
    }
  
    
    func dismissingImmersiveSpace() {
        Task {
            print("Manual dismiss Immersive Space")
            events.alvrInitialized = false
            events.streamingActive = true
            await dismissImmersiveSpace()
            events.reset()
        }
    }
    
    func recenterImmersiveSpace() {
        Task {
            model.enableRecenter = false
            recenterCount+=1
//            print("Resetting playspace")
//            events.world.resetPlayspace()
            events.streamingActive = false
            print("Recenter dismiss Immersive Space \(recenterCount)")
            model.isShowingSimClient = false
            await dismissImmersiveSpace()
            events.reset()
            if (model.immersiveSpaceID != "Mixed") {
                print("Initialize via Debug page")
                await events.world.initializeAr(arSession:ARKitSession(),
                                                worldTracking: WorldTrackingProvider(),
                                                handTracking:HandTrackingProvider(),
                                                sceneReconstruction:SceneReconstructionProvider(),
                                                planeDetection:PlaneDetectionProvider(),
                                                settings:settings)
                await events.world.runARKitSession()
            }
            await openImmersiveSpace(id: model.immersiveSpaceID)
            model.isShowingSimClient = true
            events.alvrInitialized = true
            events.streamingActive = true
            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            events.world.resetPlayspace()
            events.world.setCenter()
            isRecentering = false
        }
    }
}

struct Debug_Previews: PreviewProvider {
    static var previews: some View {
        Debug(settings: .constant(GlobalSettings.sampleData), modelDescriptors: EventHandler.shared.modelDescriptors)
    }
}
