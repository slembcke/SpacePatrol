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

varying mediump vec2 frag_texcoord0;

uniform mediump vec4 color;
uniform sampler2D texture0;

void main()
{
	highp float alpha = texture2D(texture0, frag_texcoord0).a;
#if defined GL_OES_standard_derivatives && ENABLE_AA
	highp float foo = 0.5*fwidth(alpha);
	gl_FragColor = vec4(color.rgb, smoothstep(0.5 - foo, 0.5 + foo, alpha));
#else
	gl_FragColor = vec4(color.rgb, step(0.5, alpha));
#endif
}
