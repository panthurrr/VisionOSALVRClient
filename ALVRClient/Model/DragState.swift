/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The state of the current drag gesture.
*/

import Foundation

struct DragState {
    var draggedOrigin: PlacedOrigin
    var initialPosition: SIMD3<Float>
    
    @MainActor
    init(originToDrag: PlacedOrigin) {
        draggedOrigin = originToDrag
        initialPosition = originToDrag.position
    }
}
