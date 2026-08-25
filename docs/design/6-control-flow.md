# Control Flow

Controlling code execution paths

---

## Conditional Blocks

Follow the form:
```
if (expr) {
	
} else if (expr) {
	
} else {
	
}
```

* _note_: `if` and `loop` can be combined in the same block

---

## Loop Blocks

Follow the form:
```
loop (expr) {
	
} else loop (expr) {

} else {

}
```

The `loop` branch executes while its `expr` resolves to truthy. If it resolves to falsy, the next else branch is considered (bare `else` is only truthy on first test). The `loop` statement is an `if` statement with repeating branches.

---

⬅️ [Functions](./5-functions.md) | [Heap Allocation](./7-heap-alloc.md) ➡️
