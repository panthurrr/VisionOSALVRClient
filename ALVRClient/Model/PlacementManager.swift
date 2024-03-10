/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The view model for the immersive space.
*/

import Foundation
import ARKit
import RealityKit
import QuartzCore
import SwiftUI

@Observable
final class PlacementManager {
   // static let shared = PlacementManager()
    let planeDetection = PlaneDetectionProvider()
    
    let worldTracking = WorldTrackingProvider()
  //  private var planeAnchorHandler: PlaneAnchorHandler
    var persistenceManager: PersistenceManager
    
//    var appState: AppState? = nil {
//        didSet {
//            persistenceManager.placeableOriginsByFileName = appState?.placeableOriginsByFileName ?? [:]
//        }
//    }

    private var currentDrag: DragState? = nil {
        didSet {
            placementState.dragInProgress = currentDrag != nil
        }
    }
    
    var placementState = PlacementState()

    var rootEntity: Entity
    var events = EventHandler.shared
    private let deviceLocation: Entity
    private let raycastOrigin: Entity
    private let placementLocation: Entity
    private weak var placementTooltip: Entity? = nil
    weak var dragTooltip: Entity? = nil
    weak var deleteButton: Entity? = nil
    
    // Place origins on planes with a small gap.
    static private let placedOriginsOffsetOnPlanes: Float = 0.01
    
    // Snap dragged origins to a nearby horizontal plane within +/- 4 centimeters.
    static private let snapToPlaneDistanceForDraggedOrigins: Float = 0.04
    
    init() {
        let root = Entity()
        rootEntity = root
        placementLocation = Entity()
        deviceLocation = Entity()
        raycastOrigin = Entity()
        
      //  planeAnchorHandler = PlaneAnchorHandler(rootEntity: root)
        persistenceManager = PersistenceManager(worldTracking: worldTracking, rootEntity: root)
        persistenceManager.loadPersistedOrigins()
        
        rootEntity.addChild(placementLocation)
        
        deviceLocation.addChild(raycastOrigin)
        
        // Angle raycasts 15 degrees down.
        //let raycastDownwardAngle = 15.0 * (Float.pi / 180)
      //  raycastOrigin.orientation = simd_quatf(angle: -raycastDownwardAngle, axis: [1.0, 0.0, 0.0])
    }
    
    func saveOriginAnchorsOriginsMapToDisk() {
        persistenceManager.saveOriginAnchorsOriginsMapToDisk()
    }
    
    @MainActor
    func addPlacementTooltip(_ tooltip: Entity) {
        placementTooltip = tooltip
        
        // Add a tooltip 10 centimeters in front of the placement location to give
        // users feedback about why they can’t currently place an origin.
        placementLocation.addChild(tooltip)
        tooltip.position = [0.0, 0.05, 0.1]
    }
    
    func removeHighlightedOrigin() async {
        if let highlightedOrigin = placementState.highlightedOrigin {
            await persistenceManager.removeOrigin(highlightedOrigin)
        }
    }

    @MainActor
    func runARKitSession() async {
        do {
            // Placement manager is creating a new instance each time immersive space is entered?
            // Run a new set of providers every time when entering the immersive space.
            try await events.arkitSession.run([worldTracking, planeDetection])
        } catch {
            // No need to handle the error here; the app is already monitoring the
            // session for error.
            return
        }
        
//        if let firstFileName = appState?.modelDescriptors.first?.fileName, let object = appState?.placeableObjectsByFileName[firstFileName] {
//            select(object)
//        }
    }

    @MainActor
    func collisionBegan(_ event: CollisionEvents.Began) {
        guard let selectedOrigin = placementState.selectedOrigin else { return }
        guard selectedOrigin.matchesCollisionEvent(event: event) else { return }

        placementState.activeCollisions += 1
    }
    
    @MainActor
    func collisionEnded(_ event: CollisionEvents.Ended) {
        guard let selectedOrigin = placementState.selectedOrigin else { return }
        guard selectedOrigin.matchesCollisionEvent(event: event) else { return }
        guard placementState.activeCollisions > 0 else {
            print("Received a collision ended event without a corresponding collision start event.")
            return
        }

        placementState.activeCollisions -= 1
    }
    
