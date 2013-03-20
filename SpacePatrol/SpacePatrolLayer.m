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

#import "Physics.h"
#import "DeformableTerrainSprite.h"
#import "SpaceBuggy.h"
#import "SatelliteBody.h"
#import "MissileSprite.h"
#import "TrajectoryNode.h"

#define ENSURE_RANGE 1000.0f

@implementation SpacePatrolLayer {
	// Used for grabbing the accelerometer data
	CMMotionManager *_motionManager;
	
	// The Chipmunk space for the physics simulation.
	ChipmunkSpace *_space;
	// Manages multi-touch grabbable objects.
	ChipmunkMultiGrab *_multiGrab;
	
	// The debug node for drawing the the physics debug overlay.
	CCPhysicsDebugNode *_debugNode;
	// The menu buttons for controlling the car.
	CCMenuItemSprite *_goButton, *_stopButton;
	CCMenuItemSprite *_fireButton;
	CCMenuItemSprite *_flipButton;
	
	// The CCNode that we'll be adding the terrain and car to.
	CCNode *_world;
	// The custom "sprite" that draws the terrain and parallax background.
	DeformableTerrainSprite *_terrain;
	
	// The current UITouch object we are tracking to deform the terrain.
	UITouch *_currentDeformTouch;
	// True if we are digging dirt, false if we are filling
	BOOL _currentDeformTouchRemoves;
	// Location of the last place we deformed the terrain to avoid duplicates
	CGPoint _lastDeformLocation;
	
	// The all important Super Space Ranger certified space buggy.
	SpaceBuggy *_spaceBuggy;
	
	// Timer values for implementing a fixed timestep for the physics.
	ccTime _accumulator, _fixedTime;
	
	bool _zoom;
	TrajectoryNode *_trajectory;
	NSMutableArray *_missiles;
	
	int _ticks;
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
		_world = [CCNode node];
		_world.position = ccp(240, 160);
		_world.contentSize = CGSizeMake(1.0, 1.0);
		[self addChild:_world z:Z_WORLD];
		
		_space = [[ChipmunkSpace alloc] init];
//		_space.gravity = cpv(0.0f, -GRAVITY);
		[_space addCollisionHandler:self typeA:PhysicsIdentifier(MISSILE) typeB:PhysicsIdentifier(TERRAIN) begin:@selector(missileGroundBegin:space:) preSolve:nil postSolve:nil separate:nil];
		
		_multiGrab = [[ChipmunkMultiGrab alloc] initForSpace:_space withSmoothing:cpfpow(0.8, 60) withGrabForce:1e4];
		// Set a grab radius so that you don't have to touch a shape *exactly* in order to pick it up.
		_multiGrab.grabRadius = 50.0;
		
		_terrain = [[DeformableTerrainSprite alloc] initWithFile:@"Terrain.png" space:_space texelScale:32.0 tileSize:16];
		[_world addChild:_terrain z:Z_TERRAIN];
		
		{
			// We need to find the terrain's ground level so we can drop the buggy at the surface.
			// You can't use a raycast because there is no geometry in space until the tile cache adds it.
			// Instead, we'll sample upwards along the terrain's density to find somewhere where the density is low (where there isn't dirt).
			cpVect pos = GRAVITY_ORIGIN;
			while([_terrain.sampler sample:pos] > 0.5) pos.y += 1.0;
			
			// Add the car just above that level.
			_spaceBuggy = [[SpaceBuggy alloc] initWithPosition:cpvadd(pos, cpv(0, 60))];
			[_world addChild:_spaceBuggy.node z:Z_BUGGY];
			[_space add:_spaceBuggy];
		}
		
		// Add a ChipmunkDebugNode to draw the space.
		_debugNode = [CCPhysicsDebugNode debugNodeForChipmunkSpace:_space];
		[_world addChild:_debugNode z:Z_DEBUG];
		_debugNode.visible = FALSE;
		
		{
			// Show some menu buttons.
			CCMenuItemLabel *reset = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Reset" fontName:@"Helvetica" fontSize:20] block:^(id sender){
				[[CCDirector sharedDirector] replaceScene:[[SpacePatrolLayer class] scene]];
			}];
			reset.position = ccp(50, 300);
			
			// TODO Memory leak.
			CCMenuItemLabel *zoom = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Zoom" fontName:@"Helvetica" fontSize:20] target:self selector:@selector(toggleZoom)];
			zoom.position = ccp(400, 300);
			
			CCMenu *menu = [CCMenu menuWithItems:reset, zoom, nil];
			menu.position = CGPointZero;
			[self addChild:menu z:Z_MENU];
		}
		
		{
			_goButton = [CCMenuItemSprite itemWithNormalSprite:[CCSprite spriteWithFile:@"Button.png"] selectedSprite:[CCSprite spriteWithFile:@"Button.png"]];
			_goButton.selectedImage.color = ccc3(128, 128, 128);
			_goButton.position = ccp(480 - 50, 50);
			
			_stopButton = [CCMenuItemSprite itemWithNormalSprite:[CCSprite spriteWithFile:@"Button.png"] selectedSprite:[CCSprite spriteWithFile:@"Button.png"]];
			_stopButton.selectedImage.color = ccc3(128, 128, 128);
			_stopButton.scaleX = -1.0;
			_stopButton.position = ccp(50, 50);
			
			CCMenu *menu = [CCMenu menuWithItems:_goButton, _stopButton, nil];
			menu.position = CGPointZero;
			[self addChild:menu z:Z_MENU];
		}
		
		{
			_fireButton = [CCMenuItemSprite itemWithNormalSprite:[CCSprite spriteWithFile:@"ButtonFire.png"] selectedSprite:[CCSprite spriteWithFile:@"ButtonFire.png"]];
			_fireButton.selectedImage.color = ccc3(128, 128, 128);
			_fireButton.position = ccp(480 - 50, 150);
			
			CCMenu *menu = [CCMenu menuWithItems:_fireButton, nil];
			menu.position = CGPointZero;
			[self addChild:menu z:Z_MENU];
		}
		
		{
			_flipButton = [CCMenuItemSprite itemWithNormalSprite:[CCSprite spriteWithFile:@"ButtonFlip.png"] selectedSprite:[CCSprite spriteWithFile:@"ButtonFlip.png"]];
			_flipButton.selectedImage.color = ccc3(128, 128, 128);
			_flipButton.position = ccp(50, 150);
			
			CCMenu *menu = [CCMenu menuWithItems:_flipButton, nil];
			menu.position = CGPointZero;
			[self addChild:menu z:Z_MENU];
		}
		
		_missiles = [NSMutableArray array];
		
		_trajectory = [[TrajectoryNode alloc] initWithSpace:_space];
		[_world addChild:_trajectory z:Z_TRAJECTORY];
		
		self.touchEnabled = TRUE;
	}
	
	return self;
}

