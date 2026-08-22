# Variables and Constants

Variable types, constants, and declarations

---

## Value Variables

* Scope: **local**
* Memory: **stack**
* Ownership: **none**
* Assign as rvalue: **copies**
* Mutable: **yes**
* Initialization: **optional**
* Types: **all**
* Declaration: `var name: T = V;`

---

## Pointer Variables

* Scope: **local**
* Memory: **heap**
* Ownership: **owned or borrowed**
* Assign as rvalue: **moves**
* Mutable: **yes**
* Initialization: **required**
* Types: **all**
* Declaration: `var name: own<T> = new T{ V };`

---

## Static Variables

* Scope: **global**
* Memory: **static**
* Ownership: **borrowed**
* Assign as rvalue: **invalid**
* Mutable: **yes**
* Initialization: **optional**
* Types: **all**
* Declaration: `static name: T = V;`

---

## Constants

* Scope: **none**
* Memory: **inlined**
* Ownership: **none**
* Assign as rvalue: **copies**
* Mutable: **no**
* Initialization: **required**
* Types: **primitives**
* Declaration: `const NAME: T = V;`

---

## Type Annotations and Inference

* Type annotations are required when a variable is declared but not defined (inits as default value)
* Non-annotated types are inferred from their values
* There are default inferred primitive types designd on value literals:
  * Non-decimal numerals: `i32`
  * Decimal numerals: `f64`
  * Enclosed in `"`: `str`
  * Enclosed in `'`: `char`
  * Literal `true` or `false`: `bool`

---

⬅️ [Expressions](./3-expressions.md) | [Functions](./5-functions.md) ➡️
