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

#import "HMVectorNode.h"

// Cocos2D seems to have made analoges of all of my functions which is handy.
#define cpv ccp
#define cpvadd ccpAdd
#define cpvsub ccpSub
#define cpvmult ccpMult
#define cpvnormalize ccpNormalize
#define cpvperp ccpPerp
#define cpvneg ccpNeg
#define cpvdot ccpDot
#define cpvzero CGPointZero
#define cpvforangle ccpForAngle

//#define PRINT_GL_ERRORS() for(GLenum err = glGetError(); err; err = glGetError()) NSLog(@"GLError(%s:%d) 0x%04X", __FILE__, __LINE__, err);
#define PRINT_GL_ERRORS() 

typedef struct Vertex {cpVect vertex, texcoord; Color color;} Vertex;
typedef struct Triangle {Vertex a, b, c;} Triangle;

@interface HMVectorNode(){
	GLuint _vao;
	GLuint _vbo;
	
	NSUInteger _bufferCapacity, _bufferCount;
	Vertex *_buffer;
}

@end


@implementation HMVectorNode

@synthesize blendFunc = _blendFunc;

//MARK: Memory

-(void)ensureCapacity:(NSUInteger)count
{
	if(_bufferCount + count > _bufferCapacity){
		_bufferCapacity += MAX(_bufferCapacity, count);
		_buffer = realloc(_buffer, _bufferCapacity*sizeof(Vertex));
		
//		NSLog(@"Resized vertex buffer to %d", _bufferCapacity);
	}
}

-(id)init
{
	if((self = [super init])){
		self.blendFunc = (ccBlendFunc){GL_ONE, GL_ONE_MINUS_SRC_ALPHA};
		
		CCGLProgram *shader = [[CCGLProgram alloc]
			initWithVertexShaderFilename:@"HMVectorNode.vsh"
			fragmentShaderFilename:@"HMVectorNode.fsh"
		];

		[shader addAttribute:@"position" index:kCCVertexAttrib_Position];
		[shader addAttribute:@"texcoord" index:kCCVertexAttrib_TexCoords];
		[shader addAttribute:@"color" index:kCCVertexAttrib_Color];

		[shader link];
		[shader updateUniforms];
		self.shaderProgram = shader;

		[shader release];
		
    glGenVertexArraysOES(1, &_vao);
    glBindVertexArrayOES(_vao);
		
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
		[self ensureCapacity:512];
    
		glEnableVertexAttribArray(kCCVertexAttrib_Position);
    glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, vertex));
		
		glEnableVertexAttribArray(kCCVertexAttrib_TexCoords);
    glVertexAttribPointer(kCCVertexAttrib_TexCoords, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, texcoord));
		
		glEnableVertexAttribArray(kCCVertexAttrib_Color);
    glVertexAttribPointer(kCCVertexAttrib_Color, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, color));
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArrayOES(0);
		PRINT_GL_ERRORS();
	}
	
	return self;
}

-(void)dealloc
{
	NSAssert([EAGLContext currentContext], @"No GL context set!");
	
	free(_buffer); _buffer = 0;
	
	glDeleteBuffers(1, &_vbo); _vbo = 0;
	glDeleteVertexArraysOES(1, &_vao); _vao = 0;
	
	[super dealloc];
}

//MARK: Rendering

-(void)render
{
	glBindBuffer(GL_ARRAY_BUFFER, _vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(Vertex)*_bufferCapacity, _buffer, GL_STREAM_DRAW);
		
	glBindVertexArrayOES(_vao);
	glDrawArrays(GL_TRIANGLES, 0, _bufferCount);
	
	PRINT_GL_ERRORS();
}

-(void)draw
{
	ccGLEnable(CC_GL_BLEND);
	ccGLBlendFunc(_blendFunc.src, _blendFunc.dst);
	
	[shaderProgram_ use];
	[shaderProgram_ setUniformForModelViewProjectionMatrix];
	
	[self render];
	
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindVertexArrayOES(0);
}

//MARK: Immediate Mode

-(void)drawDot:(cpVect)pos radius:(cpFloat)radius color:(Color)color;
{
	NSUInteger vertex_count = 2*3;
	[self ensureCapacity:vertex_count];
	
	Vertex a = {{pos.x - radius, pos.y - radius}, {-1.0, -1.0}, color};
	Vertex b = {{pos.x - radius, pos.y + radius}, {-1.0,  1.0}, color};
	Vertex c = {{pos.x + radius, pos.y + radius}, { 1.0,  1.0}, color};
	Vertex d = {{pos.x + radius, pos.y - radius}, { 1.0, -1.0}, color};
	
	Triangle *triangles = (Triangle *)(_buffer + _bufferCount);
	triangles[0] = (Triangle){a, b, c};
	triangles[1] = (Triangle){a, c, d};
	
	_bufferCount += vertex_count;
}