-(void)toggleZoom
{
	_zoom ^= TRUE;
}

-(void)onEnter
{
	_motionManager = [[CMMotionManager alloc] init];
	_motionManager.accelerometerUpdateInterval = [CCDirector sharedDirector].animationInterval;
	[_motionManager startAccelerometerUpdates];
	
	[self scheduleUpdateWithPriority:-100];
	[super onEnter];
	
	glClearColor(SKY_COLOR);
}

-(void)onExit
{
	[_motionManager stopAccelerometerUpdates];
	_motionManager = nil;
	
	[super onExit];
}

// A "tick" is a single fixed time-step
// This method is called 240 times per second.
-(void)tick:(ccTime)fixed_dt
{
	if(_fireButton.isSelected && _ticks%20 == 0){
		[self fire];
	}
	
	// Only terrain geometry that exists inside this "ensure" rect is guaranteed to exist.
	// This keeps the memory and CPU usage very low for the terrain by allowing it to focus only on the important areas.
	// Outside of this rect terrain geometry is not guaranteed to be current or exist at all.
	// I made this rect slightly smaller than the screen so you can see it adding terrain chunks if you turn on debug rendering.
	[_terrain.tiles ensureRect:cpBBNewForCircle(_spaceBuggy.pos, ENSURE_RANGE)];
	
	// Warning: A mistake I made initially was to ensure the screen's rect, instead of the area around the car.
	// This was bad because the view isn't centered on the car until after the physics is run.
	// If the framerate stuttered enough (like during the first frame or two) the buggy could move out of the ensured rect.
	// It would fall right through terrain that never had collision geometry generated for it.
	
	// Update the throttle values on the space buggy's motors.
	int throttle = _goButton.isSelected - _stopButton.isSelected;
	[_spaceBuggy update:fixed_dt throttle:throttle flip:_flipButton.isSelected];
	
	[_space step:fixed_dt];
	_ticks++;
}

