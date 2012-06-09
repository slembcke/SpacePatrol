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

//#extension GL_OES_standard_derivatives : enable

varying mediump vec2 frag_sky_texcoord;
varying mediump vec2 frag_parallax_texcoord;

varying mediump vec2 frag_density_texcoord;
varying mediump vec2 frag_terrain_texcoord;

uniform lowp vec4 crust_color;

uniform sampler2D sky_texture;
uniform sampler2D parallax_texture;

uniform sampler2D density_texture;
uniform sampler2D terrain_texture;
uniform sampler2D crust_texture;
uniform sampler2D mix_texture;

void main()
{
	lowp vec4 sky_color = texture2D(sky_texture, frag_sky_texcoord);
	lowp vec4 parallax_color = texture2D(parallax_texture, frag_parallax_texcoord);
	lowp vec4 bg_color = mix(sky_color, parallax_color, parallax_color.a);
	
	highp float density = texture2D(density_texture, frag_density_texcoord).a;
	highp float crust = texture2D(crust_texture, frag_terrain_texcoord).a;
	lowp vec4 mix_color = texture2D(mix_texture, vec2(density, crust));
	lowp vec4 terrain_color = texture2D(terrain_texture, frag_terrain_texcoord);
	
//	mix_color = smoothstep(0.5, 0.5*fwidth(mix_color) + 0.5, mix_color);
	gl_FragColor = mix(mix(bg_color, crust_color, mix_color.a), terrain_color, mix_color.r);
}
