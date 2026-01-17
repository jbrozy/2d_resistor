#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define RCAMERA_IMPLEMENTATION
#include "raylib.h"
#include "rlgl.h"

void *rlGetProcAddress(const char *name);
typedef void (*PFNGLMEMORYBARRIERPROC)(unsigned int barriers);

PFNGLMEMORYBARRIERPROC glMemoryBarrierPtr = NULL;
typedef void (*PFNGLGETBUFFERSUBDATAPROC)(unsigned int target, long int offset, long int size, void *data);
PFNGLGETBUFFERSUBDATAPROC glGetBufferSubDataPtr = NULL;

#define GL_SHADER_STORAGE_BARRIER_BIT 0x00002000
#define GL_SHADER_STORAGE_BUFFER 0x90D2

#define SCALE 2.0

int main(int argc, char** argv) {
	SetTargetFPS(60);

	const char * image_path = argv[1];
	const char * mode_txt = argv[2];

	int mode = 0;
	if (strcmp("voltage", mode_txt)) {
		mode = 1;
	}
	if (strcmp("current", mode_txt)) {
		mode = 2;
	}

	fprintf(stdout, "Given Image Mode: %s\n", mode_txt);
	fprintf(stdout, "Current Image Mode: %d\n", mode);

	Image image = LoadImage(image_path);
	ImageFormat(&image, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
	ImageResize(&image, image.width * SCALE, image.height * SCALE);

	if (image.data == NULL) {
	    printf("!!! FEHLER: Bilddatei wurde nicht gefunden. Pfad prüfen !!!\n");
	} else {
	    printf("Bild geladen: %d x %d Pixel\n", image.width, image.height);
	}

	InitWindow(image.width, image.height, "2d resistance");

	glMemoryBarrierPtr = (PFNGLMEMORYBARRIERPROC)rlGetProcAddress("glMemoryBarrier");
	glGetBufferSubDataPtr = (PFNGLGETBUFFERSUBDATAPROC)rlGetProcAddress("glGetBufferSubData");

	int image_width = image.width;
	int image_height = image.height;

	Texture2D texture = LoadTextureFromImage(image);

	RenderTexture2D target = LoadRenderTexture(image_width, image_height);
	SetTextureFilter(target.texture, TEXTURE_FILTER_POINT);
	char * compute_shader_text = LoadFileText("assets/compute.glsl");

	unsigned int compute_shader_id = rlCompileShader(compute_shader_text, RL_COMPUTE_SHADER);
	unsigned int compute_shader_program = rlLoadComputeShaderProgram(compute_shader_id);

	Shader compute_shader = { 0 };
	compute_shader.id = compute_shader_program;

	int compute_shader_width = rlGetLocationUniform(compute_shader_program, "width");
	int compute_shader_height = rlGetLocationUniform(compute_shader_program, "height");

	Shader render = LoadShader(0, "assets/render.glsl");
	int render_shader_width = GetShaderLocation(render, "width");
	int render_shader_height = GetShaderLocation(render, "height");
	int render_mode = GetShaderLocation(render, "mode");

	Color* pixels = (Color*)image.data;
	size_t length = image_width * image_height;

	Color *pixels_cpu = (Color*)image.data;
	    for (int i = 0; i < image.width * image.height; i++) {
		if (pixels_cpu[i].a < 50) {
		    pixels_cpu[i] = (Color){0, 0, 0, 255}; 
		} else {
		    pixels_cpu[i].a = 255;
		}
	    }

	unsigned int ssbo_image = rlLoadShaderBuffer(length * 4, pixels_cpu, RL_DYNAMIC_COPY);

	float * voltages = (float*)calloc(length, sizeof(float));

	unsigned int ssbo_read = rlLoadShaderBuffer(length * sizeof(float), voltages, RL_DYNAMIC_COPY);
	unsigned int ssbo_write = rlLoadShaderBuffer(length * sizeof(float), voltages, RL_DYNAMIC_COPY);

	SetTargetFPS(60);
	float scaleY = (float)image_height / (float)GetScreenHeight();
	float scaleX = (float)image_width / (float)GetScreenWidth();

	float voltageAtCursor = 0.0f;
	bool isMouseInBounds = false;

	while(!WindowShouldClose()) {
		int mouseY = GetMouseY();
		int mouseX = GetMouseX();
		int simY = (int)(mouseY * scaleY);
		int simX = (int)(mouseX * scaleX);

		if (simX >= 0 && simX < image_width && simY >= 0 && simY < image_height) {
			isMouseInBounds = true;
			int idx = simY * image_width + simX;
			rlBindShaderBuffer(ssbo_read, 1);
			glGetBufferSubDataPtr(GL_SHADER_STORAGE_BUFFER, idx * sizeof(float), sizeof(float), &voltageAtCursor);
			rlBindShaderBuffer(0, 1);
		}

		rlEnableShader(compute_shader_program);
			SetShaderValue(compute_shader, compute_shader_width, &image_width, SHADER_UNIFORM_INT);
			SetShaderValue(compute_shader, compute_shader_height, &image_height, SHADER_UNIFORM_INT);

			for (int i = 0; i < 512; ++i) {
				rlBindShaderBuffer(ssbo_image, 0);
				rlBindShaderBuffer(ssbo_read, 1);
				rlBindShaderBuffer(ssbo_write, 2);
				rlComputeShaderDispatch((image_width + 15) / 16, (image_height + 15) / 16, 1);
				glMemoryBarrierPtr(GL_SHADER_STORAGE_BARRIER_BIT);

				unsigned int tmp = ssbo_read;
				ssbo_read = ssbo_write;
				ssbo_write = tmp;
			}
		rlDisableShader();

		SetShaderValue(render, render_shader_width, &image_width, SHADER_UNIFORM_INT);
		SetShaderValue(render, render_shader_height, &image_height, SHADER_UNIFORM_INT);
		SetShaderValue(render, render_mode, &mode, SHADER_UNIFORM_INT);

		BeginDrawing();
			ClearBackground(BLACK);
			BeginShaderMode(render);
				rlBindShaderBuffer(ssbo_image, 0);
				rlBindShaderBuffer(ssbo_read, 1);
				DrawTextureRec(
				    texture,
				    (Rectangle){0, 0, image_width, image_height},
				    (Vector2){0, 0},
				    WHITE
				);
			EndShaderMode();
			if (isMouseInBounds) {
			    const char* text = TextFormat("%.3f", voltageAtCursor);
			    DrawText(text, mouseX + 15, mouseY - 10, 20, BLACK); // Schatten
			    DrawText(text, mouseX + 14, mouseY - 11, 20, LIME);  // Text
			    DrawText(TextFormat("Pos: %d, %d", simX, simY), 10, 40, 20, DARKGRAY);
			}
			DrawFPS(10, 10);
		EndDrawing();
	}

	UnloadImage(image);
	rlUnloadShaderBuffer(ssbo_image);
	rlUnloadShaderBuffer(ssbo_read);
	rlUnloadShaderBuffer(ssbo_write);
	UnloadShader(render);
	UnloadShader(compute_shader);
	CloseWindow();
}

