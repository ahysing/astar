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

# https://chapel-lang.org/docs/usingchapel/debugging.html?highlight=gdb
debug: target/debug/AStar
	target/debug/AStar --gdb || target/debug/AStar --lldb

test:
	mason test --show --print-callstack-on-error

clean:
	rm target/release/AStar target/debug/AStar