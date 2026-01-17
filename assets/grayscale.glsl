#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
out vec4 finalColor;

const float threshold = 50.0 / 256.0;

float luminance(vec3 v) {
	return dot(v, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
	vec4 texelColor = texture(texture0, fragTexCoord);
	float lum = luminance(texelColor.rgb);
	float r = texelColor.r;
	float g = texelColor.g;
	float b = texelColor.b;
	float bw = r + g + b;

	if (bw>threshold) { 
		if(r*3 > bw) {
		}
		else if(b*3>bw) {
		}
		else {
		}
	}

	finalColor = vec4(vec3(lum), 1.0);
}
