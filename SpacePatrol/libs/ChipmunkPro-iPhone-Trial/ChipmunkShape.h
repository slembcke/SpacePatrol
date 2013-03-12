@class ChipmunkNearestPointQueryInfo;
@class ChipmunkSegmentQueryInfo;


/// Abstract base class for collsion shape types.
@interface ChipmunkShape : NSObject <ChipmunkBaseObject> {
@public
	id data;
}

/// Get the ChipmunkShape object associciated with a cpShape pointer.
/// Undefined if the cpShape wasn't created using Objective-Chipmunk.
+(ChipmunkShape *)shapeFromCPShape:(cpShape *)shape;

/// Returns a pointer to the underlying cpShape C struct.
@property(nonatomic, readonly) cpShape *shape;

/// The ChipmunkBody that this shape is attached to.
@property(nonatomic, retain) ChipmunkBody *body;

/// The axis-aligned bounding box for this shape.
@property(nonatomic, readonly) cpBB bb;

/// Sensor shapes send collision callback messages, but don't create a collision response.
@property(nonatomic, assign) BOOL sensor;

/// How bouncy this shape is.
@property(nonatomic, assign) cpFloat elasticity;

/// How much friction this shape has.
@property(nonatomic, assign) cpFloat friction;

/**
	The velocity of the shape's surface.
	This velocity is used in the collision response when calculating the friction only.
*/
@property(nonatomic, assign) cpVect surfaceVel;

/**
	An object reference used as a collision type identifier. This is used when defining collision handlers.
	@attention Like most @c delegate properties this is a weak reference and does not call @c retain.
*/
@property(nonatomic, assign) cpCollisionType collisionType;

/**
	An object reference used as a collision group identifier. Shapes with the same group do not collide.
	@attention Like most @c delegate properties this is a weak reference and does not call @c retain.
*/
@property(nonatomic, assign) cpGroup group;

/// A layer bitmask that defines which objects 
@property(nonatomic, assign) cpLayers layers;

/// Get the space the body is added to.
@property(nonatomic, readonly) ChipmunkSpace *space;

/**
	An object that this shape is associated with. You can use this get a reference to your game object or controller object from within callbacks.
	@attention Like most @c delegate properties this is a weak reference and does not call @c retain. This prevents reference cycles from occuring.
*/
@property(nonatomic, assign) id data;

/// Update and cache the axis-aligned bounding box for this shape.
- (cpBB)cacheBB;

/// Check if a point in absolute coordinates lies within the shape.
/// @deprecated Use nearestPointQuery: instead
- (bool)pointQuery:(cpVect)point __attribute__((__deprecated__));

- (ChipmunkNearestPointQueryInfo *)nearestPointQuery:(cpVect)point;
- (ChipmunkSegmentQueryInfo *)segmentQueryFrom:(cpVect)start to:(cpVect)end;

@end


@interface ChipmunkNearestPointQueryInfo : NSObject {
	@private
	cpNearestPointQueryInfo _info;
}

- (id)initWithInfo:(cpNearestPointQueryInfo *)info;

/// Returns a pointer to the underlying cpNearestPointQueryInfo C struct.
@property(nonatomic, readonly) cpNearestPointQueryInfo *info;

/// The ChipmunkShape found.
@property(nonatomic, readonly) ChipmunkShape *shape;

/// The distance between the point and the surface of the shape.
/// Negative distances mean that the point is that depth inside the shape.
@property(nonatomic, readonly) cpFloat dist;

/// The closest point on the surface of the shape to the point.
@property(nonatomic, readonly) cpVect point;

@end


/// Holds collision information from segment queries. You should never need to create one.
@interface ChipmunkSegmentQueryInfo : NSObject {
@private
	cpSegmentQueryInfo _info;
	cpVect _start, _end;
}

- (id)initWithInfo:(cpSegmentQueryInfo *)info start:(cpVect)start end:(cpVect)end;

/// Returns a pointer to the underlying cpSegmentQueryInfo C struct.
@property(nonatomic, readonly) cpSegmentQueryInfo *info;

/// The ChipmunkShape found.
@property(nonatomic, readonly) ChipmunkShape *shape;

/// The percentage between the start and end points where the collision occurred.
@property(nonatomic, readonly) cpFloat t;

/// The normal of the collision with the shape.
@property(nonatomic, readonly) cpVect normal;

