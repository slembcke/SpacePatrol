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
		switch (level) {
			case 1:
			default:
				_terrainSpriteName = @"Terrain.png";
				_player1StartVect = cpv(4096.0, 7776.0);
				_levelFinishVect = GRAVITY_ORIGIN;
				break;
		}
	}
	return self;
}


@end
