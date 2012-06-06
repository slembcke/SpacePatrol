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

#import "DeformableTerrainSprite.h"

#import "HMVectorNode.h"

#define PRINT_GL_ERRORS() for(GLenum err = glGetError(); err; err = glGetError()) NSLog(@"GLError(%s:%d) 0x%04X", __FILE__, __LINE__, err);
//#define PRINT_GL_ERRORS() 


typedef struct Vertex {
	GLfloat vertex[2];
	GLfloat texcoord0[2];
} Vertex;


@interface DeformableTerrainSprite()

@end


@implementation DeformableTerrainSprite {
	int _tileSize;
	
	HMVectorNode *_debugNode;
	
	CCTexture2D *_texture;
	GLuint _vao, _vbo;
	
	CGImageRef hole;
}

@synthesize texelSize = _texelScale;
@synthesize sampler = _sampler;
@synthesize tiles = _tiles;

-(void)dealloc
{
	CGImageRelease(hole);
	
	glDeleteVertexArraysOES(1, &_vao);
	glDeleteBuffers(1, &_vbo);
}

-(id)initWithSpace:(ChipmunkSpace *)space texelScale:(cpFloat)texelScale tileSize:(int)tileSize;
{
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"Terrain" withExtension:@"png"];
	ChipmunkImageSampler *sampler = [ChipmunkImageSampler samplerWithImageFile:url isMask:TRUE];
	
	hole = [ChipmunkImageSampler loadImage:[[NSBundle mainBundle] URLForResource:@"Hole" withExtension:@"png"]];
	
	[sampler setBorderValue:1.0];
	
	sampler.outputRect = cpBBNew(0.5*texelScale, 0.5*texelScale, (sampler.width - 0.5)*texelScale, (sampler.height - 0.5)*texelScale);
	
	_texture = [[CCTexture2D alloc]
		initWithData:sampler.pixelData.bytes pixelFormat:kCCTexture2DPixelFormat_A8
		pixelsWide:sampler.width pixelsHigh:sampler.height
		contentSize:CGSizeMake(sampler.width, sampler.height)
	];
	
	if((self = [super init])){
		_texelScale = texelScale;
		self.sampler = sampler;
		CGContextConcatCTM(sampler.context, CGAffineTransformMake(1.0/_texelScale, 0.0, 0.0, 1.0/_texelScale, 0.0, 0.0));
		
		
		_tileSize = tileSize;
		_tiles = [[ChipmunkBasicTileCache alloc] initWithSampler:sampler space:space tileSize:_tileSize*_texelScale samplesPerTile:_tileSize + 1 cacheSize:256];
		_tiles.tileOffset = cpv(-0.5*_texelScale, -0.5*_texelScale);
		_tiles.segmentRadius = 2;
		_tiles.simplifyThreshold = 2;
		
		
		CCGLProgram *shader = [[CCGLProgram alloc]
			initWithVertexShaderFilename:@"DeformableTerrain.vsh"
			fragmentShaderFilename:@"DeformableTerrain.fsh"
		];
		
		[shader addAttribute:@"position" index:kCCVertexAttrib_Position];
		[shader addAttribute:@"texcoord0" index:kCCVertexAttrib_TexCoords];
		
		[shader link];
		[shader updateUniforms];
		self.shaderProgram = shader;
		
		
    glGenVertexArraysOES(1, &_vao);
    glBindVertexArrayOES(_vao);
		
		GLfloat w = _texelScale*sampler.width;
		GLfloat h = _texelScale*sampler.height;
		Vertex quad[] = {
			{{0, 0}, {0, 1}},
			{{w, 0}, {1, 1}},
			{{w, h}, {1, 0}},
			{{0, h}, {0, 0}},
		};
		
		glGenBuffers(1, &_vbo);
		glBindBuffer(GL_ARRAY_BUFFER, _vbo);
		glBufferData(GL_ARRAY_BUFFER, 4*sizeof(Vertex), quad, GL_STATIC_DRAW);
		
		glEnableVertexAttribArray(kCCVertexAttrib_Position);
		glEnableVertexAttribArray(kCCVertexAttrib_TexCoords);
		
    glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, vertex));
    glVertexAttribPointer(kCCVertexAttrib_TexCoords, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, texcoord0));
		
    glBindVertexArrayOES(0);
		
//		_debugNode = [HMVectorNode node];
//		[self addChild:_debugNode z:1000];
		
		PRINT_GL_ERRORS();
	}
	
	return self;
}

-(cpFloat)width
{
	return _sampler.width*_texelScale;
}

-(cpFloat)height
{
	return _sampler.height*_texelScale;
}

-(void)draw
{
	ccGLBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	// Will need to be *EXTREMELY* careful with texture states when moving to multi-texturing
	ccGLBindTexture2D(_texture.name);
	
	CCGLProgram *shader = self.shaderProgram;
	[shader use];
	[shader setUniformForModelViewProjectionMatrix];
	
	glBindVertexArrayOES(_vao);
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	glBindVertexArrayOES(0);
	
	PRINT_GL_ERRORS();
}

static inline cpBB
cpBBFromCGRect(CGRect rect)
{
	return cpBBNew(CGRectGetMinX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMaxY(rect));
}

static inline NSInteger
Clamp(int i, int min, int max)
{
	return MAX(min, MIN(i, max));
}

-(void)addHoleAt:(cpVect)pos;
{
	CGContextRef ctx = _sampler.context;
	
	CGFloat radius = 50.0;
	CGRect rect = CGRectMake(pos.x - radius/2.0, pos.y - radius/2.0, radius, radius);
	
//	CGContextSetGrayFillColor(ctx, 0.0, 1.0);
//	CGContextFillEllipseInRect(ctx, rect);
	CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
	CGContextDrawImage(ctx, rect, hole);
	
	[self.tiles markDirtyRect:cpBBFromCGRect(rect)];
	
	CGAffineTransform flip = CGAffineTransformMake(1, 0, 0, -1, 0, _texelScale*_sampler.height);
	CGAffineTransform trans = CGAffineTransformConcat(flip, CGContextGetCTM(ctx));
	
	cpBB bb = cpBBFromCGRect(CGRectApplyAffineTransform(rect, trans));
	int sw = _sampler.width, sh = _sampler.height;
	int x = Clamp(bb.l, 0, sw) & ~3;
	int y = Clamp(bb.b, 0, sh);
	int w = Clamp(bb.r, 0, sw) - x; w = ((w - 1) | 3) + 1;
	int h = Clamp(bb.t, 0, sh) - y;
	
	// x is rounded down by 4 and w is rounded up by 4
	// This ensures the final width is always a multiple of 4
	// This makes glTexSubImage2D() happy.
	
	int stride = CGBitmapContextGetBytesPerRow(ctx);
	const GLubyte *pixels = _sampler.pixelData.bytes;
	
	GLubyte *dirtyPixels = alloca(w*h);
	for(int i=0; i<h; i++) memcpy(dirtyPixels + i*w, pixels + (i + y)*stride + x, w);
	
	glBindTexture(GL_TEXTURE_2D, _texture.name);
	glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, w, h, GL_ALPHA, GL_UNSIGNED_BYTE, dirtyPixels);
	
//	PRINT_GL_ERRORS();
}

@end
