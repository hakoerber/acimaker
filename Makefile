.PHONY: all clean fresh

clean:
	rm -rf ./build/root
	rm -rf ./out

all:
	bin/build.sh all

fresh: | clean all
