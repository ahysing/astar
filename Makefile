.PHONY: all test debug run clean

all:
	mason build --release
	mason build -g

target/release/AStar:
	mason build --release

target/debug/AStar:
	mason build -g

run: target/release/AStar
	mason run

debug: target/debug/AStar
	lldb target/debug/AStar

test:
	mason test --show

clean:
	rm target/release/AStar target/debug/AStar