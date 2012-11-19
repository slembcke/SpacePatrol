/// ChipmunkHastySpace is an Objective-Chipmunk wrapper for cpHastySpace and is only available with Chipmunk Pro.
/// Subclass this class instead of ChipmunkSpace if you want to enable the cpHastySpace optimizations.
/// If ChipmunkHastySpace is linked correctly, calling [[ChipmunkSpace alloc] init] will actually return a ChipmunkHastySpace.
@interface ChipmunkHastySpace : ChipmunkSpace

@property(nonatomic, assign) NSUInteger threads;

@end
