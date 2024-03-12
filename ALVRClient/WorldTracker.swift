//
//  WorldTracker.swift
//

import Foundation
import ARKit
import CompositorServices
import RealityKit

class WorldTracker {
    var settings: GlobalSettings!
    
    var arSession = ARKitSession()
    var worldTracking = WorldTrackingProvider()
    var handTracking = HandTrackingProvider()
    var sceneReconstruction = SceneReconstructionProvider()
    var planeDetection = PlaneDetectionProvider()
    
    var deviceAnchorsLock = NSObject()
    var deviceAnchorsQueue = [UInt64]()
    var deviceAnchorsDictionary = [UInt64: simd_float4x4]()
    
    // Immersion center anchor
    var initialCenterSet: Bool = false
    var anchoredOrigins: [UUID: PlacedOrigin] = [:]
    let originDatabaseFileName: String = "persistentOrigins.json"
    var persistedOriginFileNamePerAnchor: [UUID: OriginData] = [:]
    var placeableOriginsByFileName: [String: ImmersionOrigin] = [:]
  /// var latestOrigin: UUID
    
    var placementState = PlacementState()
    var placementLocation: Entity
    var deviceLocation: Entity
    var rootEntity: Entity
    
    var originsBeingAnchored: [UUID: PlacedOrigin] = [:]
    var movingOrigins: [PlacedOrigin] = []
    let maxOriginAnchors = 4
    
    //Can't pass event handler here as it loops some errors
  //  var events = EventHandler.shared

    // Playspace and boundaries state
    var planeAnchors: [UUID: PlaneAnchor] = [:]
    
    var worldAnchors: [UUID: WorldAnchor] = [:]
    var worldTrackingAddedOriginAnchor = false
    var worldTrackingSteamVRTransform: simd_float4x4 = matrix_identity_float4x4
    var worldOriginAnchor: WorldAnchor = WorldAnchor(originFromAnchorTransform: matrix_identity_float4x4)
    var planeLock = NSObject()
    var lastUpdatedTs: TimeInterval = 0
    var crownPressCount = 0
    var sentPoses = 0
    
    var anchorCount = 0
    
    // Hand tracking
    var lastHandsUpdatedTs: TimeInterval = 0
    var lastSentHandsTs: TimeInterval = 0
    
    static let maxPrediction = 30 * NSEC_PER_MSEC
    static let deviceIdHead = alvr_path_string_to_id("/user/head")
    static let deviceIdLeftHand = alvr_path_string_to_id("/user/hand/left")
    static let deviceIdRightHand = alvr_path_string_to_id("/user/hand/right")
    static let deviceIdLeftForearm = alvr_path_string_to_id("/user/body/left_knee") // TODO: add a real forearm point?
    static let deviceIdRightForearm = alvr_path_string_to_id("/user/body/right_knee") // TODO: add a real forearm point?
    static let deviceIdLeftElbow = alvr_path_string_to_id("/user/body/left_elbow")
    static let deviceIdRightElbow = alvr_path_string_to_id("/user/body/right_elbow")
    static let appleHandToSteamVRIndex = [
        //eBone_Root
        "wrist": 1,                         //eBone_Wrist
        "thumbKnuckle": 2,                  //eBone_Thumb0
        "thumbIntermediateBase": 3,         //eBone_Thumb1
        "thumbIntermediateTip": 4,          //eBone_Thumb2
        "thumbTip": 5,                      //eBone_Thumb3
        "indexFingerMetacarpal": 6,         //eBone_IndexFinger0
        "indexFingerKnuckle": 7,            //eBone_IndexFinger1
        "indexFingerIntermediateBase": 8,   //eBone_IndexFinger2
        "indexFingerIntermediateTip": 9,    //eBone_IndexFinger3
        "indexFingerTip": 10,               //eBone_IndexFinger4
        "middleFingerMetacarpal": 11,       //eBone_MiddleFinger0
        "middleFingerKnuckle": 12,                //eBone_MiddleFinger1
        "middleFingerIntermediateBase": 13,       //eBone_MiddleFinger2
        "middleFingerIntermediateTip": 14,        //eBone_MiddleFinger3
        "middleFingerTip": 15,                    //eBone_MiddleFinger4
        "ringFingerMetacarpal": 16,         //eBone_RingFinger0
        "ringFingerKnuckle": 17,                  //eBone_RingFinger1
        "ringFingerIntermediateBase": 18,         //eBone_RingFinger2
        "ringFingerIntermediateTip": 19,          //eBone_RingFinger3
        "ringFingerTip": 20,                      //eBone_RingFinger4
        "littleFingerMetacarpal": 21,       //eBone_PinkyFinger0
        "littleFingerKnuckle": 22,                //eBone_PinkyFinger1
        "littleFingerIntermediateBase": 23,       //eBone_PinkyFinger2
        "littleFingerIntermediateTip": 24,        //eBone_PinkyFinger3
        "littleFingerTip": 25,                    //eBone_PinkyFinger4
        
        // SteamVR's 26-30 are aux bones and are done by ALVR
        
        // Special case: we want to stash these
        "forearmWrist": 26,
        "forearmArm": 27,
    ]
    static let leftHandOrientationCorrection = simd_quatf(from: simd_float3(1.0, 0.0, 0.0), to: simd_float3(-1.0, 0.0, 0.0)) * simd_quatf(from: simd_float3(1.0, 0.0, 0.0), to: simd_float3(0.0, 0.0, -1.0))
    static let rightHandOrientationCorrection = simd_quatf(from: simd_float3(0.0, 0.0, 1.0), to: simd_float3(0.0, 0.0, -1.0)) * simd_quatf(from: simd_float3(1.0, 0.0, 0.0), to: simd_float3(0.0, 0.0, 1.0))
    static let leftForearmOrientationCorrection = simd_quatf(from: simd_float3(1.0, 0.0, 0.0), to: simd_float3(0.0, 0.0, 1.0)) * simd_quatf(from: simd_float3(0.0, 1.0, 0.0), to: simd_float3(0.0, 0.0, 1.0))
    static let rightForearmOrientationCorrection = simd_quatf(from: simd_float3(1.0, 0.0, 0.0), to: simd_float3(0.0, 0.0, 1.0)) * simd_quatf(from: simd_float3(0.0, 1.0, 0.0), to: simd_float3(0.0, 0.0, 1.0))
    
