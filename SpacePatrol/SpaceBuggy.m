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
	Z_CHASSIS,
	Z_WHEEL,
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
		
		cpFloat radius = 0.95*sprite.contentSize.width/2.0;
		
		_body = [ChipmunkBody bodyWithMass:WHEEL_MASS andMoment:cpMomentForCircle(WHEEL_MASS, 0.0, radius, cpvzero)];
		
		ChipmunkShape *shape = [ChipmunkCircleShape circleWithBody:_body radius:radius offset:cpvzero];
		shape.friction = 1.0;
		shape.group = PhysicsIdentifier(BUGGY);
		shape.layers = COLLISION_LAYERS_BUGGY;
		
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
		
		_body = [ChipmunkBody bodyWithMass:CHASSIS_MASS andMoment:[line momentForMass:CHASSIS_MASS offset:cpvneg(sprite.anchorPointInPoints)]];
		
		ChipmunkPolyline *hull = [[line simplifyCurves:1.0] toConvexHull:1.0];
		ChipmunkShape *shape = [hull asChipmunkPolyShapeWithBody:_body offset:cpvneg(sprite.anchorPointInPoints)];
		shape.friction = 0.3;
		shape.group = PhysicsIdentifier(BUGGY);
		shape.layers = COLLISION_LAYERS_BUGGY;
		
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
	cpFloat _rearStrutRestAngle;
	
	ChipmunkSimpleMotor *_motor, *_frontBrake, *_rearBrake;
}

@synthesize chipmunkObjects = _chipmunkObjects, node = _node;

-(cpFloat)rearStrutAngle
{
	return cpvtoangle(cpvsub([_chassis.body local2world:_rearJoint.anchr1], _rearWheel.body.pos));
}

-(id)initWithPosition:(cpVect)pos
{
	if((self = [super init])){
		_node = [CCNode node];
		
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
		
		{
			ChipmunkBody *chassis = _chassis.body;
			ChipmunkBody *front = _frontWheel.body;
			ChipmunkBody *rear = _rearWheel.body;
			
			cpVect grv_a = [chassis world2local:front.pos];
			cpVect grv_b = cpvadd(grv_a, cpvmult(cpv(-1.0, 1.0), 7.0));
			_frontJoint = [ChipmunkGrooveJoint grooveJointWithBodyA:chassis bodyB:front groove_a:grv_a groove_b:grv_b anchr2:cpvzero];
			
			cpVect front_anchor = [chassis world2local:front.pos];
			ChipmunkConstraint *frontSpring = [ChipmunkDampedSpring dampedSpringWithBodyA:chassis bodyB:front anchr1:front_anchor anchr2:cpvzero restLength:0.0 stiffness:FRONT_SPRING damping:FRONT_DAMPING];
			
			_rearJoint = [ChipmunkPinJoint pinJointWithBodyA:chassis bodyB:rear anchr1:cpv(-14, -8) anchr2:cpvzero];
			_rearStrutRestAngle = [self rearStrutAngle];
			
			cpVect rear_anchor = [chassis world2local:rear.pos];
			ChipmunkConstraint *rearSpring = [ChipmunkDampedSpring dampedSpringWithBodyA:chassis bodyB:rear anchr1:rear_anchor anchr2:cpvzero restLength:0.0 stiffness:REAR_SPRING damping:REAR_DAMPING];
			ChipmunkConstraint *rearStrutLimit = [ChipmunkSlideJoint slideJointWithBodyA:chassis bodyB:rear anchr1:rear_anchor anchr2:cpvzero min:0.0 max:20.0];
			
			_motor = [ChipmunkSimpleMotor simpleMotorWithBodyA:chassis bodyB:rear rate:ENGINE_MAX_W];
			_motor.maxForce = 0.0;
			
			ChipmunkSimpleMotor *differential = [ChipmunkSimpleMotor simpleMotorWithBodyA:rear bodyB:front rate:0.0];
			differential.maxForce = ENGINE_MAX_TORQUE*DIFFERENTIAL_TORQUE;
			
			_frontBrake = [ChipmunkSimpleMotor simpleMotorWithBodyA:chassis bodyB:front rate:0.0];
			_rearBrake = [ChipmunkSimpleMotor simpleMotorWithBodyA:chassis bodyB:rear rate:0.0];
			_frontBrake.maxForce = _rearBrake.maxForce = ROLLING_FRICTION;
			
			_chipmunkObjects = [NSArray arrayWithObjects:
				_chassis, _frontWheel, _rearWheel,
				_frontJoint, frontSpring, _frontBrake,
				_rearJoint, rearSpring, _rearBrake,
				rearStrutLimit, _motor, differential,
				nil
			];
		}
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

static inline cpVect
ProjectFromPoint(cpVect p, cpVect anchor, cpFloat dist)
{
	cpVect n = cpvnormalize(cpvsub(p, anchor));
	return cpvadd(anchor, cpvmult(n, dist));
}

-(void)update:(ccTime)dt throttle:(int)throttle;
{
	if(throttle > 0){
		_motor.maxForce = cpfclamp01(1.0 - (_rearWheel.body.angVel - _chassis.body.angVel)/ENGINE_MAX_W)*ENGINE_MAX_TORQUE;
		_rearBrake.maxForce = _frontBrake.maxForce = ROLLING_FRICTION;
	} else if(throttle < 0){
		_motor.maxForce = 0.0;
		_rearBrake.maxForce = _frontBrake.maxForce = BRAKING_TORQUE;
	} else {
		_motor.maxForce = 0.0;
		_rearBrake.maxForce = _frontBrake.maxForce = ROLLING_FRICTION;
	}
}

-(void)sync
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
	
	_rearWheel.node.position = ProjectFromPoint(_rearWheel.body.pos, [_chassis.body local2world:_rearJoint.anchr1], _rearJoint.dist);
	_rearWheel.node.rotation = -CC_RADIANS_TO_DEGREES(_rearWheel.body.angle);
	
	_rearStrut.position = _rearWheel.node.position;
	_rearStrut.rotation = -CC_RADIANS_TO_DEGREES([self rearStrutAngle] - _rearStrutRestAngle);
}

-(cpVect)pos
{
	return _chassis.body.pos;
}

@end