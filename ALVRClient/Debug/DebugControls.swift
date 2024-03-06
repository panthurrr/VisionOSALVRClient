/*
Abstract:
Controls that allow entry into the ALVR environment.
*/

import SwiftUI

/// Controls that allow entry into the ALVR environment.
struct DebugControls: View {
    @Environment(ViewModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @ObservedObject var eventHandler = EventHandler.shared
    //let saveAction: ()->Void
    
    var body: some View {
        @Bindable var model = model
        
        HStack(spacing: 17) {
            if model.isDebugMode {
                Toggle(isOn: $model.isShowingDebugWindow) {
                    Label("Debug", systemImage: "gear")
                        .labelStyle(.titleAndIcon)
                        .padding(15)
                }
            }
            
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .glassBackgroundEffect(in: .rect(cornerRadius: 50))

        //Enable Debug Window
        

    }
}


#Preview {
    DebugControls()
        .environment(ViewModel())
}
