# Eureka

Eureka is a blazingly fast, interpreted programming language with native FFI support, designed for extreme performance and low memory footprint.

## Features

- **Bytecode VM**: Stack-based virtual machine with sub-millisecond execution
- **Memory Efficient**: Peak usage of ~67KB for typical scripts
- **Clean Syntax**: Simple, readable code structure inspired by Rust and modern languages
- **Advanced Type System**: Static typing with type inference, mixed arrays, and casting
<!-- - **Module System**: Selective imports with dependency resolution -->

## Quick Start

### Installation

```bash
git clone https://github.com/fernandothedev/eureka.git
cd eureka
dub build --build=release
```

### Hello World

```rust
print("Hello, World!")
```

Run with:

```bash
./eureka hello.ek
```

## Language Features

### Variables and Types

```rust
// Basic types
let name str = "Fernando"
let age int = 17
let active bool = true

// Numeric precision
let pi_float float = 3.141592F
let pi_double double = 3.141592  // or 3.141592D
let pi_real real = 3.141592653589793238L

// Type casting (TODO)
let value str = "42"
let number int = cast!int(value)
let float_num float = cast!float(number)
```

### Arrays

```rust
// Type-safe arrays
let names str[] = ["Alice" "Bob" "Charlie"]
let numbers int[] = [1, 2, 3, 4, 5]

// Mixed-type arrays (explicit unsafe)
let unsafe mixed[] = ["string", 42, 3.14f]

// Array iteration
for name in names {
    print(name)
}
```

### Functions

```rust
func int fibonacci(n int) {
    if n <= 1 return n
    return fibonacci(n - 1) + fibonacci(n - 2)
}
```

### Control Flow

```rust
// If/else statements
if x == y {
    print("equal")
} else if x > y {
    print("greater")
} else
    print("less")

// For loops with ranges
for i in 0 ..= 10 {        // Inclusive range
    print(i)
}

for i in 0 .. 10 {         // Exclusive range
    print(i)
}

// Float ranges with step
for i in 0.0F ..= 1.0F : 0.1F {
    print(i)
}

// C-style loops
for let i int = 0; i < 10; i = i + 1 {
    print(i)
}

// String iteration (TODO)
for ch in "Hello" {
    println(ch)
}
```

### Module System (TODO)

```rust
// Selective imports
use "io.ek" : { println, input }

let name str = input("Name: ")
println("Hello, " + name)
```

## Standard Library

Built-in functions available through module imports:

**I/O Operations:**

- `print(...)` - Print without newline
<!-- - `println(...)` - Print with newline
- `printf(format str, ...)` - Formatted output (supports %s, %d, %f, %b)
- `input(prompt str)` - Read user input

**Type Conversions:**
- `toString(...)` - Convert any type to string
- `toInt(...)` - Convert to integer
- `toBool(...)` - Convert to boolean
- `cast!T(value)` - Explicit type casting

**String Utilities:**
- `strlen(text str)` - Get string length

**Type Introspection:**
- `typeof(value)` - Get runtime type information -->

## Command Line Usage

```bash
# Run a program
./eureka program.ek

# Debug and profiling
./eureka program.ek --ast          # Show Abstract Syntax Tree
./eureka program.ek --tokens       # Show lexer tokens
./eureka program.ek --context      # Show bytecode instructions
./eureka program.ek --stat         # Show VM execution time

# Interactive REPL (TODO)
./eureka --repl
```

## REPL Mode (TODO)

Interactive development with hot reload:

```bash
$ ./eureka --repl
Eureka - Welcome to ReplMode!

> println("Hello from REPL!")
Added line 1 to buffer.

> let x int = 42
Added line 2 to buffer.

> :run
Hello from REPL!
Execution completed.

Commands:
  :run           - Execute buffered code
  :sb            - Show buffer
  :cl            - Remove last line
  :cla           - Clear buffer
  :exit          - Exit REPL
```

## Real-World Examples

### Working with Arrays

```rust
let numbers int[] = [1, 2, 3, 4, 5]
let sum int = 0

for num in numbers {
    sum = sum + num
}

println("Sum: ", sum)
```

## Architecture

Eureka uses a multi-stage compilation pipeline:

1. **Lexer**: Source code → Tokens
2. **Parser**: Tokens → Abstract Syntax Tree (AST)
3. **Semantic Analyzer**: Type checking, symbol resolution
4. **Compiler**: AST → Bytecode
5. **VM**: Stack-based bytecode execution

Total pipeline time: **~300µs** for typical programs.

## Memory Efficiency

Measured with Valgrind on real workloads:

- **Peak heap usage**: 67KB for scripts with functions, loops, arrays
- **Binary size**: 2.6MB (includes full runtime and stdlib)
- **Zero memory leaks**: Confirmed with Valgrind memcheck

Perfect for:

- Serverless functions (minimal cold start)
- Embedded systems (low footprint)
- High-density deployments (more instances per server)

## Building from Source

### Requirements

- **D compiler**: LDC (recommended), DMD, or GDC
- **DUB**: D package manager

### Build Commands

```bash
# Debug build
dub build

# Release build (optimized)
dub build --build=release

# Release with LDC optimizations
dub build --build=release --compiler=ldc2

# Optional
# Strip symbols (reduce binary size)
strip eureka
```

## Roadmap

**Version 0.2.x (Current - VM)**

- ✅ Bytecode virtual machine
- ✅ Array operations and iteration
- ✅ Module system with selective imports
- ✅ Type casting and introspection
- 🔄 JIT compilation for hot loops
- 🔄 Bytecode optimizations (peephole, constant folding, ...)

**Version 0.3.x (Planned)**

- Package manager (`eur`)
- Standard library expansion
- LSP server for IDE support
- Structs and custom types
- Pattern matching

## Contributing

Contributions are welcome! Areas of interest:

- Standard library functions
- Optimization implementations
- Documentation and examples
- Language feature proposals

## License

[MIT](LICENSE)

## Acknowledgments

Inspired by: Lua (performance), Rust (syntax), Python (simplicity)

Built with: D programming language, LLVM toolchain

---

**Eureka** - Where performance meets simplicity.
