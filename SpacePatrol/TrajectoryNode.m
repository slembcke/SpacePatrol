//
//  TrajectoryNode.m
//  AngryChipmunks
//
//  Created by Scott Lembcke on 11/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Physics.h"
#import "TrajectoryNode.h"
#import "CCTextureCache.h"
#import "MissileSprite.h"

@implementation TrajectoryNode {
	ChipmunkSpace *_space;
	MissileSprite *_template;
}

-(id)initWithSpace:(ChipmunkSpace*)space;
{
	if((self = [super init])){
		_space = space;
		_template = [[MissileSprite alloc] initAtPos:cpvzero vel:cpvzero];
	}
	
	return self;
}

-(void)setPos:(cpVect)pos muzzleVelocity:(cpVect)vel
{
	_template.body.pos = pos;
	_template.body.vel = vel;
}

-(void) draw;
{
	cpBody *body = _template.body.body;
	cpShape *shape = _template.shape.shape;
	cpVect gravity = _space.gravity;
	
	// Check ahead up to 300 frames for a collision.
	for(int i=0; i<300; i++){
		// Manually update the position and velocity of the body
		[_template.body updatePosition:FIXED_DT];
		[_template.body updateVelocity:FIXED_DT gravity:gravity damping:1.0];
		
		// Perform a shape query to see if the cage hit anything.
		if(cpSpaceShapeQuery(_space.space, shape, NULL, NULL)){
			[self drawDot:body->p radius:cpCircleShapeGetRadius(shape) color:ccc4f(1, 0, 0, 0.5)];
			break;
		} else if(i%15==0){
			// Otherwise, just draw a dot every 10 frames along the path.
			float alpha = MIN(i/500.0f, 0.5f);
			[self drawDot:body->p radius:5.0f color:ccc4f(0, 0, 0, alpha)];
		}
	}
	
	[super draw];
	[self clear];
}

@end
