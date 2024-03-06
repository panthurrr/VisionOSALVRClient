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
   // let saveAction: ()->Void

    var body: some View {
        @Bindable var model = model

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
                    print("Resetting Center")
                    WorldTracker.shared.setCenter()
                })
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .glassBackgroundEffect(in: .rect(cornerRadius: 50))

            //Enable Client
            .onChange(of: model.isShowingSimClient) { _, isShowing in
                Task {
                    if isShowing {
                        print("Opening Immersive Space")
                        EventHandler.shared.alvrInitialized = true
                        await openImmersiveSpace(id: "SimClient")
                     
                    } else {
                        print("Dismiss Immersive Space")
                        EventHandler.shared.alvrInitialized = false
                        await dismissImmersiveSpace()
                        print("Resetting playspace")
                        WorldTracker.shared.resetPlayspace()
                    }
                }
            }
            //Reset immersive space
            .onChange(of: eventHandler.distanceFromWorldAnchor) { _, newValue in
                if newValue > 1.5 {
                    Task {
                        print("Dismissing Immersive Space")
                        await dismissImmersiveSpace()
                        print("Resetting playspace")
                        WorldTracker.shared.resetPlayspace()
                        //await dismissImmersiveSpace()
                        print("ReOpen Immersive Space")
                        await openImmersiveSpace(id: "SimClient")
                    }
                }
            }
        }
        
    }
}

struct Debug_Previews: PreviewProvider {
    static var previews: some View {
        Debug()
    }
}
