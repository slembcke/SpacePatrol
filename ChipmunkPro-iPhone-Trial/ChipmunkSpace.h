/**
	Chipmunk spaces are simulation containers. You add a bunch of physics objects to a space (rigid bodies, collision shapes, and joints) and step the entire space forward through time as a whole.
	If you have Chipmunk Pro, you'll want to use the ChipmunkHastySpace subclass instead as it has iPhone specific optimizations.
	Unfortunately because of how Objective-C code is linked I can't dynamically substitute a ChipmunkHastySpace from a static library.
*/

struct cpSpace;

@interface ChipmunkSpace : NSObject {
@protected
	struct cpSpace *_space;
	ChipmunkBody *_staticBody;
	
	NSMutableSet *_children;
	NSMutableArray *_handlers;
	
	id _data;
}

/**
	The iteration count is how many solver passes the space should use when solving collisions and joints (default is 10).
	Fewer iterations mean less CPU usage, but lower quality (mushy looking) physics.
*/
@property int iterations;

/// Global gravity value to use for all rigid bodies in this space (default value is @c cpvzero).
@property cpVect gravity;

/**
	Global viscous damping value to use for all rigid bodies in this space (default value is 1.0 which disables damping).
	This value is the fraction of velocity a body should have after 1 second.
	A value of 0.9 would mean that each second, a body would have 80% of the velocity it had the previous second.
*/
@property cpFloat damping;

/// If a body is moving slower than this speed, it is considered idle. The default value is 0, which signals that the space should guess a good value based on the current gravity.
@property cpFloat idleSpeedThreshold;

/**
	Elapsed time before a group of idle bodies is put to sleep (defaults to infinity which disables sleeping).
	If an entire group of touching or jointed bodies has been idle for at least this long, the space will put all of the bodies into a sleeping state where they consume very little CPU.
*/
@property cpFloat sleepTimeThreshold;

/**
	Amount of encouraged penetration between colliding shapes..
	Used to reduce oscillating contacts and keep the collision cache warm.
	Defaults to 0.1. If you have poor simulation quality,
	increase this number as much as possible without allowing visible amounts of overlap.
*/
@property cpFloat collisionSlop;

/**
	Determines how fast overlapping shapes are pushed apart.
	Expressed as a fraction of the error remaining after each second.
	Defaults to pow(1.0 - 0.1, 60.0) meaning that Chipmunk fixes 10% of overlap each frame at 60Hz.
*/
@property cpFloat collisionBias;

/**
	Number of frames that contact information should persist.
	Defaults to 3. There is probably never a reason to change this value.
*/
@property cpTimestamp collisionPersistence;

/**
	@deprecated 6.0.4
	Does nothing, and is a no-op. The contact graph is always enabled now.
*/
@property bool enableContactGraph
__attribute__((__deprecated__));

/// Returns a pointer to the underlying cpSpace C struct
@property (readonly) cpSpace *space;

/**
	The space's designated static body.
	Collision shapes added to the body will automatically be marked as static shapes, and rigid bodies that come to rest while touching or jointed to this body will fall asleep.
*/
@property (readonly) ChipmunkBody *staticBody;

/**
	Retrieves the current (if you are in a callback from [ChipmunkSpace step:]) or most recent (outside of a [ChipmunkSpace step:] call) timestep.
*/
@property (readonly) cpFloat currentTimeStep;

/**
	An object that this space is associated with. You can use this get a reference to your game state or controller object from within callbacks.
	@attention Like most @c delegate properties this is a weak reference and does not call @c retain. This prevents reference cycles from occuring.
*/
@property (assign) id data;

/// Get the ChipmunkSpace object associciated with a cpSpace pointer.
/// Undefined if the cpSpace wasn't created using Objective-Chipmunk.
+(ChipmunkSpace *)spaceFromCPSpace:(cpSpace *)space;

/**
  Set the default collision handler.
  The default handler is used for all collisions when a specific collision handler cannot be found.
  
  The expected method selectors are as follows:
	@code
- (bool)begin:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
- (bool)preSolve:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
- (void)postSolve:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
- (void)separate:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
	@endcode
*/
- (void)setDefaultCollisionHandler:(id)delegate
	begin:(SEL)begin
	preSolve:(SEL)preSolve
	postSolve:(SEL)postSolve
	separate:(SEL)separate;

