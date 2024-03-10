/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A class which is responsible for mapping persistent world anchors to placed origins.
*/

import Foundation
import ARKit
import RealityKit

class PersistenceManager {
    var worldTracking: WorldTrackingProvider
    var anchoredOrigins: [UUID: PlacedOrigin] = [:]
    var originsBeingAnchored: [UUID: PlacedOrigin] = [:]
    var movingOrigins: [PlacedOrigin] = []
    
    let originDatabaseFileName: String = "persistentOrigins.json"
    var persistedOriginDataPerAnchor: [UUID: OriginData] = [:]
    var placeableOriginsByFileName: [String: ImmersionOrigin] = [:]
    
    // A map of world anchor UUIDs to the origins attached to them.
//    private var anchoredOrigins: [UUID: PlacedOrigin] = [:]
    
    // A map of world anchor UUIDs to the origins that are about to be attached to them.
//    private var originsBeingAnchored: [UUID: PlacedOrigin] = [:]
    
    // A list of origins that are currently not at rest (not attached to any world anchor).
//    private var movingOrigins: [PlacedOrigin] = []
    
    private let originAtRestThreshold: Float = 0.001 // 1 cm
    
    // A dictionary of all current world anchors based on the anchor updates received from ARKit.
    private var worldAnchors: [UUID: WorldAnchor] = [:]
    
    // The JSON file to store the world anchor to placed origin mapping.
//    static let originsDatabaseFileName = "persistentOrigins.json"
    
    // A dictionary of 3D model files to be loaded for a given persistent world anchor.
//    private var persistedOriginFileNamePerAnchor: [UUID: String] = [:]
    
//    var placeableOriginsByFileName: [String: PlaceableOrigin] = [:]
    
    var rootEntity: Entity
    
    init(worldTracking: WorldTrackingProvider, rootEntity: Entity) {
        self.worldTracking = worldTracking
        self.rootEntity = rootEntity
    }
    
    func updateRootEntity(_ newEntity: Entity) {
        DispatchQueue.main.async {
            self.rootEntity = newEntity
        }
    }
    
    struct OriginData : Codable {
        let fileName: String
        let date: Date
    }
    
    /// Deserialize the JSON file that contains the mapping from world anchors to placed origins from the documents directory.
    func loadPersistedOrigins() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let filePath = documentsDirectory.first?.appendingPathComponent(originDatabaseFileName)
        
