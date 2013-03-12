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

#import "SatelliteBody.h"

enum {
	Z_CHASSIS,
	Z_WHEEL,
	Z_STRUT,
};


// A extremely basic game object class shared by the wheel and chassis parts.
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
		
		_body = [SatelliteBody bodyWithMass:WHEEL_MASS andMoment:cpMomentForCircle(WHEEL_MASS, 0.0, radius, cpvzero)];
		
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
		CGPoint anchor = cpvadd(sprite.anchorPointInPoints, COG_ADJUSTMENT);
		sprite.anchorPoint = ccp(anchor.x/sprite.contentSize.width, anchor.y/sprite.contentSize.height);
		_node = sprite;
		
		// So one of the things I wanted to do in this demo was show how to create a collision shape automatically from your sprite.
		// This example is unfortunately a little contrived, but it's still good example code.
		// One issue is that sometimes you don't want the collision shape to match the sprite exactly.
		// Like it might include things like hair or other bits that stick out but aren't really considered solid.
		// In this case, I didn't want the front strut to be part of the collision shape so I made a separate ChassisOutline.png file.
		// If I was doing this for more than just one sprite, I'd set up a system to handle alternate collision masks.
		// Anyway, onwards.
		
		// Note that by loading these using regular Foundation methods and not CCFileUtils, you will be loading the non-retina file.
		// Don't worry, this is exactly what you want!
		// It's in the correct scale already, and the collision shape will be exactly the same on retina and vanilla.
		NSURL *url = [[NSBundle mainBundle] URLForResource:@"ChassisOutline" withExtension:@"png"];
		ChipmunkBitmapSampler *sampler = [ChipmunkImageSampler samplerWithImageFile:url isMask:FALSE];
		// Set a border of 0.0 to ensure the outline will be closed even if the pixels butt up against the image edge.
		[sampler setBorderValue:0.0];
		
		// March the image and grab the outline.
		ChipmunkPolylineSet *lines = [sampler marchAllWithBorder:TRUE hard:FALSE];
		ChipmunkPolyline *line = [lines lineAtIndex:0];
		// Double check that we only have one and that it has the correct winding.
		// You can handle multiple outlines easily enough, but will need to change the moment calculation so that it's properly area weighted.
		NSAssert(lines.count == 1 && line.area > 0.0, @"Degenerate image hull.");
		
		// Calculate the moment of inertia from the polyline.
		// The center of gravity of the body will match up with the sprite's anchor point, so use that as the offset.
		cpFloat moment = [line momentForMass:CHASSIS_MASS offset:cpvneg(sprite.anchorPointInPoints)];
		
		_body = [SatelliteBody bodyWithMass:CHASSIS_MASS andMoment:moment];
		
		// Simplify the outline and make a convex hull out of it.
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
	
	// Rest angle of the rear strut so we know how to rotate the strut sprite.
	cpFloat _rearStrutRestAngle;
	
	// Motors for the brakes and main engine.
	ChipmunkSimpleMotor *_motor, *_frontBrake, *_rearBrake;
}

@synthesize chipmunkObjects = _chipmunkObjects, node = _node;

-(cpFloat)rearStrutAngle
{
	// Get the angle from the rear wheel to the rear strut attachment point.
	return cpvtoangle(cpvsub([_chassis.body local2world:_rearJoint.anchr1], _rearWheel.body.pos));
}

