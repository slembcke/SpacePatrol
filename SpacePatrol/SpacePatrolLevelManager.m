//
//  SpacePatrolLevelManager.m
//  SpacePatrol
//
//  Created by Martin Grider on 4/2/13.
//
//

#import "SpacePatrolLevelManager.h"
#import "Physics.h"


@implementation SpacePatrolLevelManager


- (id)initWithLevel:(int)level
{
	self = [super init];
	if (self) {
		_level = level;
		_hasReachedObjective1 = NO;
		_hasReachedObjective2 = NO;
		_hasReachedObjective3 = NO;
		switch (level) {
			case 1:
			default:
				_terrainSpriteName = @"Terrain.png";
				_player1StartVect = cpv(4096.0, 7776.0);
				_objective1Vect = cpv(64*3*32, 64*32*2);
				_objective2Vect = cpv(64*2*32, 64*32*1);
				_objective3Vect = cpv(64*1*32, 64*32*2);
				_levelFinishVect = GRAVITY_ORIGIN;
				break;
		}
	}
	return self;
}


@end
