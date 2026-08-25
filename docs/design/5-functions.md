# Functions

Function types, signatures, and calling

---

## Signatures

* Signatures are in the form `(arg, arg, [args...]) -> T`
* Functions take 0 or more arguments
* Functions return 0 or 1 value
* Functions that never return a value return `void`
* The final argument to a function can be variadic; a literal `...` suffix marks an argument as variadic

Examples:


```
struct Person {
	var name: str;
	var age: u8;

	// A static function, doesn't rebind, known at compile time, can access member fields
	const greet: func(other: ref<Person>) -> void {
		print "Hello, " + other.name + ", my name is " + .name;
	}

	// A dynamic function, can rebind, known at runtime, can't access member fields
	var doThing: func() -> u8 {
		return 9;
	}

	// Note: undefined dynamic functions are not supported at this time
}

var alice = new Person {
	name: "Alice",
	age: 39,
};

var dave = new Person {
	name: "Dave",
	age: 47,
};

dave.greet(#alice);
```

---

⬅️ [Variables and Constants](./4-variables.md) | [Control Flow](./6-control-flow.md) ➡️