/**
  Set a collision handler to handle specific collision types.
  The methods are called only when shapes with the specified collisionTypes collide.
  
  @c typeA and @c typeB should be the same object references set to ChipmunkShape.collisionType. They can be any uniquely identifying object.
	Class and global NSString objects work well as collision types as they are easy to get a reference to and do not require you to allocate any objects.
  
  The expected method selectors are as follows:
	@code
- (bool)begin:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
- (bool)preSolve:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
- (void)postSolve:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
- (void)separate:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
	@endcode
*/
- (void)addCollisionHandler:(id)delegate
	typeA:(id)a typeB:(id)b
	begin:(SEL)begin
	preSolve:(SEL)preSolve
	postSolve:(SEL)postSolve
	separate:(SEL)separate;


/// Remove a collision handler.
- (void)removeCollisionHandlerForTypeA:(id)a andB:(id)b;

/**
  Add an object to the space.
  This can be any object that implements the ChipmunkObject protocol.
	This includes all the basic types such as ChipmunkBody, ChipmunkShape and ChipmunkConstraint as well as any composite game objects you may define that implement the protocol.
	@warning This method may not be called from a collision handler callback. See smartAdd: or ChipmunkSpace.addPostStepCallback:selector:context: for information on how to do that.
*/
- (id)add:(NSObject<ChipmunkObject> *)obj;

/**
  Remove an object from the space.
  This can be any object that implements the ChipmunkObject protocol.
	This includes all the basic types such as ChipmunkBody, ChipmunkShape and ChipmunkConstraint as well as any composite game objects you may define that implement the protocol.
	@warning This method may not be called from a collision handler callback. See smartRemove: or ChipmunkSpace.addPostStepCallback:selector:context: for information on how to do that.
*/
- (id)remove:(NSObject<ChipmunkObject> *)obj;

/// Check if a space already contains a particular object:
-(BOOL)contains:(id <ChipmunkObject>)obj;

/// If the space is locked and it's unsafe to call add: it will call addPostStepAddition: instead.
- (NSObject<ChipmunkObject> *)smartAdd:(NSObject<ChipmunkObject> *)obj;

/// If the space is locked and it's unsafe to call remove: it will call addPostStepRemoval: instead.
- (NSObject<ChipmunkObject> *)smartRemove:(NSObject<ChipmunkObject> *)obj;


/**
  Define a callback to be run just before [ChipmunkSpace step:] finishes.
  The main reason you want to define post-step callbacks is to get around the restriction that you cannot call the add/remove methods from a collision handler callback.
	Post-step callbacks run right before the next (or current) call to ChipmunkSpace.step: returns when it is safe to add and remove objects.
	You can only schedule one post-step callback per key value, this prevents you from accidentally removing an object twice. Registering a second callback for the same key is a no-op.
  
  The method signature of the method should be:
  @code
- (void)postStepCallback:(id)key</code></pre>
	@endcode
	
  This makes it easy to call a removal method on your game controller to remove a game object that died or was destroyed as the result of a collision:
  @code
[space addPostStepCallback:gameController selector:@selector(remove:) key:gameObject];
	@endcode
	
	@attention Not to be confused with post-solve collision handler callbacks.
	@warning @c target and @c object cannot be retained by the ChipmunkSpace. If you need to release either after registering the callback, use autorelease to ensure that they won't be deallocated until after [ChipmunkSpace step:] returns.
	@see ChipmunkSpace.addPostStepRemoval:
*/
- (void)addPostStepCallback:(id)target selector:(SEL)selector key:(id)key;

/// Block type used with [ChipmunkSpace addPostStepBlock:]
typedef void (^ChipmunkPostStepBlock)();

/// Same as [ChipmunkSpace addPostStepCallback:] but with a block. The block is copied.
- (void)addPostStepBlock:(ChipmunkPostStepBlock)block key:(id)key;

/// Add the Chipmunk Object from the space at the end of the step.
- (void)addPostStepAddition:(id <ChipmunkObject>)obj;

/// Remove the Chipmunk Object from the space at the end of the step.
- (void)addPostStepRemoval:(id <ChipmunkObject>)obj;

