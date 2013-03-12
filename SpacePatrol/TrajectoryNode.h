//
//  TrajectoryNode.h
//  AngryChipmunks
//
//  Created by Scott Lembcke on 11/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ObjectiveChipmunk.h"
#import "cocos2d.h"

@interface TrajectoryNode : CCDrawNode

-(id)initWithSpace:(ChipmunkSpace*)space;
-(void)setPos:(cpVect)pos muzzleVelocity:(cpVect)vel;

@end