-(void)updateGravity
{
//#if TARGET_IPHONE_SIMULATOR
//	// The accelerometer always returns (0, 0, 0) on the simulator which is unhelpful.
//	// Let's hardcode it to be always down instead.
//	CMAcceleration gravity = {-1, 0, 0};
//#else
//	CMAcceleration gravity = _motionManager.accelerometerData.acceleration;
//#endif
//	
//	_space.gravity = cpvmult(cpv(-gravity.y, gravity.x), GRAVITY);
}

-(CGPoint)touchLocation:(UITouch *)touch
{
	return [_terrain convertTouchToNodeSpace:touch];
}

-(void)modifyTerrain
{
	if(!_currentDeformTouch) return;
	
	CGFloat radius = (_zoom ? 4.0 : 1.0)*100.0;
	CGFloat threshold = 0.025*radius;
	
	// UITouch objects are persistent and continue to be updated for as long as the touch is occuring.
	// This is handy because we can conveniently poll a touch's location.
	CGPoint location = [self touchLocation:_currentDeformTouch];
	
	if(
		// Skip deforming the terrain if it's very near to the last place the terrain was deformed.
		ccpDistanceSQ(location, _lastDeformLocation) > threshold*threshold &&
		// Skip filling in dirt if it's too near to the car.
		// If you filled in over the car it would fall through the terrain segments.
		(_currentDeformTouchRemoves || ![_space nearestPointQueryNearest:location maxDistance:0.75*radius layers:COLLISION_RULE_BUGGY_ONLY group:nil].shape)
	){
		[_terrain modifyTerrainAt:location radius:radius remove:_currentDeformTouchRemoves];
		_lastDeformLocation = location;
	}
}

-(cpVect)muzzlePos
{
	ChipmunkBody *buggy = _spaceBuggy.body;
	cpVect mount = cpv(-30.0f, 20.0f);
	
	return [buggy local2world:mount];
}

-(cpVect)muzzleVel
{
	ChipmunkBody *buggy = _spaceBuggy.body;
	cpVect muzzle = cpv(300.0f, 600.0f);
	
	cpVect v_local = cpBodyGetVelAtWorldPoint(buggy.body, self.muzzlePos);
	cpVect v_muzzle = cpvrotate(muzzle, buggy.rot);
	
	return cpvadd(v_local, v_muzzle);
}

