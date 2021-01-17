.PHONY: all test debug run clean

all:
	mason build -g
	mason build --release

target/release/AStar:
	mason build --release

Mason.lock:
	mason build --release

target/debug/AStar:
	mason build -g

run: target/release/AStar Mason.lock
	target/release/AStar

debug: target/debug/AStar
	lldb target/debug/AStar

test:
	mason test --show --print-callstack-on-error

clean:
	rm target/release/AStar target/debug/AStar