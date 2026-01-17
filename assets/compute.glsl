#version 430

uniform int width;
uniform int height;

layout(local_size_x = 16, local_size_y = 16) in;

layout(std430, binding = 0) buffer image_buffer {
	uint pixels[];
};

layout(std430, binding = 1) buffer read_buffer {
	float read[];
};

layout(std430, binding = 2) buffer write_buffer {
	float write[];
};

float luminance(vec3 v) {
	return dot(v, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
	uint x = gl_GlobalInvocationID.x;
	uint y = gl_GlobalInvocationID.y;
	if (x >= width || y >= height) return;

	uint idx = (y * width + x);

	float threshold = 50.0 / 255.0;

	uint data = pixels[(y * width) + x];
	float r = float(data & 0xFFu) / 255.0;
	float g = float((data >> 8u) & 0xFFu) / 255.0;
	float b = float((data >> 16u) & 0xFFu) / 255.0;
	float a = float((data >> 16u) & 0xFFu) / 255.0;

	float brightness = (r + g + b) / 3.0;
	bool isWall = (brightness < 0.2 && a > 0.1);
	if (a < 0.1) {
		write[idx] = 0.0;
		return;
	}
	if (isWall) {
		write[idx] = 0.0;
		return;
	}
	if (r > 0.2 && r > g && r > b) {
		write[idx] = 1.0;
		return;
	}

	if (b > 0.2 && b > r && b > g) {
		write[idx] = 0.0;
		return;
	}

	if (x > 0 && x < width - 1 && y > 0 && y < height - 1) {
		float totalVoltage = 0.0;
	    	float totalWeight = 0.0;
		for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
		    
		    if (dx == 0 && dy == 0) continue;

		    int nx = int(x) + dx;
		    int ny = int(y) + dy;

		    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
			uint nIdx = ny * width + nx;

			uint nData = pixels[nIdx];
			float nR = float(nData & 0xFFu); // 0..255
			float nG = float((nData >> 8u) & 0xFFu);
			float nB = float((nData >> 16u) & 0xFFu);
			
			if ((nR + nG + nB) > 10.0) {
			    
			    float weight = (abs(dx) + abs(dy) == 2) ? 0.7071 : 1.0;

			    totalVoltage += read[nIdx] * weight;
			    totalWeight += weight;
			}
		    }
		}
	    }
	    if (totalWeight > 0.0) {
		write[idx] = totalVoltage / totalWeight;
	    } else {
		write[idx] = read[idx];
	    }
	} else {
		write[idx] = 0.0;
	}
}
