# Nook

<img src="./assets/logo.svg"></img>

> *A safe and comfortable systems language*

**Status: C Transpiler in Development.**
- ✅ Tokenizer
- ✅ AST Parser
- ❌ Static Analysis
- ❌ Code Gen

**Documentation**
- 🧭 [Roadmap](./docs/roadmap.md)
- 📐 [Design docs](./docs/design/0-conventions.md)

---

## A taste

```
pkg main;

struct Point {
	var x: f64;
	var y: f64;

	// Statically dispatched, can read member fields
	const magnitude = () -> f64 {
		return (.x ** 2.0 + .y ** 2.0) ** 0.5;
	}
}

// Functions are values, so higher-order functions need no special syntax
const twice = (f: func<(f64) -> f64>, v: f64) -> f64 {
	return f(f(v));
}

var origin = Point {
	x: 0.0,
	y: 0.0,
};

// Explicit heap allocation yields an owned pointer
var far: own<Point> = new Point {
	x: 3.0,
	y: 4.0,
};

if (far.magnitude() > 1.0) {
	print "far from origin";
} else {
	print "close";
}

drop far;
```

A few things that shape the language:

- **Allocation is explicit.** Locals live on the stack, globals in static storage, and the
  heap is reached only through `new`, which yields an `own<T>`.
- **Functions are just values.** `const` gives static dispatch, `var` gives dynamic. There
  is no separate function-declaration syntax.
- **References are ephemeral.** A `ref<T>` is usable within an expression and can never
  escape its owner.

---

## Building

Requires Zig `0.15.2` or newer.

```sh
zig build              # builds zig-out/bin/nook
zig build --release=safe  # optimized, safety checks retained
zig build test         # run the unit tests
```

## Usage

```sh
nook init              # create a module in the current directory
nook build             # build the module in the current directory
nook version
nook help
```

---

## Layout

```
src/
  cli/      command-line interface and commands
  core/
    fe/     front end: tokenizer and parser
    types/  token, expression, statement, and value types
  log/      leveled logging
  module/   module file handling
  util/     shared helpers
docs/
  design/   language design documents, read in order
  roadmap.md
```

---

## License

[MIT](./LICENSE)
