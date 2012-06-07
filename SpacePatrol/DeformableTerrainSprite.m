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
	GLfloat base_texcoord[2];
	GLfloat crust_texcoord[2];
} Vertex;


@interface DeformableTerrainSprite()

@end


@implementation DeformableTerrainSprite {
	int _tileSize;
	
	HMVectorNode *_debugNode;
	
	CCTexture2D *_skyTexture;
	CCTexture2D *_parallaxTexture;
	
	CCTexture2D *_densityTexture;
	CCTexture2D *_terrainTexture;
	CCTexture2D *_crustTexture;
	CCTexture2D *_mixTexture;
	GLuint _vao, _vbo;
	
	CGImageRef _hole;
}

@synthesize texelSize = _texelScale;
@synthesize sampler = _sampler;
@synthesize tiles = _tiles;

-(void)dealloc
{
	CGImageRelease(_hole);
	
	glDeleteVertexArraysOES(1, &_vao);
	glDeleteBuffers(1, &_vbo);
}

-(id)initWithSpace:(ChipmunkSpace *)space texelScale:(cpFloat)texelScale tileSize:(int)tileSize;
{
	if((self = [super init])){
		_texelScale = texelScale;
		
		NSURL *url = [[NSBundle mainBundle] URLForResource:@"Terrain" withExtension:@"png"];
		_sampler = [ChipmunkImageSampler samplerWithImageFile:url isMask:TRUE];
		[_sampler setBorderValue:1.0];
		
		CGContextConcatCTM(_sampler.context, CGAffineTransformMake(1.0/_texelScale, 0.0, 0.0, 1.0/_texelScale, 0.0, 0.0));
		_sampler.outputRect = cpBBNew(0.5*texelScale, 0.5*texelScale, (_sampler.width - 0.5)*texelScale, (_sampler.height - 0.5)*texelScale);
		
		_tileSize = tileSize;
		_tiles = [[ChipmunkBasicTileCache alloc] initWithSampler:_sampler space:space tileSize:_tileSize*_texelScale samplesPerTile:_tileSize + 1 cacheSize:256];
		_tiles.tileOffset = cpv(-0.5*_texelScale, -0.5*_texelScale);
		_tiles.segmentRadius = 5.0;
		_tiles.simplifyThreshold = 2.0;
		
		
		_hole = [ChipmunkImageSampler loadImage:[[NSBundle mainBundle] URLForResource:@"Hole" withExtension:@"png"]];;
		
		_skyTexture = [[CCTextureCache sharedTextureCache] addImage:@"Sky.png"];
		
		_parallaxTexture = [[CCTextureCache sharedTextureCache] addImage:@"Parallax.png"];
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		
		_densityTexture = [[CCTexture2D alloc]
			initWithData:_sampler.pixelData.bytes pixelFormat:kCCTexture2DPixelFormat_A8
			pixelsWide:_sampler.width pixelsHigh:_sampler.height
			contentSize:CGSizeMake(_sampler.width, _sampler.height)
		];
		
		_terrainTexture = [[CCTextureCache sharedTextureCache] addImage:@"TerrainDetail.png"];
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		
		// I was too lazy to load an alpha texture the hard way... So I just made a sampler which did it for me.
		// You could use GLKit if you wanted to go iOS 5 only.
		ChipmunkImageSampler *crust = [ChipmunkImageSampler samplerWithImageFile:[[NSBundle mainBundle] URLForResource:@"Crust" withExtension:@"png"] isMask:TRUE];
		_crustTexture = [[CCTexture2D alloc]
			initWithData:crust.pixelData.bytes pixelFormat:kCCTexture2DPixelFormat_A8
			pixelsWide:crust.width pixelsHigh:crust.height
			contentSize:CGSizeMake(crust.width, crust.height)
		];
		
//		_crustTexture = [[CCTextureCache sharedTextureCache] addImage:@"Crust.png"];
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		
		_mixTexture = [[CCTextureCache sharedTextureCache] addImage:@"TerrainMix.png"];
		
		CCGLProgram *shader = [[CCGLProgram alloc]
			initWithVertexShaderFilename:@"DeformableTerrain.vsh"
			fragmentShaderFilename:@"DeformableTerrain.fsh"
		];
		
		[shader addAttribute:@"position" index:0];
		[shader addAttribute:@"density_texcoord" index:1];
		[shader addAttribute:@"texcoord" index:2];
		
		[shader link];
		[shader updateUniforms];
		self.shaderProgram = shader;
		
		CGSize winSize = [CCDirector sharedDirector].winSizeInPixels;
		CGSize texSize = _parallaxTexture.contentSizeInPixels;
		glUniform2f(glGetUniformLocation(shader->program_, "parallax_scale"), winSize.width/texSize.width, winSize.height/texSize.height);
		glUniform1f(glGetUniformLocation(shader->program_, "parallax_speed"), 1.0/10000.0);
		glUniform1f(glGetUniformLocation(shader->program_, "parallax_offset"), 0.5);
		
//		glUniform4f(glGetUniformLocation(shader->program_, "sky_color"), 30.0/255.0, 66.0/255.0, 78.0/255.0, 1.0);
		glUniform4f(glGetUniformLocation(shader->program_, "crust_color"), 156.0/255.0, 122.0/255.0, 92.0/255.0, 1.0);
		
		glUniform1i(glGetUniformLocation(shader->program_, "density_texture"), 0);
		glUniform1i(glGetUniformLocation(shader->program_, "terrain_texture"), 1);
		glUniform1i(glGetUniformLocation(shader->program_, "crust_texture"), 2);
		glUniform1i(glGetUniformLocation(shader->program_, "mix_texture"), 3);
		glUniform1i(glGetUniformLocation(shader->program_, "sky_texture"), 4);
		glUniform1i(glGetUniformLocation(shader->program_, "parallax_texture"), 5);
		
		
    glGenVertexArraysOES(1, &_vao);
    glBindVertexArrayOES(_vao);
		
		GLfloat sw = _texelScale*_sampler.width;
		GLfloat sh = _texelScale*_sampler.height;
		
		GLfloat tw = sw/_terrainTexture.contentSize.width;
		GLfloat th = sh/_terrainTexture.contentSize.height;
		
		Vertex quad[] = {
			{{ 0,  0}, {0, 1}, { 0, th}},
			{{sw,  0}, {1, 1}, {tw, th}},
			{{sw, sh}, {1, 0}, {tw,  0}},
			{{ 0, sh}, {0, 0}, { 0,  0}},
		};
		
		glGenBuffers(1, &_vbo);
		glBindBuffer(GL_ARRAY_BUFFER, _vbo);
		glBufferData(GL_ARRAY_BUFFER, 4*sizeof(Vertex), quad, GL_STATIC_DRAW);
		
		glEnableVertexAttribArray(0);
		glEnableVertexAttribArray(1);
		glEnableVertexAttribArray(2);
		
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, vertex));
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, base_texcoord));
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, crust_texcoord));
		
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
	ccGLEnable(CC_GL_BLEND);
	ccGLBindTexture2D(_densityTexture.name);
	
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, _terrainTexture.name);
	
	glActiveTexture(GL_TEXTURE2);
	glBindTexture(GL_TEXTURE_2D, _crustTexture.name);
	
	glActiveTexture(GL_TEXTURE3);
	glBindTexture(GL_TEXTURE_2D, _mixTexture.name);
	
	glActiveTexture(GL_TEXTURE4);
	glBindTexture(GL_TEXTURE_2D, _skyTexture.name);
	
	glActiveTexture(GL_TEXTURE5);
	glBindTexture(GL_TEXTURE_2D, _parallaxTexture.name);
	
	glActiveTexture(GL_TEXTURE0);
	
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
	
	CGFloat radius = 100.0;
	CGRect rect = CGRectMake(pos.x - radius/2.0, pos.y - radius/2.0, radius, radius);
	
	CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
	CGContextDrawImage(ctx, rect, _hole);
	
	[self.tiles markDirtyRect:cpBBFromCGRect(rect)];
	
	CGAffineTransform flip = CGAffineTransformMake(1, 0, 0, -1, 0, _texelScale*_sampler.height);
	CGAffineTransform trans = CGAffineTransformConcat(flip, CGContextGetCTM(ctx));
	
	cpBB bb = cpBBFromCGRect(CGRectApplyAffineTransform(rect, trans));
	int sw = _sampler.width, sh = _sampler.height;
	int x = Clamp(bb.l - 1.0, 0, sw) & ~3;
	int y = Clamp(bb.b - 1.0, 0, sh);
	int w = Clamp(bb.r + 1.0, 0, sw) - x; w = ((w - 1) | 3) + 1;
	int h = Clamp(bb.t + 1.0, 0, sh) - y;
	
	// x is rounded down by 4 and w is rounded up by 4
	// This ensures the final width is always a multiple of 4 bytes
	// This makes glTexSubImage2D() happy.
	
	int stride = CGBitmapContextGetBytesPerRow(ctx);
	const GLubyte *pixels = _sampler.pixelData.bytes;
	
	GLubyte *dirtyPixels = alloca(w*h);
	for(int i=0; i<h; i++) memcpy(dirtyPixels + i*w, pixels + (i + y)*stride + x, w);
	
	glBindTexture(GL_TEXTURE_2D, _densityTexture.name);
	glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, w, h, GL_ALPHA, GL_UNSIGNED_BYTE, dirtyPixels);
	
//	PRINT_GL_ERRORS();
}

@end
