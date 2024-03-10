/*
Abstract:
The Entry content for a volume.
*/

import SwiftUI

struct Debug: View {
    @ObservedObject var eventHandler = EventHandler.shared
   // @Binding var settings: GlobalSettings
    @Environment(ViewModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isRecentering = false
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
                Text(eventHandler.distanceFromAnchor.description)
                Text("Distance from WorldAnchor:")
                Text(eventHandler.distanceFromWorldAnchor.description)
                Text("Distance from Center:")
                Text(eventHandler.distanceFromCenter.description)
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
                    eventHandler.world.setCenter()
                })
                Toggle(isOn: $model.enableRecenter) {
                    Label("Recenter", systemImage: "visionpro")
                        .labelStyle(.titleOnly)
                        .padding(15)
                }
                Button("Remove WorldAnchors", action: {
                    print("Removing anchors")
                    eventHandler.world.removeAllAnchors()
                })
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .glassBackgroundEffect(in: .rect(cornerRadius: 50))

            //Enable Client
            .onChange(of: model.isShowingSimClient) { _, isShowing in
                Task {
                    if !isRecentering {
                        if isShowing {
                            await openingImmersiveSpace()
                        } else {
                            await dismissingImmersiveSpace()
                        }
                    }
                }
            }
            //Reset immersive space
            .onChange(of: eventHandler.distanceFromCenter) { _, newValue in
                DispatchQueue.main.async {
                    if model.isShowingSimClient && model.enableRecenter && newValue > 0.25 && !isRecentering {
                        isRecentering = true
                        if updateSem.wait(timeout: .now()) == .success {
                            Task {
                                await recenterImmersiveSpace()
                            }
                        updateSem.signal()
                        }
                    }
                }
            }
        }
        
    }
    
    func openingImmersiveSpace() async {
        print("Opening Immersive Space")
        EventHandler.shared.alvrInitialized = true
        await openImmersiveSpace(id: "Mixed")
        EventHandler.shared.streamingActive = true
        eventHandler.world.resetPlayspace()
        eventHandler.world.setCenter()
    }
    
    func dismissingImmersiveSpace() async {
        print("Manual dismiss Immersive Space")
        EventHandler.shared.alvrInitialized = false
        EventHandler.shared.streamingActive = true
        await dismissImmersiveSpace()
        eventHandler.world.stopArSession()
    }
    
    func recenterImmersiveSpace() async {
        model.enableRecenter = false
        print("Resetting playspace")
        eventHandler.world.resetPlayspace()
        EventHandler.shared.streamingActive = false
        print("Recenter dismiss Immersive Space")
        model.isShowingSimClient = false
        await dismissImmersiveSpace()
  //      PlacementManager.shared.persistenceManager.saveOriginAnchorsOriginsMapToDisk()
        await openImmersiveSpace(id: "Mixed")
        model.isShowingSimClient = true
        EventHandler.shared.alvrInitialized = true
        EventHandler.shared.streamingActive = true
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        eventHandler.world.resetPlayspace()
        eventHandler.world.setCenter()
        isRecentering = false
    }
}

struct Debug_Previews: PreviewProvider {
    static var previews: some View {
        Debug()
    }
}
