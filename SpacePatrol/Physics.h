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

#import <Foundation/Foundation.h>

// I usually like to make a Physics.h/m where I throw some of my physics related utility functions and constants.

// Cocoa doesn't seem to have a function that can intern strings.
// Selectors work pretty much the same way and we just need a reference.
#define PhysicsIdentifier(key) ((__bridge id)(void *)(@selector(key)))

// Create some collision rules for fancy layer based filtering.
// There is more information about how this works in the Chipmunk docs.
#define COLLISION_RULE_TERRAIN_BUGGY (1<<0)
#define COLLISION_RULE_BUGGY_ONLY (1<<1)

// Bitwise or the rules together to get the layers for a certain shape type.
#define COLLISION_LAYERS_TERRAIN (COLLISION_RULE_TERRAIN_BUGGY)
#define COLLISION_LAYERS_BUGGY (COLLISION_RULE_TERRAIN_BUGGY | COLLISION_RULE_BUGGY_ONLY)

#define GRAVITY 1200.0f

#define WHEEL_MASS 0.25
#define CHASSIS_MASS 1.0

#define COG_ADJUSTMENT cpv(5.0, -10.0)

#define FRONT_SPRING 150.0
#define FRONT_DAMPING 3.0

#define REAR_SPRING 100.0
#define REAR_DAMPING 3.0

#define ROLLING_FRICTION 5e2

#define ENGINE_MAX_TORQUE 6.0e4
#define ENGINE_MAX_W 60
#define BRAKING_TORQUE 3.0e4

#define DIFFERENTIAL_TORQUE 0.5
