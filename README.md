# Eureka

Eureka is a fast, interpreted programming language with native FFI support and a clean syntax designed for simplicity and performance.

## Features

- **Fast execution**: Sub-millisecond startup and execution times
- **Native FFI**: Direct integration with C libraries without compilation
- **Clean syntax**: Simple, readable code structure
- **Type system**: Static typing with type inference
- **Standard library**: Built-in functions for I/O, type conversion, and more

## Quick Start

### Installation

```bash
git clone https://github.com/fernandothedev/eureka.git
cd eureka
dub build
```

### Hello World

```rust
extern func void eprintln(msg str, ...);
eprintln("Hello, World!")
```

Run with:

```bash
./eureka hello.ek -L stdlib/iolib.so
```

## Language Features

### Variables and Types

```rust
let name str = "Fernando"
let age int = 17
let active bool = true
let pi_1 float = 3.141592f
let pi_2 double = 3.141592 // or 3.141592d
let pi_3 real = 3.141592r
```

### Functions

```rust
func int sum(x int, y int) {
    return x + y
}

let result int = sum(10, 20)
```

### If/Else

```rust
extern func void print(...);
extern func void println(...);
extern func int toInt(...);
extern func str input(msg str);

let x int = toInt(input("x: "))
let y int = toInt(input("y: "))

if x == y
    println("equals")
else if x > y
    println("well well well")
else {
    print("holy")
    println("shit")
}

```

### FFI (Foreign Function Interface)

Eureka supports direct calls to C libraries:

```rust
extern func void eprintf(format str, ...);
extern func str input(prompt str);

let name str = input("Enter your name: ")
eprintf("Hello, %s!\n", name)
```

### String Operations

```rust
extern func void eprintf(format str, ...);

let first str = "Hello"
let second str = "World"
let message str = first + " " + second
eprintln(message)  // Output: Hello World
```

## Standard Library

The built-in standard library provides essential functions:

- `print()`, `println()`, `eprintf()` - Output functions
- `input()` - Interactive input
- `toString()`, `toInt()`, `toBool()` - Type conversions
- `strlen()` - String utilities

## Command Line Usage

```bash
# Run a program
./eureka program.ek -L library.so

# Debug options
./eureka program.ek --ast        # Show AST
./eureka program.ek --tokens     # Show tokens
./eureka program.ek --context    # Show runtime context
./eureka program.ek --stat       # Show performance stats

# REPL mode
./eureka --repl
```

## Examples

### Basic I/O

```rust
extern func str input(prompt str);
extern func int toInt(...);
extern func void eprintf(format str, ...);

let name str = input("Name: ")
let age int = toInt(input("Age: "))
eprintf("Hello %s, you are %d years old!\n", name, age)
```

## Performance

Eureka is designed for speed:

- Startup time: ~3ms including library loading
- FFI calls with minimal overhead
- Efficient memory management
- Function symbol caching

## FFI Safety

FFI calls are direct C function invocations. Users are responsible for:

- Ensuring correct function signatures
- Managing memory safety
- Handling potential segmentation faults

This design prioritizes performance and flexibility over safety guarantees.

## Building from Source

Requirements:

- D compiler (DMD, LDC (recommended), or GDC)
- DUB package manager

```bash
git clone https://github.com/fernandothedev/eureka
cd eureka
dub build --build=release
```

## License

[MIT](LICENSE)

---

*Eureka - Performance meets simplicity*
