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
#define ENABLE_AA 0

varying mediump vec2 frag_sampler_texcoord;
varying mediump vec2 frag_texcoord;

uniform lowp vec3 sky_color;

uniform sampler2D sampler_texture;
uniform sampler2D terrain_texture;
uniform sampler2D crust_texture;

highp float step_aa(highp float threshold, highp float alpha)
{
#if defined GL_OES_standard_derivatives && ENABLE_AA
	highp float aa = 0.5*fwidth(alpha);
	return smoothstep(threshold - aa, threshold + aa, alpha);
#else
	return step(threshold, alpha);
#endif
}

const highp float THRESHOLD = 0.5;

void main()
{
	gl_FragColor = vec4(sky_color, 1.0);
	
	highp float base = texture2D(sampler_texture, frag_sampler_texcoord).a;
	highp vec4 terrain_color = texture2D(terrain_texture, frag_texcoord);
	gl_FragColor = mix(gl_FragColor, terrain_color, step(THRESHOLD, base));
	
	highp vec4 crust_color = texture2D(crust_texture, frag_texcoord);
	highp float crust = base + 0.1*(2.0*crust_color.a - 1.0);
	gl_FragColor = mix(gl_FragColor, vec4(crust_color.rgb, 1.0), 1.0 - step(0.20, abs(crust - 0.5)));
}
