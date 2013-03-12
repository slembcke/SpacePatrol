//
//  MissileSprite.m
//  SpacePatrol
//
//  Created by Scott Lembcke on 3/12/13.
//
//

#import "MissileSprite.h"
#import "SatelliteBody.h"
#import "Physics.h"
#import "SpacePatrolLayer.h"

@implementation MissileSprite

-(id)initAtPos:(cpVect)pos vel:(cpVect)vel;
{
	if((self = [super initWithFile:@"Missile.png"])){
		self.position = pos;
		self.zOrder = Z_MISSILE;
		
		self.body = [SatelliteBody bodyWithMass:0.2 andMoment:INFINITY];
		self.body.pos = pos;
		self.body.vel = vel;
		
		self.shape = [ChipmunkCircleShape circleWithBody:self.body radius:16.0f offset:cpvzero];
		self.shape.group = PhysicsIdentifier(BUGGY);
		
		_chipmunkObjects = @[self.body, self.shape];
	}
	
	return self;
}

-(void)onEnter
{
	[super onEnter];
	[self scheduleUpdate];
}

-(void)update:(ccTime)dt
{
	self.position = self.body.pos;
	self.rotation = -CC_RADIANS_TO_DEGREES(cpvtoangle(self.body.vel) - M_PI_2);
}

@end
