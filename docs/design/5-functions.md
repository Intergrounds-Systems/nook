# Functions

Function types, signatures, and calling

---

## Signatures

* Signatures are in the form `(args...) -> T`
* Functions take 0 or more arguments
* Functions return 0 or 1 value
* Functions that never return a value do not have a `-> T` annotation
* The final argument to a function can be variadic
* Return types can be one of three variants (more info below):
  * **Scalar**: return value only
  * **Optional**: return value or nothing
  * **Errorable**: return value or an error

---

## Static Functions

* Scope: **global**
* Binding: **early**
* Dispatch: **static**
* Rebind: **no**
* Declaration: `static name(args...) -> T {}`

---

## Dynamic Functions

* Scope: **global, local and instance**
* Binding: **late**
* Dispatch: **dynamic**
* Rebind: **yes**
* Declaration: `dyn name(args...) -> T {}`

---

## Methods

* Scope: **struct instance**
* Binding: **early**
* Dispatch: **static**
* Rebind: **no**
* Declaration: `mtd name(args...) -> T {}`

---

## Lambdas

* Scope: **local**
* Binding: **early**
* Dispatch: **static**
* Rebind: **no**
* Declaration: `lambda name(args...) -> T {}`

---

## Return Variants

**Scalar**

* Return annotation: `-> T`
* Return syntax: `return V;`
* Caller handling: **none**

**Optional**

* Return annotation: `-> T?`
* Return syntax: `return V;` (value), `return;` (nothing)
* Caller handling:
```
// resolved
eval res = foo() {
	// handle value returned
} else {
	// handle nothing returned
}

// raised when calling function has same return type
var res = foo()?;
```

**Errorable**

* Return annotation: `-> T!`
* Return syntax: `return V;` (value), `return error(message);` (error)
* Caller handling:
```
// resolved
eval res = foo() {
	// handle value returned
} else {
	// handle error returned
}

// raised when calling function has same return type
var res = foo()!;
```

---

⬅️ [Variables and Constants](./4-variables.md) | [Control Flow](./6-control-flow.md) ➡️
