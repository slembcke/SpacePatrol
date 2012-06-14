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
#import "Physics.h"

#define PRINT_GL_ERRORS() for(GLenum err = glGetError(); err; err = glGetError()) NSLog(@"GLError(%s:%d) 0x%04X", __FILE__, __LINE__, err);
//#define PRINT_GL_ERRORS() 


// The vertex format used with the terrain shader.
typedef struct Vertex {
	GLfloat position[2];
	// The texcoord of density texture.
	GLfloat density_texcoord[2];
	// The texcoord for the terain/crust detail textures.
	GLfloat terrain_texcoord[2];
} Vertex;


@implementation DeformableTerrainSprite {
	CGImageRef _hole;
	CGImageRef _fill;
	
	CCTexture2D *_skyTexture;
	CCTexture2D *_parallaxTexture;
	
	CCTexture2D *_densityTexture;
	CCTexture2D *_terrainTexture;
	CCTexture2D *_crustTexture;
	CCTexture2D *_mixTexture;
	
	GLuint _vao, _vbo;
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

-(id)initWithFile:(NSString *)filename space:(ChipmunkSpace *)space texelScale:(cpFloat)texelScale tileSize:(int)tileSize;
{
	if((self = [super init])){
		_texelScale = texelScale;
		
		// Load up the sampler with the terrain texture.
		// Loading it as a "mask" means to load it as greyscale instead of RGBA.
		NSURL *url = [[NSBundle mainBundle] URLForResource:filename withExtension:nil];
		_sampler = [ChipmunkImageSampler samplerWithImageFile:url isMask:TRUE];
		// Give the sampler a dense border.
		// This means that when reading outside of the image bounds will be solid,
		// causing it to put an edge around the world for us.
		[_sampler setBorderValue:1.0];
		
		// Set the CGContext's drawing coordinates to match our Chipmunk/Cocos2D coordinates.
		CGContextConcatCTM(_sampler.context, CGAffineTransformMake(1.0/_texelScale, 0.0, 0.0, 1.0/_texelScale, 0.0, 0.0));
		// Set the output rect of the sampler to match the coordinates as well.
		_sampler.outputRect = cpBBNew(0.5*texelScale, 0.5*texelScale, (_sampler.width - 0.5)*texelScale, (_sampler.height - 0.5)*texelScale);
		
		// The tile cache is what does all the geometry processing work for us.
		// It splits the world into tiles (square chunks) and only processing the tiles that are onscreen.
		// You have to tell it the screen's rectangle every frame. This is performed in [SpacePatrolLayer update:].
		// From there it figures out which tiles need to be created (or recreated if the terrain has been deformed).
		// It completely handles creating and adding the segment shapes for a tile to the space, and removing them when the tile is uncached.
		// The cache size is the number of tiles it will keep in memory at a time.
		_tiles = [[ChipmunkBasicTileCache alloc] initWithSampler:_sampler space:space tileSize:tileSize*_texelScale samplesPerTile:tileSize + 1 cacheSize:20];
		// Offset the tile cache sampling locations by half a texel so it hits texel centers.
		// Things wouldn't quite line up correctly if you didn't do this.
		_tiles.tileOffset = cpv(-0.5*_texelScale, -0.5*_texelScale);
		// Allowed simplification threshold of the contour. (in points)
		_tiles.simplifyThreshold = 1.0;
		// Set some of the properties for the segments it will generate.
		_tiles.segmentLayers = COLLISION_LAYERS_TERRAIN;
		_tiles.segmentRadius = 5.0;
		
		// OK! that was sort of a lot of coordinates to get lined up correctly. In case you missed some of them:
		// 1) Align the CGContext's drawing coordinates with Chipmunk/Cocos coordinates.
		// 2) Align the sampler output coordinates with Chipmunk/Cocos coordinates.
		// 3) Offset the tile cache by half a texel so that it will sample at texel centers.
		
		
		// Load up some CGImages for digging or filling on the terrain density texture in the CGBitmapContext. 
		_hole = [ChipmunkImageSampler loadImage:[[NSBundle mainBundle] URLForResource:@"Hole" withExtension:@"png"]];
		_fill = [ChipmunkImageSampler loadImage:[[NSBundle mainBundle] URLForResource:@"Mound" withExtension:@"png"]];
		
		
		// The Chipmunk/autogeometry setup is done at this point.
		// Now we need to set up the terrain rendering shader and all it's resources.
		
		// The far background layer of the parallax.
		// Just a lame blue gradient in this demo. ;)
		_skyTexture = [[CCTextureCache sharedTextureCache] addImage:@"Sky.png"];
		
		// Load up the scrolling parallax background.
		_parallaxTexture = [[CCTextureCache sharedTextureCache] addImage:@"Parallax.png"];
		// Set it to repeat in the x-axis so it can scroll endlessly.
		// Leave it at the defaults to clamp on the y-axis though.
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		
		// Load up an alpha texture for the terrain density from our ChipmunkImageSampler.
		_densityTexture = [[CCTexture2D alloc]
			initWithData:_sampler.pixelData.bytes pixelFormat:kCCTexture2DPixelFormat_A8
			pixelsWide:_sampler.width pixelsHigh:_sampler.height
			contentSize:CGSizeMake(_sampler.width, _sampler.height)
		];
		
		// Load up the wavy brown terrain detail texture.
		_terrainTexture = [[CCTextureCache sharedTextureCache] addImage:@"TerrainDetail.png"];
		// If the texture was already loaded previously, the texture won't be bound.
		// You really only need to set the tex params once, but it's easier not to.
		ccGLBindTexture2D(_terrainTexture.name);
		// Set it to repeat on both the x and y axes.
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		
		// Load a lookup texture for perturbing the crust layer on top of the terrain.
		// This is what gives the crust it's organic veiny look.
		// I was too lazy to load an alpha texture the hard way... So I just made a sampler which did it for me.
		// You could also use GLKit or a PVR file... but meh.
		ChipmunkImageSampler *crust = [ChipmunkImageSampler samplerWithImageFile:[[NSBundle mainBundle] URLForResource:@"Crust" withExtension:@"png"] isMask:TRUE];
		_crustTexture = [[CCTexture2D alloc]
			initWithData:crust.pixelData.bytes pixelFormat:kCCTexture2DPixelFormat_A8
			pixelsWide:crust.width pixelsHigh:crust.height
			contentSize:CGSizeMake(crust.width, crust.height)
		];
		// Set it to repeat on both the x and y axes.
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		
		// Load up a lookup texture that specifies how to blend the different layers based on the terrain density and crust texture.
		_mixTexture = [[CCTextureCache sharedTextureCache] addImage:@"TerrainMix.png"];
		// This will be indirectly sampled in all sorts of funky ways, so let's set it up to use the highest quality filtering.
		// This will prevent the crust layer from looking blocky.
		glGenerateMipmap(GL_TEXTURE_2D);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 4);
		
		
		// Create the shader! (finally).
		CCGLProgram *shader = [[CCGLProgram alloc]
			initWithVertexShaderFilename:@"DeformableTerrain.vsh"
			fragmentShaderFilename:@"DeformableTerrain.fsh"
		];
		
		// Bind the vertex attribute locations.
		[shader addAttribute:@"position" index:0];
		[shader addAttribute:@"density_texcoord" index:1];
		[shader addAttribute:@"terrain_texcoord" index:2];
		
		// Compile/Link the shader and set it up.
		[shader link];
		[shader updateUniforms];
		self.shaderProgram = shader;
		
		// Set the parameters for the parallax scrolling layer.
		CGSize winSize = [CCDirector sharedDirector].winSizeInPixels;
		CGSize texSize = _parallaxTexture.contentSizeInPixels;
		glUniform2f(glGetUniformLocation(shader->program_, "parallax_scale"), winSize.width/texSize.width, winSize.height/texSize.height);
		glUniform1f(glGetUniformLocation(shader->program_, "parallax_speed"), 1.0/10000.0);
		glUniform1f(glGetUniformLocation(shader->program_, "parallax_offset"), 0.5);
		
		// Set the color for the crust.
		// I wanted to read the color out of the crust perturbing lookup texture, but Cocos's premultiplied alpha loading breaks that.
		// I could have created a PVR file for the texture... but that sounded like a lot of work to set up for one texture.
		glUniform4f(glGetUniformLocation(shader->program_, "crust_color"), 156.0/255.0, 122.0/255.0, 92.0/255.0, 1.0);
		
		// Bind the texture units in the shader.
		glUniform1i(glGetUniformLocation(shader->program_, "density_texture"), 0);
		glUniform1i(glGetUniformLocation(shader->program_, "terrain_texture"), 1);
		glUniform1i(glGetUniformLocation(shader->program_, "crust_texture"), 2);
		glUniform1i(glGetUniformLocation(shader->program_, "mix_texture"), 3);
		glUniform1i(glGetUniformLocation(shader->program_, "sky_texture"), 4);
		glUniform1i(glGetUniformLocation(shader->program_, "parallax_texture"), 5);
		
		
		// Create the VAO for our node.
    glGenVertexArraysOES(1, &_vao);
    glBindVertexArrayOES(_vao);
		
		GLfloat sw = _texelScale*_sampler.width;
		GLfloat sh = _texelScale*_sampler.height;
		
		GLfloat tw = sw/_terrainTexture.contentSize.width/2.0;
		GLfloat th = sh/_terrainTexture.contentSize.height/2.0;
		
		// Create the geometry for our terrain quad.
		// The terrain texcoords are spread over (0, 0) to help minimize filtering artifacts due to the extreme sampling range.
		// In a shipping game you probably would want to split this into several more quads though.
		// There is some pretty strong ASF artifacts... but it's not worth the extra effort for a demo.
		Vertex quad[] = {
			{{ 0,  0}, {0, 1}, {-tw,  th}},
			{{sw,  0}, {1, 1}, { tw,  th}},
			{{sw, sh}, {1, 0}, { tw, -th}},
			{{ 0, sh}, {0, 0}, {-tw, -th}},
		};
		
		// Generate and fill a VBO with the vertex data.
		glGenBuffers(1, &_vbo);
		glBindBuffer(GL_ARRAY_BUFFER, _vbo);
		glBufferData(GL_ARRAY_BUFFER, 4*sizeof(Vertex), quad, GL_STATIC_DRAW);
		
		// Set up the vertex arrays.
		glEnableVertexAttribArray(0);
		glEnableVertexAttribArray(1);
		glEnableVertexAttribArray(2);
		
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, position));
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, density_texcoord));
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, terrain_texcoord));
		
		// When working with VOAs in Cocos2D 2.0, make sure to set the 0 VAO when you are done.
		// Cocos2D doesn't currently track VAO state.
    glBindVertexArrayOES(0);
		
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
	// Disable alpha blending for a large speed improvement.
	// We are drawing all of the background and foreground layers in the shader anyway.
	ccGLEnable(0);
	
	// Bind texture 0 using the Cocos2D state-caching wrapper function.
	ccGLBindTexture2D(_densityTexture.name);
	
	// Bind the rest of the texture units.
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
	
	// Bind the shader and set the matrix.
	CCGLProgram *shader = self.shaderProgram;
	[shader use];
	[shader setUniformForModelViewProjectionMatrix];
	
	// Bind the VAO and draw.
	glBindVertexArrayOES(_vao);
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	
	// Remember to revert the VAO state.
	glBindVertexArrayOES(0);
	
	PRINT_GL_ERRORS();
}

