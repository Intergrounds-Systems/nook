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
  - Optional returns with `?`
  - Error returns with `!`

**Globals**
- Static variables with `static`
  - Static lifetime and storage
- Constants with `const`
  - Literals and pointers that fit in CPU register are inlined
  - Everything else goes in static storage (read-only)
- Function pointers allowed with `dyn`

**Backend**
- C as portable assembly
- Single-exit functions + cleanup blocks

---

## Implementation Order

### 0. Base Syntax and Design
- [ ] Comments, casing and whitespace conventions
- [ ] Primitive data types
- [ ] Arithmetic, bitwise, comparison, and logical expressions
- [ ] Variable declaration and definition
- [ ] Function definition and calling
- [ ] Flow control
- [ ] Heap allocation
- [ ] Structs

### 1. Core Execution
- [ ] Lexer
- [ ] Parser → AST
- [ ] Basic C generation
- [ ] Functions, variables, expressions

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