        guard let filePath, FileManager.default.fileExists(atPath: filePath.path(percentEncoded: true)) else {
            print("Couldn’t find file: '\(originDatabaseFileName)' - skipping deserialization of persistent origins.")
            return
        }

        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            persistedOriginDataPerAnchor = try decoder.decode([UUID: OriginData].self, from: data)
        } catch {
            print("Failed to restore the mapping from world anchors to persisted origins.")
        }
    }
    
    /// Serialize the mapping from world anchors to placed origins to a JSON file in the documents directory.
    func saveOriginAnchorsOriginsMapToDisk() {
        var originAnchorsToTypes: [UUID: OriginData] = [:]
        for (anchorID, originData) in anchoredOrigins {
            print("Saving \(anchorID)")
            originAnchorsToTypes[anchorID] = OriginData(fileName: originData.fileName, date: originData.date)
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let jsonString = try encoder.encode(originAnchorsToTypes)
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filePath = documentsDirectory.appendingPathComponent(originDatabaseFileName)

            do {
                try jsonString.write(to: filePath)
            } catch {
                print(error)
            }
        } catch {
            print(error)
        }
    }

    @MainActor
    func attachPersistedOriginToAnchor(_ persistedOrigin: OriginData, anchor: WorldAnchor) {
        guard let placeableOrigin = placeableOriginsByFileName[persistedOrigin.fileName] else {
            print("No origin available for '\(persistedOrigin.date)' - it will be ignored.")
            return
        }
        
        let origin = placeableOrigin.materialize(persistedOrigin.date)
        origin.position = anchor.originFromAnchorTransform.translation
        origin.orientation = anchor.originFromAnchorTransform.rotation
        origin.isEnabled = anchor.isTracked
        updateRootEntity(EventHandler.shared.rootEntity)
        
        rootEntity.addChild(origin)
        
        anchoredOrigins[anchor.id] = origin
    }
    
    @MainActor
    func process(_ anchorUpdate: AnchorUpdate<WorldAnchor>) {
        let anchor = anchorUpdate.anchor
        
        if anchorUpdate.event != .removed {
            worldAnchors[anchor.id] = anchor
        } else {
            worldAnchors.removeValue(forKey: anchor.id)
        }
        
        switch anchorUpdate.event {
        case .added:
            // Check whether there’s a persisted origin attached to this added anchor -
            // it could be a world anchor from a previous run of the app.
            // ARKit surfaces all of the world anchors associated with this app
            // when the world tracking provider starts.
            
            //Process only purposefully set center origins ?
            if let originsFileName = persistedOriginDataPerAnchor[anchor.id] {
                attachPersistedOriginToAnchor(originsFileName, anchor: anchor)
            } else if let originBeingAnchored = originsBeingAnchored[anchor.id] {
                originsBeingAnchored.removeValue(forKey: anchor.id)
                anchoredOrigins[anchor.id] = originBeingAnchored
                
                // Now that the anchor has been successfully added, display the origin.
                rootEntity.addChild(originBeingAnchored)
            } else {
                if anchoredOrigins[anchor.id] == nil {
                    Task {
                        // Immediately delete world anchors for which no placed origin is known.
                        print("No origin is attached to anchor \(anchor.id) - it can be deleted.")
                        
                        //Don't actually delete yet - panther
//                        await removeAnchorWithID(anchor.id)
                    }
                }
            }
            fallthrough
        case .updated:
            // Keep the position of placed origins in sync with their corresponding
            // world anchor, and hide the origin if the anchor isn’t tracked.
            let origin = anchoredOrigins[anchor.id]
            origin?.position = anchor.originFromAnchorTransform.translation
            origin?.orientation = anchor.originFromAnchorTransform.rotation
            origin?.isEnabled = anchor.isTracked
        case .removed:
            // Remove the placed origin if the corresponding world anchor was removed.
            let origin = anchoredOrigins[anchor.id]
            origin?.removeFromParent()
            anchoredOrigins.removeValue(forKey: anchor.id)
        }
    }
    
    @MainActor
    func removeAllPlacedOrigins() async {
        // To delete all placed origins, first delete all their world anchors.
        // The placed origins will then be removed after the world anchors
        // were successfully deleted.
        await deleteWorldAnchorsForAnchoredOrigins()
    }
    
    private func deleteWorldAnchorsForAnchoredOrigins() async {
        for anchorID in anchoredOrigins.keys {
            await removeAnchorWithID(anchorID)
        }
    }
    
    func removeAnchorWithID(_ uuid: UUID) async {
        do {
            try await worldTracking.removeAnchor(forID: uuid)
        } catch {
            print("Failed to delete world anchor \(uuid) with error \(error).")
        }
    }
    
    @MainActor
    func attachOriginToWorldAnchor(_ origin: PlacedOrigin) async {
        // First, create a new world anchor and try to add it to the world tracking provider.
        let anchor = WorldAnchor(originFromAnchorTransform: origin.transformMatrix(relativeTo: nil))
        movingOrigins.removeAll(where: { $0 === origin })
        originsBeingAnchored[anchor.id] = origin
        do {
            try await worldTracking.addAnchor(anchor)
            anchoredOrigins[anchor.id] = origin
            print("Attached origin \(origin.fileName): \(anchor.id)")
        } catch {
            // Adding world anchors can fail, such as when you reach the limit
            // for total world anchors per app. Keep track
            // of all world anchors and delete any that no longer have
            // an origin attached.
            
            if let worldTrackingError = error as? WorldTrackingProvider.Error, worldTrackingError.code == .worldAnchorLimitReached {
                print(
"""
Unable to place origin "\(origin.name)". You’ve placed the maximum number of origins.
Remove old origins before placing new ones.
"""
                )
            } else {
                print("Failed to add world anchor \(anchor.id) with error: \(error).")
            }
            
            originsBeingAnchored.removeValue(forKey: anchor.id)
            origin.removeFromParent()
            return
        }
    }
    
    @MainActor
    private func detachOriginFromWorldAnchor(_ origin: PlacedOrigin) {
        guard let anchorID = anchoredOrigins.first(where: { $0.value === origin })?.key else {
            return
        }
        
        // Remove the origin from the set of anchored origins because it’s about to be moved.
        anchoredOrigins.removeValue(forKey: anchorID)
        Task {
            // The world anchor is no longer needed; remove it so that it doesn't
            // remain in the app’s list of world anchors forever.
            await removeAnchorWithID(anchorID)
        }
    }
    
    @MainActor
    func placedOrigin(for entity: Entity) -> PlacedOrigin? {
        return anchoredOrigins.first(where: { $0.value === entity })?.value
    }
    
    @MainActor
    func origin(for entity: Entity) -> PlacedOrigin? {
        if let placedOrigin = placedOrigin(for: entity) {
            return placedOrigin
        }
        if let movingOrigin = movingOrigins.first(where: { $0 === entity }) {
            return movingOrigin
        }
        if let anchoringOrigin = originsBeingAnchored.first(where: { $0.value === entity })?.value {
            return anchoringOrigin
        }
        return nil
    }
    
    @MainActor
    func removeOrigin(_ origin: PlacedOrigin) async {
        guard let anchorID = anchoredOrigins.first(where: { $0.value === origin })?.key else {
            return
        }
        await removeAnchorWithID(anchorID)
    }
    
    @MainActor
    func checkIfAnchoredOriginsNeedToBeDetached() async {
        let anchoredOriginsBeforeCheck = anchoredOrigins
        
        // Check if any wof the anchored origins is no longer at rest
        // and needs to be detached from its world anchor.
        for (anchorID, origin) in anchoredOriginsBeforeCheck {
            guard let anchor = worldAnchors[anchorID] else {
                origin.positionAtLastReanchoringCheck = origin.position(relativeTo: nil)
                movingOrigins.append(origin)
                anchoredOrigins.removeValue(forKey: anchorID)
                continue
            }
            
            let distanceToAnchor = origin.position(relativeTo: nil) - anchor.originFromAnchorTransform.translation
            
            if length(distanceToAnchor) >= originAtRestThreshold {
                origin.atRest = false
                
                origin.positionAtLastReanchoringCheck = origin.position(relativeTo: nil)
                movingOrigins.append(origin)
                detachOriginFromWorldAnchor(origin)
            }
        }
    }
    
    @MainActor
    func checkIfMovingOriginsCanBeAnchored() async {
        let movingOriginsBeforeCheck = movingOrigins
        
        // Check whether any of the nonanchored origins are now at rest
        // and can be attached to a new world anchor.
        for origin in movingOriginsBeforeCheck {
            guard !origin.isBeingDragged else { continue }
            guard let lastPosition = origin.positionAtLastReanchoringCheck else {
                origin.positionAtLastReanchoringCheck = origin.position(relativeTo: nil)
                continue
            }
            
            let currentPosition = origin.position(relativeTo: nil)
            let movementSinceLastCheck = currentPosition - lastPosition
            origin.positionAtLastReanchoringCheck = currentPosition
            
            if length(movementSinceLastCheck) < originAtRestThreshold {
                origin.atRest = true
                await attachOriginToWorldAnchor(origin)
            }
        }
    }
}