// Hmm... I should probably throw this in a Chipmunk utility header somewhere.
// I keep copy pasting it around.
static inline cpBB
cpBBFromCGRect(CGRect rect)
{
	return cpBBNew(CGRectGetMinX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMaxY(rect));
}

static inline int
ClampInt(int i, int min, int max)
{
	return MAX(min, MIN(i, max));
}

// This is where the deforming magic happens! :D
-(void)modifyTerrainAt:(cpVect)pos radius:(cpFloat)radius remove:(BOOL)remove;
{
	CGContextRef ctx = _sampler.context;
	CGRect rect = CGRectMake(pos.x - radius/2.0, pos.y - radius/2.0, radius, radius);
	
	// Pick a blending mode and image and draw on the terrain density texture.
	if(remove){
		CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
		CGContextDrawImage(ctx, rect, _hole);
	} else {
		CGContextSetBlendMode(ctx, kCGBlendModeScreen);
		CGContextDrawImage(ctx, rect, _fill);
	}
	
	// Mark the rect we just modified as dirty in the tile cache.
	[self.tiles markDirtyRect:cpBBFromCGRect(rect)];
	
	// Construct a matrix to convert from drawing coordinates to pixels.
	CGAffineTransform flip = CGAffineTransformMake(1, 0, 0, -1, 0, _texelScale*_sampler.height);
	CGAffineTransform trans = CGAffineTransformConcat(flip, CGContextGetCTM(ctx));
	// Get the rect of the dirty pixels:
	CGRect dirty = CGRectApplyAffineTransform(rect, trans);
	
	// Clamp the pixel rect to the density bitmap's bounds.
	// Also to make glTexSubImage2D() happy, the row stride always needs to be a multiple of 4 bytes.
	// Since we are using an 8bpp alpha texture it's important to get this right.
	// x is rounded down by 4 and w is rounded up by 4.
	// This ensures a correct stride size even when the rect is clipped by the left or right edges.
	int sw = _sampler.width, sh = _sampler.height;
	int x = ClampInt(floor(CGRectGetMinX(dirty)), 0, sw) & ~3;
	int y = ClampInt(floor(CGRectGetMinY(dirty)), 0, sh);
	int w = ClampInt( ceil(CGRectGetMaxX(dirty)), 0, sw) - x; w = ((w - 1) | 3) + 1;
	int h = ClampInt( ceil(CGRectGetMaxY(dirty)), 0, sh) - y;
	
	int stride = CGBitmapContextGetBytesPerRow(ctx);
	const GLubyte *pixels = _sampler.pixelData.bytes;
	
	// Use alloca() to make a little buffer on the stack and blit the rect into it.
	GLubyte *dirtyPixels = alloca(w*h);
	for(int i=0; i<h; i++) memcpy(dirtyPixels + i*w, pixels + (i + y)*stride + x, w);
	
	// Finally replace the dirty pixels in the texture.
	// Unfortunately this part is a little slow and may cause the framerate to stutter when the terrain is constantly deformed.
	// Ideally you'd want to do this asyncronously, but I'm not really sure how at the moment.
	glBindTexture(GL_TEXTURE_2D, _densityTexture.name);
	glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, w, h, GL_ALPHA, GL_UNSIGNED_BYTE, dirtyPixels);
	
//	PRINT_GL_ERRORS();
}

@end
