/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
State for keeping track of whether origin placement is possible.
*/

import Foundation
import RealityKit

@Observable
class PlacementState {

    var selectedOrigin: ImmersionOrigin? = nil
    var highlightedOrigin: PlacedOrigin? = nil
    var originToPlace: ImmersionOrigin? { isPlacementPossible ? selectedOrigin : nil }
    var userDraggedAnOrigin = false

    var planeToProjectOnFound = false

    var activeCollisions = 0
    var collisionDetected: Bool { activeCollisions > 0 }
    var dragInProgress = false
    var userPlacedAnOrigin = false
    var deviceAnchorPresent = false
    var planeAnchorsPresent = false

    var shouldShowPreview: Bool {
        return deviceAnchorPresent && planeAnchorsPresent && !dragInProgress && highlightedOrigin == nil
    }

    var isPlacementPossible = true
}