    @MainActor
    func select(_ origin: ImmersionOrigin?) {
        if let oldSelection = placementState.selectedOrigin {
            // Remove the current preview entity.
            placementLocation.removeChild(oldSelection.previewEntity)

            // Handle deselection. Selecting the same origin again in the app deselects it.
            if oldSelection.descriptor.fileName == origin?.descriptor.fileName {
                select(nil)
                return
            }
        }
        
        // Update state.
        placementState.selectedOrigin = origin
    //    appState?.selectedFileName = origin?.descriptor.fileName
        
        if let origin {
            // Add new preview entity.
            placementLocation.addChild(origin.previewEntity)
        }
    }
    
    @MainActor
    func processWorldAnchorUpdates() async {
        for await anchorUpdate in worldTracking.anchorUpdates {
            persistenceManager.process(anchorUpdate)
        }
    }
    
    @MainActor
    func processDeviceAnchorUpdates() async {
        await run(function: self.queryAndProcessLatestDeviceAnchor, withFrequency: 90)
    }
    
    @MainActor
    private func queryAndProcessLatestDeviceAnchor() async {
        // Device anchors are only available when the provider is running.
        guard worldTracking.state == .running else { return }
        
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())

        placementState.deviceAnchorPresent = deviceAnchor != nil
//        placementState.planeAnchorsPresent = !planeAnchorHandler.planeAnchors.isEmpty
        placementState.selectedOrigin?.previewEntity.isEnabled = placementState.shouldShowPreview
        
        guard let deviceAnchor, deviceAnchor.isTracked else { return }
        
//        await updateUserFacingUIOrientations(deviceAnchor)
//        await checkWhichOriginDeviceIsPointingAt(deviceAnchor)
        await updatePlacementLocation(deviceAnchor)
    }
    
//    @MainActor
//    private func updateUserFacingUIOrientations(_ deviceAnchor: DeviceAnchor) async {
//        // 1. Orient the front side of the highlighted origin’s UI to face the user.
//        if let uiOrigin = placementState.highlightedOrigin?.uiOrigin {
//            // Set the UI to face the user (on the y-axis only).
//            uiOrigin.look(at: deviceAnchor.originFromAnchorTransform.translation)
//            let uiRotationOnYAxis = uiOrigin.transformMatrix(relativeTo: nil).gravityAligned.rotation
//            uiOrigin.setOrientation(uiRotationOnYAxis, relativeTo: nil)
//        }
//        
//        // 2. Orient each UI element to face the user.
//        for entity in [placementTooltip, dragTooltip, deleteButton] {
//            if let entity {
//                entity.look(at: deviceAnchor.originFromAnchorTransform.translation)
//            }
//        }
//    }
    
    @MainActor
    //Use this eventually when manually placing an origin?  Not needed now
    
    private func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
        deviceLocation.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
        let originFromUprightDeviceAnchorTransform = deviceAnchor.originFromAnchorTransform.gravityAligned
        
        // Determine a placement location on planes in front of the device by casting a ray.
        
        // Cast the ray from the device origin.
        let origin: SIMD3<Float> = raycastOrigin.transformMatrix(relativeTo: nil).translation
    
        // Cast the ray along the negative z-axis of the device anchor, but with a slight downward angle.
        // (The downward angle is configurable using the `raycastOrigin` orientation.)
        let direction: SIMD3<Float> = -raycastOrigin.transformMatrix(relativeTo: nil).zAxis
        
        // Only consider raycast results that are within 0.2 to 3 meters from the device.
        let minDistance: Float = 0.2
        let maxDistance: Float = 3
        
        // Only raycast against horizontal planes.
        let collisionMask = PlaneAnchor.allPlanesCollisionGroup

        var originFromPointOnPlaneTransform: float4x4? = nil
        if let result = rootEntity.scene?.raycast(origin: origin, direction: direction, length: maxDistance, query: .nearest, mask: collisionMask)
                                                  .first, result.distance > minDistance {
            if result.entity.components[CollisionComponent.self]?.filter.group != PlaneAnchor.verticalCollisionGroup {
                // If the raycast hit a horizontal plane, use that result with a small, fixed offset.
                originFromPointOnPlaneTransform = originFromUprightDeviceAnchorTransform
                originFromPointOnPlaneTransform?.translation = result.position + [0.0, PlacementManager.placedOriginsOffsetOnPlanes, 0.0]
            }
        }
        
        if let originFromPointOnPlaneTransform {
            placementLocation.transform = Transform(matrix: originFromPointOnPlaneTransform)
            placementState.planeToProjectOnFound = true
        } else {
            // If no placement location can be determined, position the preview 50 centimeters in front of the device.
            let distanceFromDeviceAnchor: Float = 0.5
            let downwardsOffset: Float = 0.3
            var uprightDeviceAnchorFromOffsetTransform = matrix_identity_float4x4
            uprightDeviceAnchorFromOffsetTransform.translation = [0, -downwardsOffset, -distanceFromDeviceAnchor]
            let originFromOffsetTransform = originFromUprightDeviceAnchorTransform * uprightDeviceAnchorFromOffsetTransform
            
            placementLocation.transform = Transform(matrix: originFromOffsetTransform)
            placementState.planeToProjectOnFound = false
        }
    }
    
