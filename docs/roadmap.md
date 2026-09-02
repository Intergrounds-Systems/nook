# Nook Experimental Phase Roadmap

## Settled Design Philosophy of Nook

**Goal:**
*A safe and comfortable systems language*
- Intuitive and simple ownership system for memory safety
- Minimalistic and familiar syntax for predictability

**Memory**
- Default allocation behavior
  - Local: stack
  - Global: static
- Explicit heap allocation with `new`
  - Creates an owned variable

**Ownership**
- Move vs copy default
  - Assignment of owned variables moves ownership and invalidates previous owner
- Explicit copy rules
  - Shallow copy value types with assignment
  - Deep copy pointers and structs with inner ownership with `clone`
  - Require type to implement a `Clonable` interface for `clone`

**RAII**
- When values are dropped
  - On exit scope of owner
- Destruction order
  - LIFO
- How destructors are defined
  - Automatically by RAII 
  - Structs can have custom destruction logic
  - Require type to implement a `Deferrable` interface for destructors

**References**
- Allowed or not
  - Allowed one at a time, not assignable, only usable in expressions
  - "Ephemeral borrowing"
- Mutable vs shared?
  - Mutable if var is not `const`
  - No sharing or aliasing
- Can they escape scope?
  - Never

**Functions**
- Pass by value vs reference
  - Both
- Move into functions?
  - Allowed
- Borrow returns allowed?
  - No

**Types**
- Static typing only
- Type inference level
  - Local inference
  - Type annotations optional when type is inferrable
  - Type annotations required when not initializing
- Generics now or later
  - Later
- Default values

**Errors**
- Panic with `panic()`
- Result types
  - Deferred — optional (`?`) and errorable (`!`) return variants were removed
    from the function design; revisit as a general optional-types system

**Globals**
- Static variables with `static`
  - Static lifetime and storage
- Constants with `const`
  - Literals and pointers that fit in CPU register are inlined
  - Everything else goes in static storage (read-only)
- Function pointers are ordinary values; `var` gives dynamic dispatch, `const` static

**Backend**
- C as portable assembly
- Single-exit functions + cleanup blocks

---

## Implementation Order

**Where things stand:** the language is designed through structs, and the front end
tokenizes and parses all of it to an AST. Nothing is checked or generated yet — the next
phase is section 2.

### 0. Base Syntax and Design
- [x] Comments, casing and whitespace conventions
- [x] Primitive data types
- [x] Statements, assignment, and terminators
- [x] Arithmetic, bitwise, comparison, and logical expressions
- [x] Variable, constant, and static declaration
- [x] Function definition and calling
- [x] Control flow
- [x] Heap allocation
- [x] Structs

Deferred, both blocked on section 9:
- `iter` loops over collections
- Variadic arguments

Dropped pending sum types: `switch` / `case`. A match construct earns its keep through
exhaustiveness checking, which needs a closed set of values to check against.

### 1. Core Execution
- [x] Lexer
- [x] Parser → AST
- [ ] Basic C generation
- [ ] Functions, variables, expressions end to end

---

### 2. Names & Types
- [ ] Symbol resolution (scopes)
- [ ] Type checking
- [ ] Structs
- [ ] Function signatures

---

### 3. Control Flow
- [ ] `if`
- [ ] loops
- [ ] `return`

---

### 4. Memory Placement
- [ ] Stack allocation
- [ ] Heap allocation (`malloc/free`)
- [ ] Static variables
- [ ] Constants
- [ ] Function pointers
- [ ] Default value initialization

---

### 5. Ownership
- [ ] Move semantics
- [ ] Use-after-move detection
- [ ] Shallow copy

---

### 6. Interfaces & Type Aliases
- [ ] Interface declaration and satisfaction
- [ ] Type aliases and resolution

---

### 7. RAII
- [ ] User destructors
- [ ] Scope-based drop tracking
- [ ] Reverse-order destruction
- [ ] Single-exit lowering with cleanup

---

### 8. References
- [ ] Reference creation
- [ ] Borrow validation
- [ ] No escape from owner

---

### 9. Generics & Collections
- [ ] Type notation
- [ ] Typed collections
- [ ] Generic functions

Unblocks the deferred syntax from section 0 — `iter` needs something to iterate over, and
variadics need somewhere to put the extra arguments.

---

### 10. Stabilize Core
Freeze:
- Allocation model
- Ownership rules
- RAII behavior
- Function semantics

---

### 11. Later
- Packages
- Modules
- Stdlib
- Optimizations / LLVM
