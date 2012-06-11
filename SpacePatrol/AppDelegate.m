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

#import "cocos2d.h"

#import "AppDelegate.h"
#import "SpacePatrolLayer.h"

@implementation AppController

@synthesize window=window_, navController=navController_, director=director_;

// Use a custom projection so the same assets and code can work on iPad/iPhone without changes.
-(void)updateProjection
{
	kmGLMatrixMode(KM_GL_PROJECTION);
	kmGLLoadIdentity();

	kmMat4 orthoMatrix;
	if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
		kmMat4OrthographicProjection(&orthoMatrix, 0, 480, 0, 320, -1024, 1024 );
	} else {
		kmMat4OrthographicProjection(&orthoMatrix, -16, 496, -32, 352, -1024, 1024 );
	}
	kmGLMultMatrix( &orthoMatrix );

	kmGLMatrixMode(KM_GL_MODELVIEW);
	kmGLLoadIdentity();
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Create the main window
	window_ = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	
	CCGLView *glView = [CCGLView viewWithFrame:[window_ bounds]
		pixelFormat:kEAGLColorFormatRGBA8
		depthFormat:0
		preserveBackbuffer:NO
		sharegroup:nil
		multiSampling:NO
		numberOfSamples:0
	];
	
	// Enable multitouch
	[glView setMultipleTouchEnabled:TRUE];
	 
	director_ = (CCDirectorIOS*) [CCDirector sharedDirector];
	
	director_.wantsFullScreenLayout = YES;
	
	// Display FSP and SPF
	[director_ setDisplayStats:TRUE];
	
	// set FPS at 60
	[director_ setAnimationInterval:1.0/60];
	
	// attach the openglView to the director
	[director_ setView:glView];
	
	// for rotation and other messages
	[director_ setDelegate:self];
	
	[director_ setProjection:kCCDirectorProjectionCustom];
	
	// Enables High Res mode (Retina Display) on iPhone 4 and maintains low res on all other devices
	if( ! [director_ enableRetinaDisplay:TRUE] )
		CCLOG(@"Retina Display Not supported");
	
	// Create a Navigation Controller with the Director
	navController_ = [[UINavigationController alloc] initWithRootViewController:director_];
	navController_.navigationBarHidden = YES;
	
	// set the Navigation Controller as the root view controller
	//	[window_ setRootViewController:rootViewController_];
	[window_ addSubview:navController_.view];
	
	// make main window visible
	[window_ makeKeyAndVisible];
	
	if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
		// This is a bit of a hack so that the iPad think it's running at 512x384 points at a 2x scale
		// The retina iPad will have a 4x scale.
		// I modified CCFileUtils slightly to make this work.
		
		director_->winSizeInPoints_ = CGSizeMake(512, 384);
		director_->winSizeInPixels_ = CGSizeMake(1024, 768);
		__ccContentScaleFactor *= 2;
		
		[director_ createStatsLabel];
	}
	
	// Default texture format for PNG/BMP/TIFF/JPEG/GIF images
	// It can be RGBA8888, RGBA4444, RGB5_A1, RGB565
	// You can change anytime.
	[CCTexture2D setDefaultAlphaPixelFormat:kCCTexture2DPixelFormat_RGBA8888];
	
	// If the 1st suffix is not found and if fallback is enabled then fallback suffixes are going to searched. If none is found, it will try with the name without suffix.
	// On iPad HD  : "-ipadhd", "-ipad",  "-hd"
	// On iPad     : "-ipad", "-hd"
	// On iPhone HD: "-hd"
	CCFileUtils *sharedFileUtils = [CCFileUtils sharedFileUtils];
	[sharedFileUtils setEnableFallbackSuffixes:NO];				// Default: NO. No fallback suffixes are going to be used
	[sharedFileUtils setiPhoneRetinaDisplaySuffix:@"-hd"];		// Default on iPhone RetinaDisplay is "-hd"
	[sharedFileUtils setiPadSuffix:@"-hd"];					// Default on iPad is "ipad"
	[sharedFileUtils setiPadRetinaDisplaySuffix:@"-hd"];	// Default on iPad RetinaDisplay is "-ipadhd"
	[sharedFileUtils setiPadRetinaScale:4.0];
	
	// Assume that PVR images have premultiplied alpha
	[CCTexture2D PVRImagesHavePremultipliedAlpha:YES];
	
	// and add the scene to the stack. The director will run it when it automatically when the view is displayed.
	[director_ pushScene: [SpacePatrolLayer scene]]; 
	
	return YES;
}

// Supported orientations: Landscape. Customize it for your own needs
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}


// getting a call, pause the game
-(void) applicationWillResignActive:(UIApplication *)application
{
	if( [navController_ visibleViewController] == director_ )
		[director_ pause];
}

// call got rejected
-(void) applicationDidBecomeActive:(UIApplication *)application
{
	if( [navController_ visibleViewController] == director_ )
		[director_ resume];
}

-(void) applicationDidEnterBackground:(UIApplication*)application
{
	if( [navController_ visibleViewController] == director_ )
		[director_ stopAnimation];
}

-(void) applicationWillEnterForeground:(UIApplication*)application
{
	if( [navController_ visibleViewController] == director_ )
		[director_ startAnimation];
}

// application will be killed
- (void)applicationWillTerminate:(UIApplication *)application
{
	CC_DIRECTOR_END();
}

// purge memory
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	[[CCDirector sharedDirector] purgeCachedData];
}

// next delta time will be zero
-(void) applicationSignificantTimeChange:(UIApplication *)application
{
	[[CCDirector sharedDirector] setNextDeltaTimeZero:YES];
}

- (void) dealloc
{
	[window_ release];
	[navController_ release];
	
	[super dealloc];
}
@end