//    @MainActor
//    private func checkWhichOriginDeviceIsPointingAt(_ deviceAnchor: DeviceAnchor) async {
//        let origin: SIMD3<Float> = raycastOrigin.transformMatrix(relativeTo: nil).translation
//        let direction: SIMD3<Float> = -raycastOrigin.transformMatrix(relativeTo: nil).zAxis
//        let collisionMask = PlacedOrigin.collisionGroup
//        
//        if let result = rootEntity.scene?.raycast(origin: origin, direction: direction, query: .nearest, mask: collisionMask).first {
//            if let pointedAtOrigin = persistenceManager.origin(for: result.entity) {
//                setHighlightedOrigin(pointedAtOrigin)
//            } else {
//                setHighlightedOrigin(nil)
//            }
//        } else {
//            setHighlightedOrigin(nil)
//        }
//    }
//    
    
    @MainActor
    func setHighlightedOrigin(_ originToHighlight: PlacedOrigin?) {
        guard placementState.highlightedOrigin != originToHighlight else {
            return
        }
        placementState.highlightedOrigin = originToHighlight

        // Detach UI from the previously highlighted origin.
        guard let deleteButton, let dragTooltip else { return }
        deleteButton.removeFromParent()
        dragTooltip.removeFromParent()

        guard let originToHighlight else { return }

        // Position and attach the UI to the newly highlighted origin.
        let extents = originToHighlight.extents
        let topLeftCorner: SIMD3<Float> = [-extents.x / 2, (extents.y / 2) + 0.02, 0]
        let frontBottomCenter: SIMD3<Float> = [0, (-extents.y / 2) + 0.04, extents.z / 2 + 0.04]
        deleteButton.position = topLeftCorner
        dragTooltip.position = frontBottomCenter

        originToHighlight.uiOrigin.addChild(deleteButton)
        deleteButton.scale = 1 / originToHighlight.scale
        originToHighlight.uiOrigin.addChild(dragTooltip)
        dragTooltip.scale = 1 / originToHighlight.scale
    }

    func removeAllPlacedOrigins() async {
        await persistenceManager.removeAllPlacedOrigins()
    }
    