-(void)drawSegmentFrom:(cpVect)a to:(cpVect)b radius:(cpFloat)radius color:(Color)color;
{
	NSUInteger vertex_count = 6*3;
	[self ensureCapacity:vertex_count];
	
	cpVect n = cpvnormalize(cpvperp(cpvsub(b, a)));
	cpVect t = cpvperp(n);
	
	cpVect nw = cpvmult(n, radius);
	cpVect tw = cpvmult(t, radius);
	cpVect v0 = cpvsub(b, cpvadd(nw, tw));
	cpVect v1 = cpvadd(b, cpvsub(nw, tw));
	cpVect v2 = cpvsub(b, nw);
	cpVect v3 = cpvadd(b, nw);
	cpVect v4 = cpvsub(a, nw);
	cpVect v5 = cpvadd(a, nw);
	cpVect v6 = cpvsub(a, cpvsub(nw, tw));
	cpVect v7 = cpvadd(a, cpvadd(nw, tw));
	
	Triangle *triangles = (Triangle *)(_buffer + _bufferCount);
	triangles[0] = (Triangle){{v0, cpvneg(cpvadd(n, t)), color}, {v1, cpvsub(n, t), color}, {v2, cpvneg(n), color},};
	triangles[1] = (Triangle){{v3, n, color}, {v1, cpvsub(n, t), color}, {v2, cpvneg(n), color},};
	triangles[2] = (Triangle){{v3, n, color}, {v4, cpvneg(n), color}, {v2, cpvneg(n), color},};
	triangles[3] = (Triangle){{v3, n, color}, {v4, cpvneg(n), color}, {v5, n, color},};
	triangles[4] = (Triangle){{v6, cpvsub(t, n), color}, {v4, cpvneg(n), color}, {v5, n, color},};
	triangles[5] = (Triangle){{v6, cpvsub(t, n), color}, {v7, cpvadd(n, t), color}, {v5, n, color},};
	
	_bufferCount += vertex_count;
}

-(void)drawPolyWithVerts:(cpVect *)verts count:(NSUInteger)count width:(cpFloat)width fill:(Color)fill line:(Color)line;
{
	struct ExtrudeVerts {cpVect offset, n;};
	struct ExtrudeVerts extrude[count];
	bzero(extrude, sizeof(struct ExtrudeVerts)*count);
	
	for(int i=0; i<count; i++){
		cpVect v0 = verts[(i-1+count)%count];
		cpVect v1 = verts[i];
		cpVect v2 = verts[(i+1)%count];
		
		cpVect n1 = cpvnormalize(cpvperp(cpvsub(v1, v0)));
		cpVect n2 = cpvnormalize(cpvperp(cpvsub(v2, v1)));
		
		cpVect offset = cpvmult(cpvadd(n1, n2), 1.0/(cpvdot(n1, n2) + 1.0));
		extrude[i] = (struct ExtrudeVerts){offset, n2};
	}
	
	BOOL outline = (line.a > 0.0 && width > 0.0);
	
	NSUInteger triangle_count = 3*count - 2;
	NSUInteger vertex_count = 3*triangle_count;
	[self ensureCapacity:vertex_count];
	
	Triangle *triangles = (Triangle *)(_buffer + _bufferCount);
	Triangle *cursor = triangles;
	
	cpFloat inset = (outline == 0.0 ? 0.5 : 0.0);
	for(int i=0; i<count-2; i++){
		cpVect v0 = cpvsub(verts[0  ], cpvmult(extrude[0  ].offset, inset));
		cpVect v1 = cpvsub(verts[i+1], cpvmult(extrude[i+1].offset, inset));
		cpVect v2 = cpvsub(verts[i+2], cpvmult(extrude[i+2].offset, inset));
		
		*cursor++ = (Triangle){{v0, cpvzero, fill}, {v1, cpvzero, fill}, {v2, cpvzero, fill},};
	}
	
	for(int i=0; i<count; i++){
		int j = (i+1)%count;
		cpVect v0 = verts[i];
		cpVect v1 = verts[j];
		
		cpVect n0 = extrude[i].n;
		
		cpVect offset0 = extrude[i].offset;
		cpVect offset1 = extrude[j].offset;
		
		if(outline){
			cpVect inner0 = cpvsub(v0, cpvmult(offset0, width));
			cpVect inner1 = cpvsub(v1, cpvmult(offset1, width));
			cpVect outer0 = cpvadd(v0, cpvmult(offset0, width));
			cpVect outer1 = cpvadd(v1, cpvmult(offset1, width));
			
			*cursor++ = (Triangle){{inner0, cpvneg(n0), line}, {inner1, cpvneg(n0), line}, {outer1, n0, line}};
			*cursor++ = (Triangle){{inner0, cpvneg(n0), line}, {outer0, n0, line}, {outer1, n0, line}};
		} else {
			cpVect inner0 = cpvsub(v0, cpvmult(offset0, 0.5));
			cpVect inner1 = cpvsub(v1, cpvmult(offset1, 0.5));
			cpVect outer0 = cpvadd(v0, cpvmult(offset0, 0.5));
			cpVect outer1 = cpvadd(v1, cpvmult(offset1, 0.5));
			
			*cursor++ = (Triangle){{inner0, cpvzero, fill}, {inner1, cpvzero, fill}, {outer1, n0, fill}};
			*cursor++ = (Triangle){{inner0, cpvzero, fill}, {outer0, n0, fill}, {outer1, n0, fill}};
		}
	}
	
	_bufferCount += vertex_count;
}

-(void)clear
{
	_bufferCount = 0;
}

@end
