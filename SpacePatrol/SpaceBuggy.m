/* Copyright (c) 2012 Scott Lembcke and Howling Moon Software
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "SpaceBuggy.h"

#import "ChipmunkAutoGeometry.h"
#import "Physics.h"

enum {
	Z_WHEEL,
	Z_CHASSIS,
	Z_STRUT,
};


@interface SpaceBuggyPart : NSObject<ChipmunkObject>  {
	ChipmunkBody *_body;
	CCNode *_node;
}

@property(nonatomic, readonly, strong) ChipmunkBody *body;
@property(nonatomic, readonly, strong) CCNode *node;

@property(nonatomic, retain) NSArray *chipmunkObjects;

@end


@implementation SpaceBuggyPart

@synthesize body = _body, node = _node;
@synthesize chipmunkObjects = _chipmunkObjects;

@end



@interface SpaceBuggyWheel : SpaceBuggyPart @end
@implementation SpaceBuggyWheel

-(id)init
{
	if((self = [super init])){
		CCSprite *sprite = [CCSprite spriteWithFile:@"Wheel.png"];
		_node = sprite;
		
		cpFloat mass = 1.0;
		cpFloat radius = 0.95*sprite.contentSize.width/2.0;
		
		_body = [ChipmunkBody bodyWithMass:mass andMoment:cpMomentForCircle(mass, 0.0, radius, cpvzero)];
		
		ChipmunkShape *shape = [ChipmunkCircleShape circleWithBody:_body radius:radius offset:cpvzero];
		shape.friction = 1.0;
		shape.group = PhysicsIdentifier(BUGGY);
		
		self.chipmunkObjects = [NSArray arrayWithObjects:_body, shape, nil];
	}
	
	return self;
}

@end



@interface SpaceBuggyChassis : SpaceBuggyPart @end
@implementation SpaceBuggyChassis

-(id)init
{
	if((self = [super init])){
		CCSprite *sprite = [CCSprite spriteWithFile:@"Chassis.png"];
		_node = sprite;
		
		NSURL *url = [[NSBundle mainBundle] URLForResource:@"ChassisOutline" withExtension:@"png"];
		ChipmunkBitmapSampler *sampler = [ChipmunkImageSampler samplerWithImageFile:url isMask:FALSE];
		[sampler setBorderValue:0.0];
		ChipmunkPolylineSet *lines = [sampler marchAllWithBorder:TRUE hard:FALSE];
		ChipmunkPolyline *line = [lines lineAtIndex:0];
		
		NSAssert(lines.count == 1 && line.area > 0.0, @"Degenerate image hull.");
		
		cpFloat mass = 1.0;
		
		_body = [ChipmunkBody bodyWithMass:mass andMoment:[line momentForMass:mass offset:cpvneg(sprite.anchorPointInPoints)]];
		
		ChipmunkPolyline *hull = [[line simplifyCurves:1.0] toConvexHull:1.0];
		ChipmunkShape *shape = [hull asChipmunkPolyShapeWithBody:_body offset:cpvneg(sprite.anchorPointInPoints)];
		shape.friction = 0.3;
		shape.group = PhysicsIdentifier(BUGGY);
		
		self.chipmunkObjects = [NSArray arrayWithObjects:_body, shape, nil];
	}
	
	return self;
}

@end



@implementation SpaceBuggy {
	SpaceBuggyPart *_chassis;
	SpaceBuggyPart *_frontWheel, *_rearWheel;
	
	CCSprite *_frontStrut, *_rearStrut;
	
	ChipmunkGrooveJoint *_frontJoint;
	ChipmunkPinJoint *_rearJoint;
}

@synthesize chipmunkObjects = _chipmunkObjects, node = _node;

-(id)initWithPosition:(cpVect)pos
{
	if((self = [super init])){
		_node = [CCNode node];
		[_node.scheduler scheduleUpdateForTarget:self priority:1000 paused:FALSE];
		
		_chassis = [[SpaceBuggyChassis alloc] init];
		_chassis.body.pos = pos;
		[_node addChild:_chassis.node z:Z_CHASSIS];
		
		_frontWheel = [[SpaceBuggyWheel alloc] init];
		_frontWheel.body.pos = cpvadd(pos, cpv(47, -20));
		[_node addChild:_frontWheel.node z:Z_WHEEL];
		
		_frontStrut = [CCSprite spriteWithFile:@"FrontStrut.png"];
		_frontStrut.anchorPoint = ccp(1.2, 0.5);
		[_node addChild:_frontStrut z:Z_STRUT];
		
		_rearWheel = [[SpaceBuggyWheel alloc] init];
		_rearWheel.body.pos = cpvadd(pos, cpv(-41, -20));
		[_node addChild:_rearWheel.node z:Z_WHEEL];
		
		_rearStrut = [CCSprite spriteWithFile:@"RearStrut.png"];
		_rearStrut.anchorPoint = ccp(0.025, 0.2);
		[_node addChild:_rearStrut z:Z_STRUT];
		
		cpVect grv_a = [_chassis.body world2local:_frontWheel.body.pos];
		cpVect grv_b = cpvadd(grv_a, cpvmult(cpv(-1.0, 1.0), 7.0));
		_frontJoint = [ChipmunkGrooveJoint grooveJointWithBodyA:_chassis.body bodyB:_frontWheel.body groove_a:grv_a groove_b:grv_b anchr2:cpvzero];
		
		_rearJoint = [ChipmunkPinJoint pinJointWithBodyA:_chassis.body bodyB:_rearWheel.body anchr1:cpv(-14, -8) anchr2:cpvzero];
		
		_chipmunkObjects = [NSArray arrayWithObjects:_chassis, _frontWheel, _rearWheel, _frontJoint, _rearJoint, nil];
	}
	
	return self;
}

static inline cpVect
ClosetPointOnSegment(const cpVect p, const cpVect a, const cpVect b)
{
	cpVect delta = cpvsub(a, b);
	cpFloat t = cpfclamp01(cpvdot(delta, cpvsub(p, b))/cpvlengthsq(delta));
	return cpvadd(b, cpvmult(delta, t));
}

-(void)update:(ccTime)dt
{
	// Sync the chassis normally.
	_chassis.node.position = _chassis.body.pos;
	_chassis.node.rotation = -CC_RADIANS_TO_DEGREES(_chassis.body.angle);
	
	// Ooops... Forgot to write Obj-C groove joint getters... A little embarassing...
	// Will fix in the next version of Chipmunk. Use the C API for now.
	cpVect grv_a = [_chassis.body local2world:cpGrooveJointGetGrooveA(_frontJoint.constraint)];
	cpVect grv_b = [_chassis.body local2world:cpGrooveJointGetGrooveB(_frontJoint.constraint)];
	
	_frontWheel.node.position = ClosetPointOnSegment(_frontWheel.body.pos, grv_a, grv_b);
	_frontWheel.node.rotation = -CC_RADIANS_TO_DEGREES(_frontWheel.body.angle);
	
	_frontStrut.position = _frontWheel.node.position;
	_frontStrut.rotation = _chassis.node.rotation;
	
	_rearWheel.node.position = _rearWheel.body.pos;
	_rearWheel.node.rotation = -CC_RADIANS_TO_DEGREES(_rearWheel.body.angle);
	
	
	_rearStrut.position = _rearWheel.node.position;
	_rearStrut.rotation = _chassis.node.rotation;
}

-(cpVect)pos
{
	return _chassis.body.pos;
}

-(void)unschedule
{
	[_node.scheduler unscheduleAllSelectorsForTarget:self];
}

-(void)adjust:(cpVect)pos
{
	NSLog(@"%@", NSStringFromCGPoint(pos));
}

@end