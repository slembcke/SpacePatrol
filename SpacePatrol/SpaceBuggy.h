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
#import "cocos2d.h"


@interface SpaceBuggy : NSObject<ChipmunkObject>

// The position of the chassis of the buggy.
@property(nonatomic, readonly) cpVect pos;

// The array of ChipmunkObjects for the buggy.
// This implements the ChipmunkObject protocol and allows you to add
// the buggy to the space simply using [space add:buggy] or similar.
@property(nonatomic, retain) NSArray *chipmunkObjects;

// The parent node for the buggy's sprites.
@property(nonatomic, retain) CCNode *node;

-(id)initWithPosition:(cpVect)pos;

// Update the motors attached to the buggy.
-(void)update:(ccTime)dt throttle:(int)throttle;

// Resync the sprite and body positions.
// Normally you would use something like ChipmunkSprite to do this.
// See the method implementation for why I didn't.
-(void)sync;

@end
