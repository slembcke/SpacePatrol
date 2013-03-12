//
//  MissileSprite.h
//  SpacePatrol
//
//  Created by Scott Lembcke on 3/12/13.
//
//

#import "ObjectiveChipmunk.h"
#import "CCSprite.h"

@interface MissileSprite : CCSprite <ChipmunkObject>

@property(nonatomic, retain) ChipmunkBody *body;
@property(nonatomic, retain) ChipmunkShape *shape;

@property(nonatomic, readonly) NSArray *chipmunkObjects;

-(id)initAtPos:(cpVect)pos vel:(cpVect)vel;

@end