    init(rootEntity: Entity) {
        self.rootEntity = rootEntity
        self.placementLocation = Entity()
        self.deviceLocation = Entity()
    }
    
    func updateWorldTracking(worldTracking: WorldTrackingProvider) {
        
    }
    
    func updateRootEntity(rootEntity: Entity) {
        self.rootEntity = rootEntity
    }
    
    func resetPlayspace() {
        guard worldTracking.state == .running else { return }
        print("Reset playspace")
        // Reset playspace state
        self.worldTrackingAddedOriginAnchor = false
        let transform = getDeviceOriginFromTransform()
        self.worldTrackingSteamVRTransform = transform
        self.worldOriginAnchor = WorldAnchor(originFromAnchorTransform: transform)
        self.lastUpdatedTs = 0
        self.crownPressCount = 0
        self.sentPoses = 0
    }
    
    // Pass in new sessions each time immersive space is opened
    @MainActor
    func initializeAr(arSession: ARKitSession, worldTracking: WorldTrackingProvider, handTracking: HandTrackingProvider, sceneReconstruction: SceneReconstructionProvider, planeDetection: PlaneDetectionProvider, settings: GlobalSettings) async  {
        self.arSession = arSession
        self.worldTracking = worldTracking
        self.handTracking = handTracking
        self.sceneReconstruction = sceneReconstruction
        self.planeDetection = planeDetection
        //self.placementManager = PlacementManager()
        print("Init AR succ")
        Task {
            await processReconstructionUpdates()
        }
        Task {
            await processPlaneUpdates()
        }
        Task {
            //Only not doing this because mixed view passes this task in
            await processWorldTrackingUpdates()
        }
        Task {
            await processHandTrackingUpdates()
        }
        Task {
            //await processDeviceAnchorUpdates()
        }
        self.settings = settings
        loadPersistedOrigins()
        resetPlayspace()
    }
    
    @MainActor
    func runARKitSession() async {
        do {
            // Run a new set of providers every time when entering the immersive space.
            try await arSession.run([worldTracking, planeDetection, sceneReconstruction, handTracking])
        } catch {
            // No need to handle the error here; the app is already monitoring the
            // session for error.
            return
        }
        
        let origin = placeableOriginsByFileName["Cone"]
        select(origin)
        
    }
    
    func stopArSession() {
        saveOriginAnchorsOriginsMapToDisk()
        print("Stopping ar session")
        arSession.stop()
    }
    
    func processReconstructionUpdates() async {
//        for await update in sceneReconstruction.anchorUpdates {
//            //let meshAnchor = update.anchor
//            //print(meshAnchor.id, meshAnchor.originFromAnchorTransform)
//        }
    }
    
    
    func processPlaneUpdates() async {
        for await update in planeDetection.anchorUpdates {
            //print(update.event, update.anchor.classification, update.anchor.id, update.anchor.description)
            if update.anchor.classification == .window {
                // Skip planes that are windows.
                continue
            }
            switch update.event {
            case .added, .updated:
                updatePlane(update.anchor)
            case .removed:
                removePlane(update.anchor)
            }
        
        }
    }
    
