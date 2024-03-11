//
//  ImmersionOrigin.swift
//  ALVRClient
//
//  Created by Chris Metrailer on 3/6/24.
//

import Foundation
import RealityKit

struct ModelDescriptor: Identifiable, Hashable {
    let fileName: String
    let displayName: String
    
    var id: String { fileName }
    
    init(fileName: String, displayName: String? = nil) {
        self.fileName = fileName
        self.displayName = displayName ?? fileName
    }
}

private enum PreviewOrigin {
    static let active = UnlitMaterial(color: .gray.withAlphaComponent(0.5))
    static let inactive = UnlitMaterial(color: .gray.withAlphaComponent(0.1))
}

@MainActor
class ImmersionOrigin {
    let descriptor: ModelDescriptor
    var previewEntity: Entity
    private var renderContent: ModelEntity
    
    static let previewCollisionGroup = CollisionGroup(rawValue: 1 << 15)
    
    init(descriptor: ModelDescriptor, renderContent: ModelEntity, previewEntity: Entity) {
        self.descriptor = descriptor
        self.previewEntity = previewEntity
        self.previewEntity.applyMaterial(PreviewOrigin.active)
        self.renderContent = renderContent
    }
    
    var isPreviewActive: Bool = true {
        didSet {
            if oldValue != isPreviewActive {
                previewEntity.applyMaterial(isPreviewActive ? PreviewOrigin.active : PreviewOrigin.inactive)
                // Only act as input target while active to prevent intercepting drag gestures from intersecting placed objects.
                previewEntity.components[InputTargetComponent.self]?.allowedInputTypes = isPreviewActive ? .indirect : []
            }
        }
    }
    
    func materialize(_ date: Date) -> PlacedOrigin {
        let shapes = previewEntity.components[CollisionComponent.self]!.shapes
        return PlacedOrigin(descriptor: descriptor, renderContentToClone: renderContent, shapes: shapes, date: date)
    }
    
    func matchesCollisionEvent(event: CollisionEvents.Began) -> Bool {
        event.entityA == previewEntity || event.entityB == previewEntity
    }
    
    func matchesCollisionEvent(event: CollisionEvents.Ended) -> Bool {
        event.entityA == previewEntity || event.entityB == previewEntity
    }

    func attachPreviewEntity(to entity: Entity) {
        entity.addChild(previewEntity)
    }
}

class PlacedOrigin: Entity {
    let fileName: String
    let date: Date
    
    private let renderContent: ModelEntity
    
    static let collisionGroup = CollisionGroup(rawValue: 1 << 29)
    
    let uiOrigin = Entity()
    
    var affectedByPhysics = false
    
    var isBeingDragged = false
    
    var positionAtLastReanchoringCheck: SIMD3<Float>?
    
    var atRest = false
    
    init(descriptor: ModelDescriptor, renderContentToClone: ModelEntity, shapes: [ShapeResource], date: Date) {
        fileName = "Cone" //descriptor.fileName
        self.date = date
        renderContent = renderContentToClone.clone(recursive: true)
        super.init()
        name = renderContent.name
        scale = renderContent.scale
        renderContent.scale = .one
        
        //We don't need any of the below yet
        // Make the object respond to gravity.
        let physicsMaterial = PhysicsMaterialResource.generate(restitution: 0.0)
        let physicsBodyComponent = PhysicsBodyComponent(shapes: shapes, mass: 1.0, material: physicsMaterial, mode: .static)
        components.set(physicsBodyComponent)
        components.set(CollisionComponent(shapes: shapes, isStatic: false,
                                          filter: CollisionFilter(group: PlacedOrigin.collisionGroup, mask: .all)))
        addChild(renderContent)
     //   addChild(uiOrigin)
    //    uiOrigin.position.y = extents.y / 2 // Position the UI origin in the object’s center.
        
        // Allow direct and indirect manipulation of placed objects.
        components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))
        
        // Add a grounding shadow to placed objects.
        renderContent.components.set(GroundingShadowComponent(castsShadow: true))
    }
    
    required init() {
        fatalError("`init` is unimplemented.")
    }
}

extension Entity {
    func applyMaterial(_ material: Material) {
        if let modelEntity = self as? ModelEntity {
            modelEntity.model?.materials = [material]
        }
        for child in children {
            child.applyMaterial(material)
        }
    }
        
    var extents: SIMD3<Float> { visualBounds(relativeTo: self).extents }
        
    func look(at target: SIMD3<Float>) {
        look(at: target,
             from: position(relativeTo: nil),
             relativeTo: nil,
             forward: .positiveZ)
    }
}
