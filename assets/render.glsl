#version 430

uniform int width;
uniform int height;

uniform int mode;

in vec2 fragTexCoord;

out vec4 finalColor;

layout(std430, binding = 0) buffer image_buffer {
	uint pixels[];
};

layout(std430, binding = 1) buffer voltage_buffer {
	float voltages[];
};

float luminance(vec3 v) {
	return dot(v, vec3(0.2126, 0.7152, 0.0722));
}

vec3 rainbowPalette(float t) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.00, 0.33, 0.67);
    return a + b * cos(6.28318 * (c * t + d));
}

float getSmoothVoltage(vec2 uv) {
    float x = uv.x * float(width);
    float y = (uv.y) * float(height);
    int x1 = int(x); int y1 = int(y);
    int x2 = min(x1 + 1, width - 1); int y2 = min(y1 + 1, height - 1);
    x1 = clamp(x1, 0, width - 1); y1 = clamp(y1, 0, height - 1);
    float fractX = fract(x); float fractY = fract(y);
    float v1 = voltages[y1 * width + x1]; float v2 = voltages[y1 * width + x2];
    float v3 = voltages[y2 * width + x1]; float v4 = voltages[y2 * width + x2];
    return mix(mix(v1, v2, fractX), mix(v3, v4, fractX), fractY);
}

vec3 getResist2DColor(float t) {
    vec3 green = vec3(0.0, 0.6, 0.2);
    vec3 white = vec3(1.0, 1.0, 0.9);
    vec3 purple = vec3(0.6, 0.0, 0.8);
    float wave = cos(t * 6.28318);
    vec3 colorMix = mix(green, purple, (sin(t * 6.28318) * 0.5 + 0.5));
    float whiteAmount = smoothstep(0.2, 1.0, wave * 0.5 + 0.5);
    return mix(colorMix, white, whiteAmount);
}

float get_voltage(int x, int y) {
    x = clamp(x, 0, width - 1);
    y = clamp(y, 0, height - 1);
    return voltages[y * width + x];
}

vec3 get_magma_color(float t) {
    t = clamp(t, 0.0, 1.0);

    vec3 c0 = vec3(0.00, 0.00, 0.02);
    vec3 c1 = vec3(0.16, 0.04, 0.35);
    vec3 c2 = vec3(0.60, 0.07, 0.40);
    vec3 c3 = vec3(0.98, 0.55, 0.15);
    vec3 c4 = vec3(0.99, 0.95, 0.60);
    vec3 c5 = vec3(1.00, 1.00, 1.00);

    if (t < 0.20) return mix(c0, c1, t / 0.20);
    if (t < 0.40) return mix(c1, c2, (t - 0.20) / 0.20);
    if (t < 0.60) return mix(c2, c3, (t - 0.40) / 0.20);
    if (t < 0.80) return mix(c3, c4, (t - 0.60) / 0.20);
    return mix(c4, c5, (t - 0.80) / 0.20);
}

vec4 current_mode(vec2 uv) {
    int x = int(uv.x * float(width));
    int y = int(uv.y * float(height));
    x = clamp(x, 0, width - 1); y = clamp(y, 0, height - 1);

    float center = get_voltage(x, y); 
    float right = get_voltage(x + 1, y); 
    float up = get_voltage(x, y + 1); 

    float dx = center - right;
    float dy = center - up;

    float magnitude = sqrt(dx*dx + dy*dy);
    float intensity = magnitude * 50.0;

    uint idx = uint(y * width + x);
    uint data = pixels[idx];
    float brightness = float((data & 0xFFu) + ((data >> 8u)&0xFFu) + ((data >> 16u)&0xFFu)) / (3.0 * 255.0);
    if (brightness < 0.1 && float((data >> 24u) & 0xFFu) > 128.0) return vec4(vec3(0.0), 1.0);
    return vec4(get_magma_color(intensity), 1.0);
}

vec4 voltage_mode(vec2 uv) {
    int x = int(uv.x * float(width));
    int y = int(uv.y * float(height));
    x = clamp(x, 0, width - 1); y = clamp(y, 0, height - 1);
    uint idx = uint(y * width + x);

    uint data = pixels[idx];
    vec4 originalImage = vec4(
            float(data & 0xFFu),
            float((data >> 8u) & 0xFFu),
            float((data >> 16u) & 0xFFu),
            float((data >> 24u) & 0xFFu)
    ) / 255.0;

    float v = voltages[idx]; // getSmoothVoltage(fragTexCoord);
    
    vec3 simColor;

    if (v > 0.99) simColor = vec3(1.0, 0.0, 0.0);
    else if (v < 0.01) simColor = vec3(0.0, 0.0, 1.0);
    else {
        float frequency = 10.0; 
        float phase = v * frequency;
        simColor = getResist2DColor(phase);
        float shadow = sin(phase * 6.28318);
        float shadowFactor = smoothstep(-1.0, -0.5, shadow); 
        simColor *= (0.5 + 0.5 * shadowFactor);
    }

    float inkDensity = (originalImage.r + originalImage.g + originalImage.b) / 3.0;
    if (originalImage.a < 0.1) inkDensity = 0.0;
    if (originalImage.a < 0.5) inkDensity = 1.0; 

    vec3 result = simColor * inkDensity;

    float conductor = 1.0 - inkDensity;

    return vec4(result, 1.0);
}

void main() {
	int x = int(fragTexCoord.x * float(width));
	int y = int(fragTexCoord.y * float(height));
	x = clamp(x, 0, width - 1); y = clamp(y, 0, height - 1);
	uint idx = uint(y * width + x);

	uint data = pixels[idx];
	vec4 originalImage = vec4(
			float(data & 0xFFu),
			float((data >> 8u) & 0xFFu),
			float((data >> 16u) & 0xFFu),
			float((data >> 24u) & 0xFFu)
			) / 255.0;
	if (mode == 1) {
		finalColor = current_mode(fragTexCoord);
		finalColor.rgb = mix(finalColor.rgb, originalImage.rgb, 0.5);
	} 
	if (mode == 2) {
		finalColor = voltage_mode(fragTexCoord);
	}
}