/// The point of the collision in absolute (world) coordinates.
@property(nonatomic, readonly) cpVect point;

/// The distance from the start point where the collision occurred.
@property(nonatomic, readonly) cpFloat dist;

/// The start point.
@property(nonatomic, readonly) cpVect start;

/// The end point.
@property(nonatomic, readonly) cpVect end;

@end


/// Holds collision information from segment queries. You should never need to create one.
@interface ChipmunkShapeQueryInfo : NSObject {
@private
	ChipmunkShape *_shape;
	cpContactPointSet _contactPoints;
}

- (id)initWithShape:(ChipmunkShape *)shape andPoints:(cpContactPointSet *)set;

@property(nonatomic, readonly) ChipmunkShape *shape;
@property(nonatomic, readonly) cpContactPointSet *contactPoints;

@end


/// A perfect circle shape.
@interface ChipmunkCircleShape : ChipmunkShape {
@private
	cpCircleShape _shape;
}

/// Create an autoreleased circle shape with the given radius and offset from the center of gravity.
+ (id)circleWithBody:(ChipmunkBody *)body radius:(cpFloat)radius offset:(cpVect)offset;

/// Initialize a circle shape with the given radius and offset from the center of gravity.
- (id)initWithBody:(ChipmunkBody *)body radius:(cpFloat)radius offset:(cpVect)offset;

/// The radius of the circle.
@property(nonatomic, readonly) cpFloat radius;

/// The offset from the center of gravity.
@property(nonatomic, readonly) cpVect offset;

@end


/// A beveled (rounded) segment shape.
@interface ChipmunkSegmentShape : ChipmunkShape {
@private
	cpSegmentShape _shape;
}

/// Create an autoreleased segment shape with the given endpoints and radius.
+ (id)segmentWithBody:(ChipmunkBody *)body from:(cpVect)a to:(cpVect)b radius:(cpFloat)radius;

/// Initialize a segment shape with the given endpoints and radius.
- (id)initWithBody:(ChipmunkBody *)body from:(cpVect)a to:(cpVect)b radius:(cpFloat)radius;

/// The start of the segment shape.
@property(nonatomic, readonly) cpVect a;

/// The end of the segment shape.
@property(nonatomic, readonly) cpVect b;

/// The normal of the segment shape.
@property(nonatomic, readonly) cpVect normal;

/// The beveling radius of the segment shape.
@property(nonatomic, readonly) cpFloat radius;

@end


/// A convex polygon shape.
@interface ChipmunkPolyShape : ChipmunkShape {
@private
	cpPolyShape _shape;
}

/// Create an autoreleased polygon shape from the given vertex and offset from the center of gravity.
+ (id)polyWithBody:(ChipmunkBody *)body count:(int)count verts:(cpVect *)verts offset:(cpVect)offset;

/// Create an autoreleased box shape centered on the center of gravity.
+ (id)boxWithBody:(ChipmunkBody *)body width:(cpFloat)width height:(cpFloat)height;

/// Create an autoreleased box shape with the given bounding box in body local coordinates.
+ (id)boxWithBody:(ChipmunkBody *)body bb:(cpBB)bb;

/// Initialize a polygon shape from the given vertex and offset from the center of gravity.
- (id)initWithBody:(ChipmunkBody *)body count:(int)count verts:(cpVect *)verts offset:(cpVect)offset;

/// Initialize a box shape centered on the center of gravity.
- (id)initBoxWithBody:(ChipmunkBody *)body width:(cpFloat)width height:(cpFloat)height;

/// Initialize a box shape with the given bounding box in body local coordinates.
- (id)initBoxWithBody:(ChipmunkBody *)body bb:(cpBB)bb;

/// The number of vertexes in this polygon.
@property(nonatomic, readonly) int count;

/// Access the vertexes of this polygon.
- (cpVect)getVertex:(int)index;

@end

/// A subclass of ChipmunkCircleShape that is added as a static shape when using ChipmunkSpace.add:.
@interface ChipmunkStaticCircleShape : ChipmunkCircleShape
@end


/// A subclass of ChipmunkSegmentShape that is added as a static shape when using ChipmunkSpace.add:.
@interface ChipmunkStaticSegmentShape : ChipmunkSegmentShape
@end

/// A subclass of ChipmunkPolyShape that is added as a static shape when using ChipmunkSpace.add:.
@interface ChipmunkStaticPolyShape : ChipmunkPolyShape
@end
