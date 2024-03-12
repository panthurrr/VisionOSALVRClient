//
//  GlobalSettings.swift
//

import Foundation
import SwiftUI

struct GlobalSettings: Codable {
    var keepSteamVRCenter: Bool
    var showHandsOverlaid: Bool
    var autoRecenter: Bool
    var recenterDistance: Float
    
    init(keepSteamVRCenter: Bool, showHandsOverlaid: Bool, autoRecenter: Bool, recenterDistance: Float) {
        self.keepSteamVRCenter = keepSteamVRCenter
        self.showHandsOverlaid = showHandsOverlaid
        self.autoRecenter = autoRecenter
        self.recenterDistance = recenterDistance
    }
}

extension GlobalSettings {
    static let sampleData: GlobalSettings =
    GlobalSettings(keepSteamVRCenter: true, showHandsOverlaid: true, autoRecenter: true, recenterDistance: 1.1)
}

@MainActor
class GlobalSettingsStore: ObservableObject {
    @Published var settings: GlobalSettings = GlobalSettings(keepSteamVRCenter: false, showHandsOverlaid: false, autoRecenter: true, recenterDistance: 1.1)
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        .appendingPathComponent("globalsettings.data")
    }
    
    func load() throws {
        let fileURL = try Self.fileURL()
        guard let data = try? Data(contentsOf: fileURL) else {
            return self.settings = GlobalSettings(keepSteamVRCenter: false, showHandsOverlaid: false, autoRecenter: false, recenterDistance: 1.1)
        }
        let globalSettings = try JSONDecoder().decode(GlobalSettings.self, from: data)
        self.settings = globalSettings
    }
    
    func save(settings: GlobalSettings) throws {
        let data = try JSONEncoder().encode(settings)
        let outfile = try Self.fileURL()
        try data.write(to: outfile)
    }
}
