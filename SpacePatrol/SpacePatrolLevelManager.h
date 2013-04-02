//
//  SpacePatrolLevelManager.h
//  SpacePatrol
//
//  Created by Martin Grider on 4/2/13.
//
//

#import <Foundation/Foundation.h>
#import "ObjectiveChipmunk.h"


@interface SpacePatrolLevelManager : NSObject


@property (strong) NSString *terrainSpriteName;

@property (assign) cpVect player1StartVect;
@property (assign) cpVect levelFinishVect;

@property (assign) int level;


- (id)initWithLevel:(int)level;


@end
