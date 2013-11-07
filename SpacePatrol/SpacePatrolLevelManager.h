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

@property (assign) cpVect objective1Vect;
@property (assign) cpVect objective2Vect;
@property (assign) cpVect objective3Vect;

@property (assign) BOOL hasReachedObjective1;
@property (assign) BOOL hasReachedObjective2;
@property (assign) BOOL hasReachedObjective3;

@property (assign) cpVect levelFinishVect;

@property (assign) int level;


- (id)initWithLevel:(int)level;


@end