    func anchorDistanceFromOrigin(anchor: WorldAnchor) -> Float {
        guard worldTracking.state == .running else { return -1 }
        let pos = anchor.originFromAnchorTransform.columns.3
        return simd_distance(matrix_identity_float4x4.columns.3, pos)
    }
    
    func deviceDistanceFromAnchor(anchor: DeviceAnchor) -> Float {
        guard worldTracking.state == .running else { return -1 }
        
        let pos = anchor.originFromAnchorTransform.columns.3
        return simd_distance(matrix_identity_float4x4.columns.3, pos)
    }
    
    func deviceDistanceFromCenter(anchor: DeviceAnchor) -> Float {
        let pos = anchor.originFromAnchorTransform.columns.3
        return simd_distance(self.worldOriginAnchor.originFromAnchorTransform.columns.3, pos)
    }
    
    func getDevice() -> DeviceAnchor? {
        return queryDevice(CACurrentMediaTime())
    }
    
    func queryDevice(_ time: TimeInterval) -> DeviceAnchor? {
        guard worldTracking.state == .running else { return nil }
        return worldTracking.queryDeviceAnchor(atTimestamp: time)
    }
    
    
    func getDeviceOriginFromTransform() -> matrix_float4x4 {
        return getDevice()?.originFromAnchorTransform ?? matrix_identity_float4x4
    }
    
    func queryDeviceDistanceFromAnchor() async -> Float {
        // Device anchors are only available when the provider is running.
        guard worldTracking.state == .running else {
            print("Missing world Tracker")
            return -1
        }
        let deviceAnchor = queryDevice(CACurrentMediaTime())
        return deviceDistanceFromAnchor(anchor: deviceAnchor!)
        
    }
    
    func createCenterAnchor(_ deviceAnchor: DeviceAnchor) {
        
    }
    
    func setCenter() {
        setCenter(getDevice())
    }
    
    func setCenter(_ deviceAnchor: DeviceAnchor?) {
        if let deviceAnchor {
            let transform = deviceAnchor.originFromAnchorTransform
            Task {
                await updatePlacementLocation(deviceAnchor)
                await placeSelectedOrigin(deviceAnchor)
                
            }
            self.worldOriginAnchor = WorldAnchor(originFromAnchorTransform: transform)
//            self.worldTrackingSteamVRTransform =
            self.worldTrackingAddedOriginAnchor = true

        }
    }
    
    struct OriginData : Codable {
        let fileName: String
        let date: Date
    }
    
    func saveOriginAnchorsOriginsMapToDisk() {
        var originAnchorsToTypes: [UUID: OriginData] = [:]
        let sortedAnchoredOrigins = anchoredOrigins.sorted { $0.value.date < $1.value.date }
        let latestAnchoredOrigins = Dictionary(uniqueKeysWithValues: sortedAnchoredOrigins.suffix(maxOriginAnchors))
        for (anchorID, originData) in latestAnchoredOrigins {
            print("Saving \(anchorID) - \(originData.date)")
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
            persistedOriginFileNamePerAnchor = try decoder.decode([UUID: OriginData].self, from: data)
        } catch {
            print("Failed to restore the mapping from world anchors to persisted origins.")
        }
    }
    
    @MainActor
    func processDeviceAnchorUpdates() async {
        print("processing device anchor updates ever 90 hz")
        
        await EventHandler.shared.run(function: self.queryAndProcessLatestDeviceAnchor, withFrequency: 90)
    }
    
    @MainActor
    private func queryAndProcessLatestDeviceAnchor() async {
        // Device anchors are only available when the provider is running.
        guard worldTracking.state == .running else { return }
        
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())

        
        placementState.deviceAnchorPresent = deviceAnchor != nil
        placementState.planeAnchorsPresent = true
        placementState.selectedOrigin?.previewEntity.isEnabled = placementState.shouldShowPreview
        
