CC = gcc

CFLAGS = -Wall -Wextra
LDLIBS = 

TARGET = engine.exe
SRC = main.c
OBJ = main.o

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(OBJ) -o $(TARGET) -I include -L lib -lraylib -lgdi32 -lwinmm 

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	del /q $(OBJ) $(TARGET)

.PHONY: all clean
