# Data Types

The primitive data types and their properties

---

## Types

**Integral**
* `u8`    - 8 bit  unsigned integer
* `u16`   - 16 bit unsigned integer
* `u32`   - 32 bit unsigned integer
* `u64`   - 64 bit unsigned integer
* `uword` - unsigned native machine word

* `i8`    - 8 bit  signed integer
* `i16`   - 16 bit signed integer
* `i32`   - 32 bit signed integer
* `i64`   - 64 bit signed integer
* `iword` - signed native machine word

**Fractional**
* `f32` - 32 bit floating point
* `f64` - 64 bit floating point

**Text**
* `char` - Unicode scalar value
* `str`  - string of Unicode characters

**Other**
* `bool`   - boolean value
* `own<T>` - owned pointer
* `ref<T>` - borrowed pointer

---

## Default Values

There are no uninitialized values. Variables without definitions will have the following values by default:

* Integers: `0`
* Floats: `0.0`
* `char`: `'\u0'`
* `str`: `""`
* `bool`: `false`

---

## Truthiness

All types are truthy when their value is anything other than their default value, and falsy when equal to their default value.

---

⬅️ [Conventions](./0-conventions.md) | [Expressions](./2-expressions.md) ➡️
