# Expressions

Various expression types and operators

---

## Arithmetic

* `+`:  add
* `-`:  subtract (binary), negate (unary)
* `*`:  multiply
* `/`:  divide
* `%`:  modulo
* `**`: exponent

---

## Logic

* `!`:  not (overloads as errorable func return in postfix position)
* `&&`: and
* `||`: or
* `^^`: xor

---

## Comparison

* `==`: equal
* `!=`: not equal
* `>`:  greater
* `<`:  less
* `>=`: greater or equal
* `<=`: less or equal

---

## Bitwise

* `~`: not
* `&`: and
* `|`: or
* `^`: xor
* `>>`: right shift
* `<<`: left shift

---

## Other

* `()`: function call
* `$`: dereference pointer
* `#`: borrow pointer
* `.`: member access
* `new`: allocate data on the heap (yields `own<T>`)
* `copy`: shallow copy a struct (inner pointers as `ref<T>`)
* `clone`: deep copy a struct (inner pointers as new `own<T>`)

---

## Precedence

Loosest to tightest. All binary operators are left associative except `**`.

| Level | Name | Members |
| --- | --- | --- |
| lowest | logical or | `\|\|` |
|  | logical xor | `^^` |
|  | logical and | `&&` |
|  | equality | `!= ==` |
|  | comparison | `> >= < <=` |
|  | bitwise or | `\|` |
|  | bitwise xor | `^` |
|  | bitwise and | `&` |
|  | shift | `<< >>` |
|  | term | `+ -` |
|  | factor | `* / %` |
|  | unary | `! ~ - new copy clone` |
|  | exponent | `**` (right associative) |
|  | pointer | `$ #` |
|  | postfix | `() . ? !` |
| highest | primary | literals, identifiers, constructions, groupings |

---

## Builtin Statements

These builtins are statement prefixes; they do not produce an output, but they have side effects based on their input.

* `print`: write the input to stdout (likely temporary until stdlib IO is implemented)
* `drop`: frees an owned pointer's data from memory

⬅️ [Data Types](./1-data-types.md) | [Variables and Constants](./3-variables.md) ➡️
