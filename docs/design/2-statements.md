# Statements

Various statement types and operators. This page specifically only documents statements that don't produce a value, but may have side effects.

---

## Terminators

A semicolon terminates an **expression**, not a declaration. So a declaration whose
initializer is brace-bodied ends at its closing brace, matching `if`, `loop`, and bare
blocks:

```
var count: u32;                   // no initializer, needs a terminator
var total = a + b;                // expression initializer
var point = Point { x: 1, y: 2 }; // construction is an expression, not a block

const greet = () -> void {        // function body is a block
	print "hi";
}

struct Point {                    // struct body is a block
	var x: u32;
	var y: u32;
}
```

Construction braces are not blocks, so `Point { … }` still needs its semicolon. The
distinction is whether the closing brace ends a block of statements or an expression.

Statements always terminate with a semicolon, including `return`, so returning a
function literal reads `return (a: f64) -> f64 { ... };`.

---

## Assignments

The identity assignment is the base "LH assigned value of RH" statement. The following compound forms all resolve to "LH assigned value of LH _operator_ RH"

* `=`: identity assignment
* `+=`: addition assignment
* `-=`: subtraction assignment
* `*=`: multiplication assignment
* `/=`: division assignment
* `%=`: modulo assignment
* `**=`: exponent assignment
* `|=`: bitwise OR assignment
* `&=`: bitwise AND assignment
* `^=`: bitwise XOR assignment
* `<<=`: left bit shift assignment
* `>>=`: right bit shift assignment

* _note_: Assignment targets are restricted to variables and struct fields, and chained assignment is not supported.

---

## Other

* `print`: write the input to stdout (likely temporary until stdlib IO is implemented)
* `drop`: frees an owned pointer's data from memory

---

⬅️ [Data Types](./1-data-types.md) | [Expressions](./3-expressions.md) ➡️