        guard let deviceAnchor, deviceAnchor.isTracked else { return }
        
//        await updateUserFacingUIOrientations(deviceAnchor)
//        await checkWhichOriginDeviceIsPointingAt(deviceAnchor)
        await updatePlacementLocation(deviceAnchor)
    }
    
    @MainActor
    func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
        deviceLocation.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
     //   print("Device location transformed")
        
        let originFromUprightDeviceAnchorTransform = deviceAnchor.originFromAnchorTransform//.gravityAligned
        
        let distanceFromDeviceAnchor: Float = 0.5
        let downwardsOffset: Float = 0.3
        
        var uprightDeviceAnchorFromOffsetTransform = matrix_identity_float4x4
        uprightDeviceAnchorFromOffsetTransform.translation = [0, -downwardsOffset, -distanceFromDeviceAnchor]
        let originFromOffsetTransform = originFromUprightDeviceAnchorTransform * uprightDeviceAnchorFromOffsetTransform
        
        placementLocation.transform = Transform(matrix: originFromOffsetTransform)
    
        //plane to project on found is the important part for placement ?
        placementState.planeToProjectOnFound = true
        
    }
    
    @MainActor
    func select(_ origin: ImmersionOrigin?) {
        if let oldSelection = placementState.selectedOrigin {
            // Remove the current preview entity.
            placementLocation.removeChild(oldSelection.previewEntity)

            // Handle deselection. Selecting the same object again in the app deselects it.
//            if oldSelection.descriptor.fileName == origin?.descriptor.fileName {
//                select(nil)
//                return
//            }
        }
        placementState.selectedOrigin = origin
        //This line gives us trouble when making a second world tracker
        EventHandler.shared.selectedFileName = (origin?.descriptor.fileName)!

        if let origin {
            // Add new preview entity.
            placementLocation.addChild(origin.previewEntity)
        }
    }
    
    @MainActor
    func getOrigin() {
        let object = placeableOriginsByFileName["Cone"]
        select(object)
    }
    
    @MainActor
    func placeSelectedOrigin(_ deviceAnchor: DeviceAnchor) {
        // Ensure there’s a placeable origin.
        self.getOrigin()
        guard let originToPlace = placementState.originToPlace else { return }

        let origin = originToPlace.materialize(Date())
//        origin.position = placementLocation.position
//        origin.orientation = placementLocation.orientation
        origin.position = deviceLocation.position
        origin.orientation = deviceLocation.orientation
        
        Task {
            await attachOriginToWorldAnchor(origin)
        }
        placementState.userPlacedAnOrigin = true
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
            print("Attached origin \(origin.fileName): \(anchor.id) - \(CACurrentMediaTime())")
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
    
    
    
    func removeAnchorWithID(_ uuid: UUID) async {
        do {
            try await self.worldTracking.removeAnchor(forID: uuid)
        } catch {
            print("Failed to delete world anchor \(uuid) with error \(error).")
        }
    }
    
    func removeAllAnchors()  {
        Task {
            for await update in worldTracking.anchorUpdates {
                
                switch update.event {
                case .added, .updated:
                    await self.removeAnchorWithID(update.anchor.id)
                case .removed:
                    anchorCount+=1
                    print("Removed \(anchorCount) - \(update.anchor.id)")
                }
            }
        }
    }
    
    @MainActor
    func deleteAnchorsForAnchoredOrigins() async {
        print("DeleteAnchorsForAnchoredOrigins")
        for anchorID in anchoredOrigins.keys {
            await removeAnchorWithID(anchorID)
        }
    }
    
    @MainActor
    func attachPersistedOriginToAnchor(_ persistedOrigin: OriginData, anchor: WorldAnchor) {
        guard let placeableOrigin = placeableOriginsByFileName[persistedOrigin.fileName] else {
            print("No origin available for '\(persistedOrigin.date)' - it will be ignored.")
            return
        }
        print("Attaching persisted origin: \(persistedOrigin.fileName) from date: \(persistedOrigin.date) - \(anchor.id)")

        let origin = placeableOrigin.materialize(persistedOrigin.date)
        origin.position = anchor.originFromAnchorTransform.translation
        origin.orientation = anchor.originFromAnchorTransform.rotation
        origin.isEnabled = anchor.isTracked        
        rootEntity.addChild(origin)
        
        anchoredOrigins[anchor.id] = origin
    }
    
    // We have an origin anchor which we use to maintain SteamVR's positions
    // every time visionOS's centering changes.
    @MainActor
    func processWorldTrackingUpdates() async {
       // guard worldTracking.state == .running else { return }
        for await update in worldTracking.anchorUpdates {
            let anchor = update.anchor

            if update.event != .removed {
                worldAnchors[anchor.id] = anchor
            } else {
                worldAnchors.removeValue(forKey: anchor.id)
            }
            
            switch update.event {
            case .added:
                
//                if let persistedObjectFileName = persistedObjectFileNamePerAnchor[anchor.id] {
//                    attachPersistedObjectToAnchor(persistedObjectFileName, anchor: anchor)
//                }
                if let persistedOriginFileName = persistedOriginFileNamePerAnchor[anchor.id] {
                    attachPersistedOriginToAnchor(persistedOriginFileName, anchor: anchor)
                } else if let originBeingAnchored = originsBeingAnchored[anchor.id] {
                    originsBeingAnchored.removeValue(forKey: anchor.id)
                    anchoredOrigins[anchor.id] = originBeingAnchored
                    print("Displaying origin \(originBeingAnchored.fileName)")
                    // Now that the anchor has been successfully added, display the object.
                    EventHandler.shared.rootEntity.addChild(originBeingAnchored)
                    //Only display object once added to rootEntity
                    //self.worldTrackingSteamVRTransform = anchor.originFromAnchorTransform
                } else {
                    if anchoredOrigins[anchor.id] == nil {
                        Task {
                            // Immediately delete world anchors for which no placed object is known.
                            print("No object is attached to anchor \(anchor.id) - it can be deleted.")
                            await removeAnchorWithID(anchor.id)
                        }
                    }
                }
                
                fallthrough
//            case .updated:
                // This checks every world anchor
                // Check for prior world anchors
//                let anchor = update.anchor
//                if let originType = PersistenceManager.shared.persistedOriginDataPerAnchor[anchor.id] {
//                    await PersistenceManager.shared.attachPersistedOriginToAnchor(originType, anchor: anchor)
//                } else if let originBeingAnchored = PersistenceManager.shared.originsBeingAnchored[anchor.id] {
//                    PersistenceManager.shared.originsBeingAnchored.removeValue(forKey: anchor.id)
//                    PersistenceManager.shared.anchoredOrigins[anchor.id] = originBeingAnchored
//                    //Display Origin (we don't need to display)
//                }
                
         //       worldAnchors[anchor.id] = anchor
//                if !self.worldTrackingAddedOriginAnchor {
//                    print("Early origin anchor?", anchorDistanceFromOrigin(anchor: update.anchor), "Current Origin,", self.worldOriginAnchor.id)
//                    
//                    // If we randomly get an anchor added within 3.5m, consider that our origin
//                    // What would randomly cause an ahcor
//                    if anchorDistanceFromOrigin(anchor: update.anchor) < 3.5 {
//                        print("Set new origin!")
//                        
//                        // This has a (positive) minor side-effect: all redundant anchors within 3.5m will get cleaned up,
//                        // though which anchor gets chosen will be arbitrary.
//                        // But there should only be one anyway.
//                        
//                        //Setup list of anchors similar to persistence manager to store only one Origin Anchor
//                        do {
//                            try await worldTracking.removeAnchor(self.worldOriginAnchor)
//                        }
//                        catch {
//                            // don't care
//                        }
//                        
//                        worldOriginAnchor = update.anchor
//                        self.worldTrackingAddedOriginAnchor = true
//                    }
//                }
//                
//                if update.anchor.id == worldOriginAnchor.id {
//                    self.worldOriginAnchor = update.anchor
//                    
//                    // This seems to happen when headset is removed, or on app close.
//                    if !update.anchor.isTracked {
//                        // print("Headset removed?")
//                        //EventHandler.shared.handleHeadsetRemoved()
//                        //resetPlayspace()
//                        continue
//                    }
//                    
//                    let anchorTransform = update.anchor.originFromAnchorTransform
//                    if settings.keepSteamVRCenter {
//                        self.worldTrackingSteamVRTransform = anchorTransform
//                    }
//                    
//                    //Crown-press doesn't work for me?
//                    // Crown-press shenanigans
//                    if update.event == .updated {
//                        let sinceLast = update.timestamp - lastUpdatedTs
//                        if sinceLast < 3.0 && sinceLast > 0.5 {
//                            crownPressCount += 1
//                        }
//                        else {
//                            crownPressCount = 0
//                        }
//                        lastUpdatedTs = update.timestamp
//                        
//                        // Triple-press crown to purge nearby anchors and recenter
//                        if crownPressCount >= 2 {
//                            print("Reset world origin!")
//                            
//                            // Purge all existing world anchors within 3.5m
//                            for anchorPurge in worldAnchors {
//                                do {
//                                    if anchorDistanceFromOrigin(anchor: update.anchor) < 3.5 {
//                                        guard worldTracking.state == .running else { break }
//                                        try await worldTracking.removeAnchor(anchorPurge.value)
//                                    }
//                                }
//                                catch {
//                                    // don't care
//                                }
//                                worldAnchors.removeValue(forKey: anchorPurge.key)
//                            }
//                            
//                            let device = getDevice()
//                            if (device != nil) {
//                                //Use device for origin to track distance traveled
//                                self.worldOriginAnchor = WorldAnchor(originFromAnchorTransform: device!.originFromAnchorTransform)
//                            } else {
//                                self.worldOriginAnchor = WorldAnchor(originFromAnchorTransform: matrix_identity_float4x4)
//                            }
//                            self.worldTrackingAddedOriginAnchor = true
//                            if settings.keepSteamVRCenter {
//                                self.worldTrackingSteamVRTransform = anchorTransform
//                            }
//                            
//                            do {
//                                
//                                try await worldTracking.addAnchor(self.worldOriginAnchor)
//                            }
//                            catch {
//                                // don't care
//                            }
//                            
//                            crownPressCount = 0
//                        }
//                    }
//                }
            case .updated:
                //Is the update where I need to fix recentering?
                if anchor.id == worldOriginAnchor.id {
                    self.worldOriginAnchor = anchor
                    self.worldTrackingAddedOriginAnchor = true
                }
                let origin = anchoredOrigins[anchor.id]
                origin?.position = anchor.originFromAnchorTransform.translation
                origin?.orientation = anchor.originFromAnchorTransform.rotation
                origin?.isEnabled = anchor.isTracked
                
                break
            case .removed:
                let origin = anchoredOrigins[anchor.id]
                origin?.removeFromParent()
                anchoredOrigins.removeValue(forKey: anchor.id)
            }
        }
    }
    
    func processHandTrackingUpdates() async {
        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                lastHandsUpdatedTs = update.timestamp
                break
            case .removed:
                break
            }
        }
    }
    
    func updatePlane(_ anchor: PlaneAnchor) {
        lockPlaneAnchors()
        planeAnchors[anchor.id] = anchor
        unlockPlaneAnchors()
    }
    
    func removePlane(_ anchor: PlaneAnchor) {
        lockPlaneAnchors()
        planeAnchors.removeValue(forKey: anchor.id)
        unlockPlaneAnchors()
    }
    
    func lockPlaneAnchors() {
        objc_sync_enter(planeLock)
    }
    
    func unlockPlaneAnchors() {
        objc_sync_exit(planeLock)
    }
    
    // Wrist-only pose
    func handAnchorToPoseFallback(_ hand: HandAnchor) -> AlvrPose {
        let transform = self.worldTrackingSteamVRTransform.inverse * hand.originFromAnchorTransform
        var orientation = simd_quaternion(transform)
        if hand.chirality == .right {
            orientation = orientation * WorldTracker.rightHandOrientationCorrection
        }
        else {
            orientation = orientation * WorldTracker.leftHandOrientationCorrection
        }
        let position = transform.columns.3
        let pose = AlvrPose(orientation: AlvrQuat(x: orientation.vector.x, y: orientation.vector.y, z: orientation.vector.z, w: orientation.vector.w), position: (position.x, position.y, position.z))
        return pose
    }
    
    // Palm pose for controllers
    func handAnchorToPose(_ hand: HandAnchor) -> AlvrPose {
        // Fall back to wrist pose
        guard let skeleton = hand.handSkeleton else {
            return handAnchorToPoseFallback(hand)
        }
        
        let middleMetacarpal = skeleton.joint(.middleFingerMetacarpal)
        let middleProximal = skeleton.joint(.middleFingerKnuckle)
        let wrist = skeleton.joint(.wrist)
        let middleMetacarpalTransform = self.worldTrackingSteamVRTransform.inverse * hand.originFromAnchorTransform * middleMetacarpal.anchorFromJointTransform
        let middleProximalTransform = self.worldTrackingSteamVRTransform.inverse * hand.originFromAnchorTransform * middleProximal.anchorFromJointTransform
        let wristTransform = self.worldTrackingSteamVRTransform.inverse * hand.originFromAnchorTransform * wrist.anchorFromJointTransform
        
        // Use the OpenXR definition of the palm, middle point between middle metacarpal and proximal.
        let middleMetacarpalPosition = middleMetacarpalTransform.columns.3
        let middleProximalPosition = middleProximalTransform.columns.3
        let position = (middleMetacarpalPosition + middleProximalPosition) / 2.0
        
        var orientation = simd_quaternion(wristTransform)
        if hand.chirality == .right {
            orientation = orientation * WorldTracker.rightHandOrientationCorrection
        }
        else {
            orientation = orientation * WorldTracker.leftHandOrientationCorrection
        }
        
        let pose = AlvrPose(orientation: AlvrQuat(x: orientation.vector.x, y: orientation.vector.y, z: orientation.vector.z, w: orientation.vector.w), position: (position.x, position.y, position.z))
        return pose
    }
    
    func handAnchorToAlvrDeviceMotion(_ hand: HandAnchor) -> AlvrDeviceMotion {
        let device_id = hand.chirality == .left ? WorldTracker.deviceIdLeftHand : WorldTracker.deviceIdRightHand
        
        let pose = handAnchorToPose(hand)
        return AlvrDeviceMotion(device_id: device_id, pose: pose, linear_velocity: (0, 0, 0), angular_velocity: (0, 0, 0))
    }
    
    func handAnchorToSkeleton(_ hand: HandAnchor) -> [AlvrPose]? {
        var ret: [AlvrPose] = []
        
        guard let skeleton = hand.handSkeleton else {
            return nil
        }
        let rootAlvrPose = handAnchorToPose(hand)
        let rootOrientation = simd_quatf(ix: rootAlvrPose.orientation.x, iy: rootAlvrPose.orientation.y, iz: rootAlvrPose.orientation.z, r: rootAlvrPose.orientation.w)
        let rootPosition = simd_float3(x: rootAlvrPose.position.0, y: rootAlvrPose.position.1, z: rootAlvrPose.position.2)
        let rootPose = AlvrPose(orientation: AlvrQuat(x: rootOrientation.vector.x, y: rootOrientation.vector.y, z: rootOrientation.vector.z, w: rootOrientation.vector.w), position: (rootPosition.x, rootPosition.y, rootPosition.z))
        for i in 0...25+2 {
            ret.append(rootPose)
        }
        
        // Apple has two additional joints: forearmWrist and forearmArm
        for joint in skeleton.allJoints {
            let steamVrIdx = WorldTracker.appleHandToSteamVRIndex[joint.name.description, default:-1]
            if steamVrIdx == -1 || steamVrIdx >= 28 {
                continue
            }
            let transformRaw = self.worldTrackingSteamVRTransform.inverse * hand.originFromAnchorTransform * joint.anchorFromJointTransform
            let transform = transformRaw
            var orientation = simd_quaternion(transform) * simd_quatf(from: simd_float3(1.0, 0.0, 0.0), to: simd_float3(0.0, 0.0, 1.0))
            if hand.chirality == .right {
                orientation = orientation * simd_quatf(from: simd_float3(0.0, 0.0, 1.0), to: simd_float3(0.0, 0.0, -1.0))
            }
            else {
                orientation = orientation * simd_quatf(from: simd_float3(1.0, 0.0, 0.0), to: simd_float3(-1.0, 0.0, 0.0))
            }
            
            // Make wrist/elbow trackers face outward
            if steamVrIdx == 26 || steamVrIdx == 27 {
                if hand.chirality == .right {
                    orientation = orientation * WorldTracker.rightForearmOrientationCorrection
                }
                else {
                    orientation = orientation * WorldTracker.leftForearmOrientationCorrection
                }
            }
            var position = transform.columns.3
            // Move wrist/elbow slightly outward so that they appear to be on the surface of the arm,
            // instead of inside it.
            if steamVrIdx == 26 || steamVrIdx == 27 {
                position += transform.columns.1 * (0.025 * (hand.chirality == .right ? 1.0 : -1.0))
            }
            let pose = AlvrPose(orientation: AlvrQuat(x: orientation.vector.x, y: orientation.vector.y, z: orientation.vector.z, w: orientation.vector.w), position: (position.x, position.y, position.z))
            
            ret[steamVrIdx] = pose
        }
        
        return ret
    }
    
    // TODO: figure out how stable Apple's predictions are into the future
    
    func sendTracking(targetTimestamp: Double) {
        var targetTimestampWalkedBack = targetTimestamp
        var deviceAnchor:DeviceAnchor? = nil
        
        // Predict as far into the future as Apple will allow us.
        for _ in 0...20 {
            deviceAnchor = queryDevice(targetTimestampWalkedBack)
            if deviceAnchor != nil {
                break
            }
            targetTimestampWalkedBack -= (5/1000.0)
        }
        
        // Fallback.
        if deviceAnchor == nil {
            targetTimestampWalkedBack = CACurrentMediaTime()
            deviceAnchor = queryDevice(targetTimestamp)
        }
        
        // Well, I'm out of ideas.
        guard let deviceAnchor = deviceAnchor else {
            // Prevent audio crackling issues
            if sentPoses > 30 {
                EventHandler.shared.handleHeadsetRemoved()
                //resetPlayspace()
            }
            return
        }
        
        // This is kinda fiddly: worldTracking doesn't have a way to get a list of existing anchors,
        // and addAnchor only works while fully immersed mode is fully running.
        // So we have to sandwich it in here where we know worldTracking is online.
        //
        // That aside, if we add an anchor at (0,0,0), we will get reports in processWorldTrackingUpdates()
        // every time the user recenters.
        // Is this necessary with setCenter()
        if !self.worldTrackingAddedOriginAnchor && sentPoses > 300 {
            self.worldTrackingAddedOriginAnchor = true
            print("SendTracking based update")
            Task {
                do {
                    try await worldTracking.addAnchor(self.worldOriginAnchor)
                }
                catch {
                    // don't care
                }
            }
        }
        sentPoses += 1
        
        let targetTimestampNS = UInt64(targetTimestampWalkedBack * Double(NSEC_PER_SEC))
        
        deviceAnchorsQueue.append(targetTimestampNS)
        if deviceAnchorsQueue.count > 1000 {
            let val = deviceAnchorsQueue.removeFirst()
            deviceAnchorsDictionary.removeValue(forKey: val)
        }
        deviceAnchorsDictionary[targetTimestampNS] = deviceAnchor.originFromAnchorTransform
        
        // Don't move SteamVR center/bounds when the headset recenters
        let transform = self.worldTrackingSteamVRTransform.inverse * deviceAnchor.originFromAnchorTransform
        
        let orientation = simd_quaternion(transform)
        let position = transform.columns.3
        let headPose = AlvrPose(orientation: AlvrQuat(x: orientation.vector.x, y: orientation.vector.y, z: orientation.vector.z, w: orientation.vector.w), position: (position.x, position.y, position.z))
        let headTrackingMotion = AlvrDeviceMotion(device_id: WorldTracker.deviceIdHead, pose: headPose, linear_velocity: (0, 0, 0), angular_velocity: (0, 0, 0))
        var trackingMotions = [headTrackingMotion]
        var skeletonLeft:[AlvrPose]? = nil
        var skeletonRight:[AlvrPose]? = nil
        
        var skeletonLeftPtr:UnsafeMutablePointer<AlvrPose>? = nil
        var skeletonRightPtr:UnsafeMutablePointer<AlvrPose>? = nil
        
        let handPoses = handTracking.latestAnchors
        if let leftHand = handPoses.leftHand {
            if leftHand.isTracked /*&& lastHandsUpdatedTs != lastSentHandsTs*/ {
                trackingMotions.append(handAnchorToAlvrDeviceMotion(leftHand))
                skeletonLeft = handAnchorToSkeleton(leftHand)
            }
        }
        if let rightHand = handPoses.rightHand {
            if rightHand.isTracked /*&& lastHandsUpdatedTs != lastSentHandsTs*/ {
                trackingMotions.append(handAnchorToAlvrDeviceMotion(rightHand))
                skeletonRight = handAnchorToSkeleton(rightHand)
            }
        }
        if let skeletonLeft = skeletonLeft {
            if skeletonLeft.count >= 28 {
                skeletonLeftPtr = UnsafeMutablePointer<AlvrPose>.allocate(capacity: 26)
                for i in 0...25 {
                    skeletonLeftPtr![i] = skeletonLeft[i]
                }
                
                trackingMotions.append(AlvrDeviceMotion(device_id: WorldTracker.deviceIdLeftForearm, pose: skeletonLeft[26], linear_velocity: (0, 0, 0), angular_velocity: (0, 0, 0)))
                trackingMotions.append(AlvrDeviceMotion(device_id: WorldTracker.deviceIdLeftElbow, pose: skeletonLeft[27], linear_velocity: (0, 0, 0), angular_velocity: (0, 0, 0)))
            }
        }
        if let skeletonRight = skeletonRight {
            if skeletonRight.count >= 28 {
                skeletonRightPtr = UnsafeMutablePointer<AlvrPose>.allocate(capacity: 26)
                for i in 0...25 {
                    skeletonRightPtr![i] = skeletonRight[i]
                }
                
                trackingMotions.append(AlvrDeviceMotion(device_id: WorldTracker.deviceIdRightForearm, pose: skeletonRight[26], linear_velocity: (0, 0, 0), angular_velocity: (0, 0, 0)))
                trackingMotions.append(AlvrDeviceMotion(device_id: WorldTracker.deviceIdRightElbow, pose: skeletonRight[27], linear_velocity: (0, 0, 0), angular_velocity: (0, 0, 0)))
            }
        }
        
        //let targetTimestampReqestedNS = UInt64(targetTimestamp * Double(NSEC_PER_SEC))
        //let currentTimeNs = UInt64(CACurrentMediaTime() * Double(NSEC_PER_SEC))
        //print("asking for:", targetTimestampNS, "diff:", targetTimestampReqestedNS&-targetTimestampNS, "diff2:", targetTimestampNS&-EventHandler.shared.lastRequestedTimestamp, "diff3:", targetTimestampNS&-currentTimeNs)
        
        EventHandler.shared.lastRequestedTimestamp = targetTimestampNS
        lastSentHandsTs = lastHandsUpdatedTs
        alvr_send_tracking(targetTimestampNS, trackingMotions, UInt64(trackingMotions.count), [UnsafePointer(skeletonLeftPtr), UnsafePointer(skeletonRightPtr)], nil)
    }
    
    func lookupDeviceAnchorFor(timestamp: UInt64) -> simd_float4x4? {
        return deviceAnchorsDictionary[timestamp]
    }
    
}