-(void)update:(ccTime)dt
{
	[self modifyTerrain];
	[self updateGravity];
	
	// Add the current dynamic timestep to the accumulator.
	_accumulator += dt;
	// Subtract off fixed-sized chunks of time from the accumulator and step
	while(_accumulator > FIXED_DT){
		[self tick:FIXED_DT];
		_accumulator -= FIXED_DT;
		_fixedTime += FIXED_DT;
	}
	
	// Resync the space buggy's sprites.
	// Take a look at the SpaceBuggy class to see why I don't just use ChipmunkSprites.
	[_spaceBuggy sync];
	cpVect buggyPos = _spaceBuggy.pos;
	
	// Scroll the screen as long as we aren't dragging the car.
	if(_multiGrab.grabs.count == 0){
		// Clamp off the position vector so we can't see outside of the terrain sprite.
		CGSize winSize = [CCDirector sharedDirector].winSize;
		cpBB clampingBB = cpBBNew(winSize.width/2.0, winSize.height/2.0, _terrain.width - winSize.width/2.0, _terrain.height - winSize.height/2.0);
		
		// TODO Should smooth this out better to avoid the pops when releasing the buggy.
		cpVect pos = cpBBClampVect(clampingBB, buggyPos);
		_world.anchorPoint = pos;
		_world.rotation = CC_RADIANS_TO_DEGREES(cpvtoangle(cpvsub(pos, GRAVITY_ORIGIN)) - M_PI_2);
	}
	
	float targetScale = (_zoom ? 1.0/8.0 : 1.0);
	_world.scale = _world.scale*pow(targetScale/_world.scale, 1.0 - pow(0.1, dt/0.25));
	
	[_trajectory setPos:self.muzzlePos muzzleVelocity:self.muzzleVel];
	
	for(MissileSprite *missile in [_missiles copy]){
		// Destroy the missiles when they get too far away.
		if(cpvdist(buggyPos, missile.body.pos) > ENSURE_RANGE){
			[self destructMissile:missile];
		}
	}
}

-(void)fire
{
	MissileSprite *missile = [[MissileSprite alloc] initAtPos:self.muzzlePos vel:self.muzzleVel];
	[_space add:missile];
	[_world addChild:missile];
	[_missiles addObject:missile];
	
	ChipmunkBody *buggy = _spaceBuggy.body;
	ChipmunkBody *mbody = missile.body;
	[buggy applyImpulse:cpvmult(mbody.vel, -mbody.mass) offset:cpvsub(self.muzzlePos, buggy.pos)];
}

-(void)destructMissile:(MissileSprite *)missile
{
	CCSprite *explosion = [CCSprite spriteWithFile:@"Explosion.png"];
	explosion.position = missile.position;
	explosion.zOrder = Z_EFFECTS;
	[_world addChild:explosion];
	
	ccTime duration = 0.15;
	[explosion runAction:[CCFadeOut actionWithDuration:duration]];
	[explosion runAction:[CCSequence actions:
		[CCScaleTo actionWithDuration:duration scale:0.5],
		[CCCallBlock actionWithBlock:^{[explosion removeFromParentAndCleanup:TRUE];}],
		nil
	]];
	
	[_terrain modifyTerrainAt:missile.body.pos radius:300.0 remove:TRUE];
	
	[_world removeChild:missile cleanup:TRUE];
	[_space remove:missile];
	[_missiles removeObject:missile];
}

-(bool)missileGroundBegin:(cpArbiter *)arbiter space:(ChipmunkSpace*)space
{
	CHIPMUNK_ARBITER_GET_BODIES(arbiter, missileBody, groundBody);
	MissileSprite *missile = missileBody.data;
	
	[space addPostStepBlock:^{[self destructMissile:missile];} key:missile];
	
	return FALSE;
}

-(void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	for(UITouch *touch in touches){
		cpVect location = [self touchLocation:touch];
//		NSLog(@"sample%@: %f", NSStringFromCGPoint(location), [_terrain.sampler sample:location]);
		[_multiGrab beginLocation:location];
		
		if(!_currentDeformTouch){
			_currentDeformTouch = touch;
			
			// Check the density of the terrain at the touch location to see if we shold be filling or digging.
			cpFloat density = [_terrain.sampler sample:location];
			_currentDeformTouchRemoves = (density < 0.5);
		}
	}
}

-(void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	for(UITouch *touch in touches){
		[_multiGrab updateLocation:[_terrain convertTouchToNodeSpace:touch]];
	}
}

-(void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	for(UITouch *touch in touches){
		[_multiGrab endLocation:[_terrain convertTouchToNodeSpace:touch]];
		
		if(touch == _currentDeformTouch){
			_currentDeformTouch = nil;
		}
	}
}

-(void)ccTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self ccTouchesEnded:touches withEvent:event];
}

@end
