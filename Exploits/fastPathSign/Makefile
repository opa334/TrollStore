TARGET = fastPathSign

CC = clang

CFLAGS = -framework Foundation -framework CoreServices -framework Security -fobjc-arc $(shell pkg-config --cflags libcrypto) -Isrc/external/include
LDFLAGS = $(shell pkg-config --libs libcrypto) -Lsrc/external/lib -lchoma

$(TARGET): $(wildcard src/*.m src/*.c)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

clean:
	@rm -f $(TARGET)