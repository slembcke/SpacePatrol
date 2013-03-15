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

#import "ObjectiveChipmunk.h"
#import "ChipmunkAutoGeometry.h"

#import "cocos2d.h"

#define SKY_COLOR 29.0/255.0, 63.0/255.0, 75.0/255.0, 1.0

@interface DeformableTerrainSprite : CCNode

// How much to upscale the terrain when rendering it to the screen.
@property(nonatomic, readonly) cpFloat texelSize;

// The sampler created for the terrain.
@property(nonatomic, readonly, strong) ChipmunkImageSampler *sampler;
// The tile cache created for the terrain.
@property(nonatomic, readonly, strong) ChipmunkBasicTileCache *tiles;

// The width and height of the terrain. (texelSize times the image width or height)
@property(nonatomic, readonly) cpFloat width;
@property(nonatomic, readonly) cpFloat height;

-(id)initWithFile:(NSString *)filename space:(ChipmunkSpace *)space texelScale:(cpFloat)texelScale tileSize:(int)tileSize;

// Add or remove dirt at the given location.
-(void)modifyTerrainAt:(cpVect)pos radius:(cpFloat)radius remove:(BOOL)remove;

@end