-(id)initWithPosition:(cpVect)pos
{
	if((self = [super init])){
		_node = [CCNode node];
		
		_chassis = [[SpaceBuggyChassis alloc] init];
		_chassis.body.pos = cpvadd(pos, COG_ADJUSTMENT);
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
		
		// Lots of physics to set up. WooT!
		{
			ChipmunkBody *chassis = _chassis.body;
			ChipmunkBody *front = _frontWheel.body;
			ChipmunkBody *rear = _rearWheel.body;
			
			// I purposely made a bunch of animating struts on the car to demonstrate two points:
			// 1) That you don't need to physically model each part to make it animate simply.
			// 2) With composite jointed objects, it can be a good idea to fudge the sprite positions instead of matching them exactly to the physics.
			
			// In the model I set up below, I keep the body and joint setup very simple.
			// The struts are not phyically modeled at all, they are just animated graphics.
			// Because there are no physical struts, the wheels are jointed directly to the chassis, and this keeps the simulation very stable.
			// I use zero length springs here because they make setting the model up very simple.
			// They always pull inwards, so you can't accidentally get the joint popped around and have the spring push it into a bad location.
			// Zero-length springs aren't possible in the real world, but they sure are handy in a simulated one. ;)
			
			// The front wheel strut telescopes, so we'll attach the center of the wheel to a groov joint on the chassis.
			// I created the graphics specifically to have a 45 degree angle. So it's easy to just fudge the numbers.
			cpVect grv_a = [chassis world2local:front.pos];
			cpVect grv_b = cpvadd(grv_a, cpvmult(cpv(-1.0, 1.0), 7.0));
			_frontJoint = [ChipmunkGrooveJoint grooveJointWithBodyA:chassis bodyB:front groove_a:grv_a groove_b:grv_b anchr2:cpvzero];
			
			// Create the front zero-length spring.
			cpVect front_anchor = [chassis world2local:front.pos];
			ChipmunkConstraint *frontSpring = [ChipmunkDampedSpring dampedSpringWithBodyA:chassis bodyB:front anchr1:front_anchor anchr2:cpvzero restLength:0.0 stiffness:FRONT_SPRING damping:FRONT_DAMPING];
			
			// The rear strut is a swinging arm that holds the wheel a at a certain distance from a pivot on the chassis.
			// A perfect fit for a pin joint conected between the chassis and the wheel's center.
			_rearJoint = [ChipmunkPinJoint pinJointWithBodyA:chassis bodyB:rear anchr1:cpvsub(cpv(-14, -8), COG_ADJUSTMENT) anchr2:cpvzero];
			_rearStrutRestAngle = [self rearStrutAngle];
			
			// Create the rear zero-length spring.
			cpVect rear_anchor = [chassis world2local:rear.pos];
			ChipmunkConstraint *rearSpring = [ChipmunkDampedSpring dampedSpringWithBodyA:chassis bodyB:rear anchr1:rear_anchor anchr2:cpvzero restLength:0.0 stiffness:REAR_SPRING damping:REAR_DAMPING];
			
			// Attach a slide joint to the wheel to limit it's range of motion.
			ChipmunkConstraint *rearStrutLimit = [ChipmunkSlideJoint slideJointWithBodyA:chassis bodyB:rear anchr1:rear_anchor anchr2:cpvzero min:0.0 max:20.0];
			
			// The main motor that drives the buggy.
			_motor = [ChipmunkSimpleMotor simpleMotorWithBodyA:chassis bodyB:rear rate:ENGINE_MAX_W];
			_motor.maxForce = 0.0;
			
			// I don't know if "differential" is the correct word, but it transfers a fraction of the rear torque to the front wheels.
			// In case the rear wheels are slipping. This makes the buggy less frustrating when climbing steep hills.
			ChipmunkSimpleMotor *differential = [ChipmunkSimpleMotor simpleMotorWithBodyA:rear bodyB:front rate:0.0];
			differential.maxForce = ENGINE_MAX_TORQUE*DIFFERENTIAL_TORQUE;
			
			// Wheel brakes.
			// While you could reuse the main motor for the brakes, it's easier not to.
			// It won't cause a performance issue to have too many extra motors unless you have hundreds of buggies in the game.
			// Even then, the motor constraints would be the least of your performance worries.
			_frontBrake = [ChipmunkSimpleMotor simpleMotorWithBodyA:chassis bodyB:front rate:0.0];
			_rearBrake = [ChipmunkSimpleMotor simpleMotorWithBodyA:chassis bodyB:rear rate:0.0];
			_frontBrake.maxForce = _rearBrake.maxForce = ROLLING_FRICTION;
			
			// Whew! That's a lot of objects to list.
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

// This is a handy function I've had hiding in chipmunk_private.h.
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
		// The motor is modeled like an electric motor where the torque decreases inversely as the rate approaches the maximum.
		// It's simple to code up and feels nice.
		_motor.maxForce = cpfclamp01(1.0 - (_chassis.body.angVel - _rearWheel.body.angVel)/ENGINE_MAX_W)*ENGINE_MAX_TORQUE;
		// Set the brakes to apply the baseline rolling friction torque.
		_rearBrake.maxForce = _frontBrake.maxForce = ROLLING_FRICTION;
	} else if(throttle < 0){
		// Disable the motor.
		_motor.maxForce = 0.0;
		// It would be a pretty good idea to give the front and rear brakes different torques.
		// The buggy as is now has a tendency to tip forward when braking hard.
		_rearBrake.maxForce = _frontBrake.maxForce = BRAKING_TORQUE;
	} else {
		// Disable the motor.
		_motor.maxForce = 0.0;
		// Set the brakes to apply the baseline rolling friction torque.
		_rearBrake.maxForce = _frontBrake.maxForce = ROLLING_FRICTION;
	}
}

-(void)sync
{
	// Q: So what's up with this? Why sync the sprites all manually when ChipmunkSprite exists?
	// A: Because it would make the struts look like crap!
	// Joints in physics engines are never perfect.
	// They always approximately constrain two bodies, but always leave a little slop.
	// This is normally fine, but in this demo, you'd notice the poor alignment of the struts if this happened.
	// Especially the front telescoping one which is very position sensitive.
	
	// So we'll sync them manually and clamp the positions back to the nearest properly constrained location.
	// This might cause the sprites and bodies to get slightly out of sync, but _nobody_ will notice that.
	
	
	// Sync the chassis normally.
	_chassis.node.position = _chassis.body.pos;
	_chassis.node.rotation = -CC_RADIANS_TO_DEGREES(_chassis.body.angle);
	
	// Ooops... Forgot to write Obj-C groove joint getters... A little embarassing...
	// Will fix in the next version of Chipmunk. Use the C API for now.
	cpVect grv_a = [_chassis.body local2world:cpGrooveJointGetGrooveA(_frontJoint.constraint)];
	cpVect grv_b = [_chassis.body local2world:cpGrooveJointGetGrooveB(_frontJoint.constraint)];
	
	// Clamp the front wheel's position to the groove.
	_frontWheel.node.position = ClosetPointOnSegment(_frontWheel.body.pos, grv_a, grv_b);
	_frontWheel.node.rotation = -CC_RADIANS_TO_DEGREES(_frontWheel.body.angle);
	
	// Position the front strut sprite to match the wheel's position and the chassis's rotation.
	_frontStrut.position = _frontWheel.node.position;
	_frontStrut.rotation = _chassis.node.rotation;
	
	// Project the rear wheel to the proper distance from the pivot.
	_rearWheel.node.position = ProjectFromPoint(_rearWheel.body.pos, [_chassis.body local2world:_rearJoint.anchr1], _rearJoint.dist);
	_rearWheel.node.rotation = -CC_RADIANS_TO_DEGREES(_rearWheel.body.angle);
	
	// Position the rear strut to match the rear wheel's position and it's proper angle of rotation based on the joint anchor positions.
	_rearStrut.position = _rearWheel.node.position;
	_rearStrut.rotation = -CC_RADIANS_TO_DEGREES([self rearStrutAngle] - _rearStrutRestAngle);
}

-(cpVect)pos
{
	return _chassis.body.pos;
}

-(ChipmunkBody *)body
{
	return _chassis.body;
}

@end