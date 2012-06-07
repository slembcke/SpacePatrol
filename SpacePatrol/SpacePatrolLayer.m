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

#import <CoreMotion/CoreMotion.h>

#import "SpacePatrolLayer.h"
#import "ChipmunkAutoGeometry.h"
#import "ChipmunkDebugNode.h"
#import "DeformableTerrainSprite.h"

#import "Physics.h"

#define PIXEL_SIZE 4.0
#define TILE_SIZE 32.0

static const ccColor4B SKY_COLOR = {30, 66, 78, 255};


enum Z_ORDER {
	Z_WORLD,
	Z_TERRAIN,
	Z_CRATES,
	Z_MISSILE,
	Z_CLOUD,
	Z_EFFECTS,
	Z_DEBUG,
	Z_MENU,
};


#define WeakSelf(__var__) __unsafe_unretained typeof(*self) *__var__ = self


@interface SpacePatrolLayer()

@end


@implementation SpacePatrolLayer {
	CMMotionManager *motionManager;
	ChipmunkSpace *space;
	ChipmunkDebugNode *debugNode;
	
	CCNode *world;
	DeformableTerrainSprite *terrain;
	
	ChipmunkBody *body;
	
	ccTime _accumulator, _fixedTime;
}

+(CCScene *)scene
{
	CCScene *scene = [CCScene node];
	[scene addChild: [self node]];
	
	return scene;
}

-(id)init
{
	if((self = [super init])){
		world = [CCNode node];
		[self addChild:world z:Z_WORLD];
		
		// Setup the space
		space = [[ChipmunkSpace alloc] init];
		space.gravity = cpv(0.0f, -GRAVITY);
		
		terrain = [[DeformableTerrainSprite alloc] initWithSpace:space texelScale:8.0 tileSize:32];
		[world addChild:terrain z:Z_TERRAIN];
		
		cpFloat mass = 1.0;
		cpFloat radius = 30.0;
		body = [space add:[ChipmunkBody bodyWithMass:mass andMoment:cpMomentForCircle(mass, 0.0, radius, cpvzero)]];
		body.pos = cpv(2.0*radius, terrain.sampler.height*terrain.texelSize/3.0);
		
		ChipmunkShape *shape = [space add:[ChipmunkCircleShape circleWithBody:body radius:radius offset:cpvzero]];
		shape.friction = 1.0;
		
//		[space add:[ChipmunkSimpleMotor simpleMotorWithBodyA:space.staticBody bodyB:body rate:10.0]];
		
		// Add a ChipmunkDebugNode to draw the space.
		debugNode = [ChipmunkDebugNode debugNodeForChipmunkSpace:space];
		[world addChild:debugNode z:Z_DEBUG];
		debugNode.visible = FALSE;
		
		// Show some menu buttons.
		CCMenuItemLabel *reset = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Reset" fontName:@"Helvetica" fontSize:20] block:^(id sender){
			[[CCDirector sharedDirector] replaceScene:[[SpacePatrolLayer class] scene]];
		}];
		reset.position = ccp(50, 300);
		
		CCMenuItemLabel *showDebug = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Show Debug" fontName:@"Helvetica" fontSize:20] block:^(id sender){
			debugNode.visible ^= TRUE;
		}];
		showDebug.position = ccp(400, 300);
		
		CCMenu *menu = [CCMenu menuWithItems:reset, showDebug, nil];
		menu.position = CGPointZero;
		[self addChild:menu z:Z_MENU];
		
		self.isTouchEnabled = TRUE;
	}
	
	return self;
}

-(void)onEnter
{
	motionManager = [[CMMotionManager alloc] init];
	motionManager.accelerometerUpdateInterval = [CCDirector sharedDirector].animationInterval;
	[motionManager startAccelerometerUpdates];
	
	[self scheduleUpdate];
	[super onEnter];
}

-(void)onExit
{
	[motionManager stopAccelerometerUpdates];
	motionManager = nil;
	
	[super onExit];
}

static cpBB
cpBBFromCGRect(CGRect rect)
{
	return cpBBNew(CGRectGetMinX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMaxY(rect));
}

-(void)tick:(ccTime)fixed_dt
{
	[space step:fixed_dt];
}

-(void)update:(ccTime)dt
{
#if TARGET_IPHONE_SIMULATOR
	CMAcceleration gravity = {-1, 0, 0};
#else
	CMAcceleration gravity = motionManager.accelerometerData.acceleration;
#endif
	
	space.gravity = cpvmult(cpv(-gravity.y, gravity.x), GRAVITY);
	
	CGAffineTransform trans = CGAffineTransformInvert([terrain nodeToWorldTransform]);
	CGRect screen = CGRectMake(-100, -100, 680, 520);
	CGRect rect = CGRectApplyAffineTransform(screen, trans);
	
//	NSLog(@"rect: %@", NSStringFromCGRect(rect));
//	[debugNode drawSegmentFrom:rect.origin to:cpvadd(rect.origin, cpv(rect.size.width, rect.size.height)) radius:2.0 color:ccc4f(1, 0, 0, 1)];
	
	[terrain.tiles ensureRect:cpBBFromCGRect(rect)];
	
	// Update the physics
	ccTime fixed_dt = 1.0/240.0;
	
	_accumulator += dt;
	while(_accumulator > fixed_dt){
		[self tick:fixed_dt];
		_accumulator -= fixed_dt;
		_fixedTime += fixed_dt;
	}
	
	world.position = cpvsub(cpv(240, 160), body.pos);
}

-(void)scheduleBlockOnce:(void (^)(void))block delay:(ccTime)delay
{
	// There really needs to be a 
	[self.scheduler scheduleSelector:@selector(invoke) forTarget:[block copy] interval:0.0 paused:FALSE repeat:1 delay:delay];
}

-(void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[terrain addHoleAt:[terrain convertTouchToNodeSpace:touches.anyObject]];
}

-(void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[terrain addHoleAt:[terrain convertTouchToNodeSpace:touches.anyObject]];
}

-(void)ccTouchesEnded:(UITouch *)touch withEvent:(UIEvent *)event
{
}

@end
