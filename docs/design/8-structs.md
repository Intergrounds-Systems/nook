# Structs

Defining and using structs

---

## Struct Definition

Struct members (fields and methods) are all declared inside the struct body. Methods are
ordinary function declarations, so the same `var` / `const` / `static` rules apply:

```
struct Name {

	// fields
	var v1: u32;
	var v2: str = "bar";

	// statically dispatched method
	const foo = () -> u32 {
		return .v1;
	}

	// dynamically dispatched method, can be reseated at runtime
	var bar = () -> void {

	}

	// only one copy is dispatched; non-static members are not in scope in the body
	static baz = () -> u32 {
		return 5;
	}
}
```

---

## Instantiation

Instantiation uses braces and supports partial initialization:
```
struct FooBar {
	var foo: str;
	var bar: str;
}

var foobar = FooBar {
	foo: "bar",
};
```

Instantiation also supports untagged positional initialization:
```
struct BazBop {
	var baz: u32;
	var bop: i16;
}

var bazbop = BazBop {
	8743,  // baz
	35,    // bop
};
```

---

## Accessing Instance Members

Instance members are accessed with the `.` operator (auto-dereferences struct pointers).

Access from outside the instance uses symbol prefix:
```
var person = Person {
	name: "Dave",
};

print(person.name);
```

Access from within the instance uses no prefix:
```
struct Person {
	var name: str;

	const greet = () -> void {
		print("Hello, I am " + .name);
	}
}
```

---

⬅️ [Heap Allocation](./7-heap-alloc.md)
