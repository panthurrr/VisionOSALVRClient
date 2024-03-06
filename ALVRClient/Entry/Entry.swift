/*
Abstract:
The Entry content for a volume.
*/

import SwiftUI

struct Entry: View {
    @ObservedObject var eventHandler = EventHandler.shared
    @Environment(ViewModel.self) private var model
    @Binding var settings: GlobalSettings
    @Environment(\.scenePhase) private var scenePhase
    let saveAction: ()->Void

    var body: some View {
        ZStack {
            VStack {
                VStack {
                    Text("ALVR")
                        .font(.system(size: 50, weight: .bold))
                        .padding()
                    
                    Text("Options:")
                        .font(.system(size: 20, weight: .bold))
                    VStack {
                        Toggle(isOn: $settings.showHandsOverlaid) {
                            Text("Show hands overlaid")
                        }
                        .toggleStyle(.switch)
                        
                        Toggle(isOn: $settings.keepSteamVRCenter) {
                            Text("Crown Button long-press also recenters SteamVR")
                        }
                        .toggleStyle(.switch)
                    }
                    .frame(width: 450)
                    .padding()
                    
                    Text("Connection Information:")
                        .font(.system(size: 20, weight: .bold))
                    
                    if eventHandler.hostname != "" && eventHandler.IP != "" {
                        let columns = [
                            GridItem(.fixed(100), alignment: .trailing),
                            GridItem(.fixed(150), alignment: .leading)
                        ]
                        
                        LazyVGrid(columns: columns) {
                            Text("hostname:")
                            Text(eventHandler.hostname)
                            Text("IP:")
                            Text(eventHandler.IP)
                        }
                        .frame(width: 250, alignment: .center)
                    }
                } //End VStack1
                .frame(minWidth: 650, minHeight: 500)
                .frame(depth: 0.0)
                .glassBackgroundEffect()
                .onChange(of: scenePhase) {
                    switch scenePhase {
                    case .background:
                        saveAction()
                        break
                    case .inactive:
                        saveAction()
                        break
                    case .active:
                        break
                    @unknown default:
                        break
                    }
                }
                
                HStack(spacing: 17) {
                    EntryControls(saveAction: saveAction)
                    DebugControls()
                }
            } //End VStack2
            .zIndex(0)
            if (model.isShowingDebugWindow) {
                Debug()
                    .frame(width: 600, height: 400)
                    .frame(depth: 20.0)
                    .glassBackgroundEffect()
                    .zIndex(5.0)
            }

        } //End HStack
    }
}

struct Entry_Previews: PreviewProvider {
    static var previews: some View {
        Entry(settings: .constant(GlobalSettings.sampleData), saveAction: {})
    }
}
