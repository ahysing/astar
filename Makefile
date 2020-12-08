.PHONY: test debug run

all:
	mason build

run:
	mason run --build

debug:
	mason build -g
	lldb ./target/debug/AStar

test:
	mason test
