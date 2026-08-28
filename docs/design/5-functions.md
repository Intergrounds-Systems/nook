# Functions

Function types, signatures, and calling

---

## Declaration

Declaring functions is like declaring variables, but the function body must be defined at declaration time.
Functions can be defined as `var` or `const`, making them dynamically or statically dispatched, respectively.
Since the body must be defined, the type annotation for the function is inferred and therefore optional to write.
Functions inside structs can be `static` so that only one copy is dispatched; its host struct's non-static members are not in scope in the body. The type declaration for a function is `func<(arg types) -> return type>`, where arg types are a comma-separated list. Functions can take and return functions to create higher-order functions.

**Examples**
```
// This is a function that takes two numbers and returns their product
const product = (a: f64, b: f64) -> f64 {
	return a * b;
};

// This function takes nothing and returns no value, but can be reseated at runtime
var doThing = () -> void {
	
};

// This function composes two functions into one
const compose = (f1: func<(f64, f64) -> f64>, f2: func<(f64, f64) -> f64>) -> func<(f64, f64) -> f64> {
	const pi = 3.14159;
	
	// Return a closure
	return (a: f64, b: f64) -> f64 {
		a *= pi;
		b /= pi;

		// Calling functions and using their returns inline
		return f1(a, b) ** f2(a, b);
	};
};
```

* Functions take 0 or more arguments
* Functions return 0 or 1 value
* Functions that never return a value return `void`

**Closures**

Closures always capture their state by value, so primitive variables are copied, and owned pointers are moved into the closure body. References can't be captured. Returning a closure always creates a new heap allocation.

---

⬅️ [Variables and Constants](./4-variables.md) | [Control Flow](./6-control-flow.md) ➡️
