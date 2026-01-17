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

	if (x == 0 || y == 0 || x >= width - 1 || y >= height - 1) {
		if (x < width && y < height) write[y * width + x] = 0.0;
		return;
	}

	uint idx = (y * width + x);

	float threshold = 50.0 / 255.0;

	vec4 color = unpackUnorm4x8(pixels[idx]);

	float brightness = (color.r + color.g + color.b) / 3.0;
	bool is_wall = (brightness < 0.2) || (color.a < 0.1);

	if (is_wall) {
		write[idx] = 0.0;
		return;
	}
	if (color.r > 0.5 && color.g < 0.2 && color.b < 0.2) {
		write[idx] = 1.0; 
		return;
	}
	if (color.b > 0.5 && color.r < 0.2 && color.g < 0.2) {
		write[idx] = 0.0;
		return;
	}

	float total_voltage = 0.0;
	float total_weight = 0.0;

	for (int dy = -1; dy <= 1; dy++) {
        int neighbor_y_offset = (int(y) + dy) * width; 
        
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            int n_idx = neighbor_y_offset + (int(x) + dx);
            vec4 n_color = unpackUnorm4x8(pixels[n_idx]);
            
            if ((n_color.r + n_color.g + n_color.b) > 0.1) {
                float weight = (abs(dx * dy) == 1) ? 0.707 : 1.0;
                
                total_voltage += read[n_idx] * weight;
                total_weight += weight;
            }
        }

	if (total_weight > 0.0) {
		write[idx] = total_voltage / total_weight;
	} else {
		write[idx] = read[idx] * 0.99;
	}
    }
}