//    func processPlaneDetectionUpdates() async {
//        for await anchorUpdate in planeDetection.anchorUpdates {
//            await planeAnchorHandler.process(anchorUpdate)
//        }
//    }
    
    // LOOK AT THIS ///
    // LOOK AT THIS ///

    // LOOK AT THIS ///

    // LOOK AT THIS ///

    // LOOK AT THIS ///

    // LOOK AT THIS ///
    // LOOK AT THIS ///

    //Place Origin using device location once
    @MainActor
    func placeSelectedOrigin(_ deviceAnchor: DeviceAnchor) {
        // Ensure there’s a placeable origin.
        guard let originToPlace = placementState.originToPlace else { return }

        // WHERE DOES PLACEMENT LOCATION POSITION AND ORIENTATION COME FROM
        let origin = originToPlace.materialize(Date())
//        origin.position = placementLocation.position
//        origin.orientation = placementLocation.orientation
        origin.position = deviceLocation.position
        origin.orientation = deviceLocation.orientation
        
        Task {
            await persistenceManager.attachOriginToWorldAnchor(origin)
        }
        placementState.userPlacedAnOrigin = true
    }
    
    // LOOK AT THIS ///

    // LOOK AT THIS ///

    // LOOK AT THIS ///

    
    @MainActor
    func checkIfAnchoredOriginsNeedToBeDetached() async {
        // Check whether origins should be detached from their world anchor.
        // This runs at 10 Hz to ensure that origins are quickly detached from their world anchor
        // as soon as they are moved - otherwise a world anchor update could overwrite the
        // origin’s position.
        await run(function: persistenceManager.checkIfAnchoredOriginsNeedToBeDetached, withFrequency: 10)
    }
    
    @MainActor
    func checkIfMovingOriginsCanBeAnchored() async {
        // Check whether origins can be reanchored.
        // This runs at 2 Hz - origins should be reanchored eventually but it’s not time critical.
        await run(function: persistenceManager.checkIfMovingOriginsCanBeAnchored, withFrequency: 2)
    }
    
//    @MainActor
//    func updateDrag(value: EntityTargetValue<DragGesture.Value>) {
//        if let currentDrag, currentDrag.draggedOrigin !== value.entity {
//            // Make sure any previous drag ends before starting a new one.
//            print("A new drag started but the previous one never ended - ending that one now.")
//            endDrag()
//        }
//        
//        // At the start of the drag gesture, remember which origin is being manipulated.
//        if currentDrag == nil {
//            guard let origin = persistenceManager.origin(for: value.entity) else {
//                print("Unable to start drag - failed to identify the dragged origin.")
//                return
//            }
//            
//            origin.isBeingDragged = true
//            currentDrag = DragState(originToDrag: origin)
//            placementState.userDraggedAnOrigin = true
//        }
//        
//        // Update the dragged origin’s position.
//        if let currentDrag {
//            currentDrag.draggedOrigin.position = currentDrag.initialPosition + value.convert(value.translation3D, from: .local, to: rootEntity)
//
//            // If possible, snap the dragged origin to a nearby horizontal plane.
//            let maxDistance = PlacementManager.snapToPlaneDistanceForDraggedOrigins
////            if let projectedTransform = PlaneProjector.project(point: currentDrag.draggedOrigin.transform.matrix,
////                                                               ontoHorizontalPlaneIn: planeAnchorHandler.planeAnchors,
////                                                               withMaxDistance: maxDistance) {
////                currentDrag.draggedOrigin.position = projectedTransform.translation
////            }
//        }
//    }
//    
//    @MainActor
//    func endDrag() {
//        guard let currentDrag else { return }
//        currentDrag.draggedOrigin.isBeingDragged = false
//        self.currentDrag = nil
//    }
}

extension PlacementManager {
    /// Run a given function at an approximate frequency.
    ///
    /// > Note: This method doesn’t take into account the time it takes to run the given function itself.
    @MainActor
    func run(function: () async -> Void, withFrequency hz: UInt64) async {
        while true {
            if Task.isCancelled {
                return
            }
            
            // Sleep for 1 s / hz before calling the function.
            let nanoSecondsToSleep: UInt64 = NSEC_PER_SEC / hz
            do {
                try await Task.sleep(nanoseconds: nanoSecondsToSleep)
            } catch {
                // Sleep fails when the Task is cancelled. Exit the loop.
                return
            }
            
            await function()
        }
    }
}
