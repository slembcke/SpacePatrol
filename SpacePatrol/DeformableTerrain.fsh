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

#extension GL_OES_standard_derivatives : enable

// Enabling AA of the terrain will probably cut the framerate in half on an iPhone 4
#define ENABLE_AA 1

varying mediump vec2 frag_sampler_texcoord;
varying mediump vec2 frag_texcoord;

uniform lowp vec3 sky_color;
uniform lowp vec3 crust_color;

uniform sampler2D sampler_texture;
uniform sampler2D terrain_texture;
uniform sampler2D crust_texture;

highp float step2(highp float threshold, highp float alpha)
{
	const highp float aa = 0.02;
	return smoothstep(threshold - aa, threshold + aa, alpha);
}

highp float step_aa(highp float threshold, highp float alpha)
{
#if defined GL_OES_standard_derivatives && ENABLE_AA
	highp float aa = 0.5*fwidth(alpha);
	return smoothstep(threshold - aa, threshold + aa, alpha);
#else
	return step2(threshold, alpha);
#endif
}

const highp float THRESHOLD = 0.5;

void main()
{
	lowp vec3 color = sky_color;
	highp float base = texture2D(sampler_texture, frag_sampler_texcoord).a;

	lowp vec3 terrain_color = texture2D(terrain_texture, frag_texcoord).rgb;
	color = mix(color, terrain_color, step(THRESHOLD, base));
	
	lowp float crust = mix(0.5, texture2D(crust_texture, frag_texcoord).a, 0.6);
	color = mix(color, crust_color, 1.0 - step_aa(0.15, abs(crust - base)));
	
	gl_FragColor = vec4(color, 1.0);
}
