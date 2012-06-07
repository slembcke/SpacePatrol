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

uniform highp mat4 projection;
uniform highp float parallax_scale;
uniform highp float parallax_offset;

attribute highp vec2 position;
attribute mediump vec2 density_texcoord;
attribute mediump vec2 texcoord;

varying mediump vec2 frag_sky_texcoord;
varying mediump vec2 frag_parallax_texcoord;

varying mediump vec2 frag_density_texcoord;
varying mediump vec2 frag_terrain_texcoord;

uniform mat4 u_MVPMatrix;

void main()
{
	highp vec4 clip_space = u_MVPMatrix*vec4(position, 0, 1);
	gl_Position = clip_space;
	
	mediump vec2 texture_space = (-0.5*clip_space + 0.5).xy;
	frag_sky_texcoord = texture_space;
	frag_parallax_texcoord = texture_space - position*parallax_scale + vec2(0.0, parallax_offset);
	
	frag_density_texcoord = density_texcoord;
	frag_terrain_texcoord = texcoord;
}
