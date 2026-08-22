# Heap Allocation

Creating and using pointer values

---

## Pointer Values

* Allocation syntax: `var foo[: own<T>] = new T{ V };`
* Dereference syntax (`$`): `var sum = $baz + 5;`
* Borrowing is ephemeral; borrows (references) only live for the duration of a single expression
* References provide direct access to the value inside the pointer
* Borrow syntax (`#`): `bar(#foo);`, `sum = #baz + 5;`
* Pointers as function parameters:
  * Taking ownership: `static bop(param: own<T>)`
  * Borrowing reference: `static doo(param: ref<T>)`

---

⬅️ [Control Flow](./6-control-flow.md) | [Structs](./8-structs.md) ➡️
