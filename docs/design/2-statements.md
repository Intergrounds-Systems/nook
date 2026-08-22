# Statements

Various statement types and operators. This page specifically only documents statements that don't produce a value, but may have side effects.

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