/// Return an array of ChipmunkNearestPointQueryInfo objects for shapes within @c maxDistance of @c point.
/// The point is treated as having the given group and layers.
- (NSArray *)nearestPointQueryAll:(cpVect)point maxDistance:(cpFloat)maxDistance layers:(cpLayers)layers group:(id)group;

/// Find the closest shape to a point that is within @c maxDistance of @c point.
/// The point is treated as having the given layers and group.
- (ChipmunkNearestPointQueryInfo *)nearestPointQueryNearest:(cpVect)point maxDistance:(cpFloat)maxDistance layers:(cpLayers)layers group:(id)group;

/// Returns a NSArray of all shapes that overlap the given point. The point is treated as having the given group and layers.
/// @deprecated
- (NSArray *)pointQueryAll:(cpVect)point layers:(cpLayers)layers group:(id)group __attribute__((__deprecated__));

/// Returns the first shape that overlaps the given point. The point is treated as having the given group and layers.
/// @deprecated 
- (ChipmunkShape *)pointQueryFirst:(cpVect)point layers:(cpLayers)layers group:(id)group __attribute__((__deprecated__));

/// Return a NSArray of ChipmunkSegmentQueryInfo objects for all the shapes that overlap the segment. The objects are unsorted.
- (NSArray *)segmentQueryAllFrom:(cpVect)start to:(cpVect)end layers:(cpLayers)layers group:(id)group;

/// Returns the first shape that overlaps the given segment. The segment is treated as having the given group and layers. 
- (ChipmunkSegmentQueryInfo *)segmentQueryFirstFrom:(cpVect)start to:(cpVect)end layers:(cpLayers)layers group:(id)group;

/// Returns a NSArray of all shapes whose bounding boxes overlap the given bounding box. The box is treated as having the given group and layers. 
- (NSArray *)bbQueryAll:(cpBB)bb layers:(cpLayers)layers group:(id)group;

/// Returns a NSArray of ChipmunkShapeQueryInfo objects for all the shapes that overlap @c shape.
- (NSArray *)shapeQueryAll:(ChipmunkShape *)shape;

/// Returns true if the shape overlaps anything in the space.
- (BOOL)shapeTest:(ChipmunkShape *)shape;

/// Perform a shape query for shape and call cpBodyActivate() for everythnig it touches.
- (void)activateShapesTouchingShape:(ChipmunkShape *)shape;

/// Get a copy of the list of all the bodies in the space.
- (NSArray *)bodies;

/// Get a copy of the list of all the shapes in the space
- (NSArray *)shapes;

/// Get a copy of the list of all the constraints in the space
- (NSArray *)constraints;

/// Update all the static shapes.
- (void)reindexStatic;

/// Update the collision info for a single shape.
/// Can be used to update individual static shapes that were moved or active shapes that were moved that you want to query against.
- (void)reindexShape:(ChipmunkShape *)shape;

/// Update the collision info for all shapes attached to a body.
- (void)reindexShapesForBody:(ChipmunkBody *)body;

/// Step time forward. While variable timesteps may be used, a constant timestep will allow you to reduce CPU usage by using fewer iterations.
- (void)step:(cpFloat)dt;

@end

//MARK: Misc

/**
	A macro that defines and initializes shape variables for you in a collision callback.
	They are initialized in the order that they were defined in the collision handler associated with the arbiter.
	If you defined the handler as:
	
	@code
		[space addCollisionHandler:target typeA:foo typeB:bar ...]
	@endcode
	
	You you will find that @code a->collision_type == 1 @endcode and @code b->collision_type == 2 @endcode.
*/
#define CHIPMUNK_ARBITER_GET_SHAPES(arb, a, b) ChipmunkShape *a, *b; { \
	cpShape *shapeA, *shapeB; \
	cpArbiterGetShapes(arb, &shapeA, &shapeB); \
	a = shapeA->data; b = shapeB->data; \
}

#define CHIPMUNK_ARBITER_GET_BODIES(arb, a, b) ChipmunkBody *a, *b; { \
	cpBody *bodyA, *bodyB; \
	cpArbiterGetBodies(arb, &bodyA, &bodyB); \
	a = bodyA->data; b = bodyB->data; \
}


