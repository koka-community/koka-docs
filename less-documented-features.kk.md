
## Less Documented Features

The following keywords or features are less well-known or documented in Koka:

### Type Definitions

#### Abstract Types
`abstract` in front of a type declaration will make the type non-constructible outside the current module. 
In addition it will not auto create the copy function or value accessors. 
This is used in the standard libraries for external types defined by the runtime, as well as types such as `sslice` which has specific guarantees about relations between its fields that it needs to take serious responsibility for to avoid undefined behavior such as segfaults.

#### Coinductive Types
Coinductively defined types have no special aspect to them at this point as far as I know other than to be reserved for functional completeness.

#### Extensible Types
Exensible types allow you to add constructors to a type from outside the type's definition.
It is used for example in the standard library's `exception-info` type, which allows you to add additional information to an exception.

The syntax is as follows:
```koka
open type mytype
  Constr1(a: int)
  Constr2(b: string)

extend type mytype
  Constr3(c: float64)
```

Note that for extensible types, the extended type must have public visibility `pub` or you will run into a known bug. Also note that pattern matching
will no longer be exhaustive so you must have `exn` in the effect row when pattern matching on an extensible type if there is no sensible default or catch all case.

There is still work to do to make extensible types work well with the rest of the language, in particular with implicits and overloading.

### Generated Functions
Types have a number of generated functions for convenience. 
These include:
- `copy` for copying a value while replacing some values (typically specified via named parameters)
- `is-<constructor>` for checking if a value is of a certain constructor (e.g. `is-nil` or `is-cons` for lists). Note that the name of the constructor has it's first character lowercased.
- `<field>` for accessing a field of the value (all constructors in an enumerated type must have the field with identical type to generate this function).

It should be noted that reference counting works better with pattern matching at the moment. However, we will make these generated functions more efficient in the future.

The copy function is typically invoked by directly postfixing the value with `()` and specifying the named parameters. (It looks like you are calling the value as a function). 

#### Type Aliases
Type aliases are a way to give a new name to an existing type.
This can be useful for documentation purposes or to make the code more readable.
For example, you could define a type alias for a function type that takes an integer and returns a string as follows:
```koka
alias i-to-s = int -> string
alias i-to-s-e<e> = int -> e string
```
Type parameters are allowed in type aliases. 
Type aliases are transparent, meaning that they are sometimes expanded when type checking, and do not hide any methods on the original type. 

While this might not seem useful, they are particularly useful for giving aliases to groups of effects that you often use, or to give names to function types.

For example, in the standard library we have the following type aliases:
```
alias pure = <div,exn>
alias st<h> = <alloc<h>,read<h>,write<h>>
```

#### Vectors
Vectors in koka are implemented as a fixed sized array. 
They allow mutable updates when used as a local variable, which typically results in functional behavior.

Additionally in the extended standard library available [here](https://github.com/koka-community/std), we have a new module `std/data/vector-list` which exposes a type `vector-list<t>` with a short alias `vlist<t>` which provides a functional interface to vectors. 
This means that it uses expensive copies when the vector is updated, unless there is a single reference to the vector. 
Unfortunately locally mutable variables at the moment keep around too many references, to work around this for now you can rebind the update to another local binding, or bind it recursively.

#### Matching
All defined types (except abstract ones outside their definiting module), can participate in pattern matching.

The syntax is very familiar to most functional programmers, including an expression descriminant, and a series of cases separated by newlines.
```koka
fun sum(xs: list<int>): int
  match xs
    Nil -> 0
    Cons(x, xs) -> x + sum(xs)
```
Each case is indented and separated from it's body by an arrow `->`. 
The bodies can follow on the next line (indented), or be on the same line as the arrow.
Additionally additional guards can be added to each case by adding a `|` and a boolean expression before the arrow.

For example to gather the integers greater than 0 from a list we can do:
```koka
[INCLUDE=examples.kk:gather-positives]
```

Using guards reduces nesting a bit compared to using if statements. 
However, the guard expression must not use any effects including divergence. Otherwise it could manipulate state, or prevent any matches! 
If you really need to use effects, you can always use an if statement inside the case, or bind a value prior to the match.
Each case is checked in order, and if the cases are not exhaustive, the compiler will infer an exception effect, which will throw a message at runtime stating where the pattern match failed.

Additionally Koka has support for naming subpatterns which can then be used in the body of the case.
For example to return a list where the first element of the new list is the sum of the first two elements of the old list, but with the rest of the list unchanged, we can do the following:
```koka
[INCLUDE=examples.kk:sum-first-two]
```

To match on two values at once, join them together in a tuple and match on the tuple.

### Parameters
All parameters to top level functions must be named.
As such, arguments can be passed named or in order.

Additionally parameters can be marked as borrowed by prefixing the name with the caret `^`.

This can be useful to avoid unnecessary reference counting on parameters that you know will be live for the duration of the function call (such as higher order function parameters, including implicits).
However, it will mean that the parameter including any variables captured under a lambda will not be freed as early as it could.
For data structures that will be destructed using a match statement, it is almost always better to rely on the default owned semantics, which will let Koka reuse the memory in place.

### Return Statement
The return statement allows you to return early from a block of code. 
However, the rest of the function after the early return must also type check to the same type as the expression given to return.

### Function Modifiers
The various function modifiers to guarantee certain properties related to reference counting are more details now here &sec-fbip;.

### Divergence Inference
Koka infers the divergence effects in four particular situations:

1. When a function is self-recursive
2. When functions call each other in a mutually recursive way.
3. When a heap allocated reference is read, but it's value also could reference the same heap, (which could diverge due to self referential functions).
4. Where handlers could cause divergence through their operations involving functions that reference the effect itself.

Of these only the first (self-recursion) can be eliminated by the compiler automatically by
using an inductive argument, and realizing that the discriminant will always get smaller.

To augment this you can add an import for the `std/core/undiv` module and
use the `pretend-decreasing` on arguments that you know to be decreasing (such as parallel reduction on multiple parameters). 
This will allow the compiler to finish the argument for removing `div`.

However, this technique will not work for mutual recursion or any other form of divergence.

One solution for these cases is to internally name the mutually recursive functions name and then expose a function that wraps the internal function and with a call to `pretend-no-div` from the `std/core/undiv` module (e.g. `pretend-no-div(fn() internal())`). This will remove the `div` effect without removing any other effects.

### Final Effects
You can use final ctl to denote that the effect operation never resumes. 

```koka
pub effect fail<b>
  final ctl fail(info: b) : a
```

### Linear Effects
Linear effects are effects whose handlers are always guaranteed to be used in a linear fashion.
This severely restricts what kinds of handlers can be implemented for those effects (including disallowing calls to any potentially other non-linear effect within the handler operations - for example `exn`).

You can create a linear effect by prefixing the effect definition with linear
```koka
linear effect pretty
  val indentation: int
  fun print(s: string): ()
```

In practice it does reduce the generated code size quite a bit, but doesn't have a large impact on performance, since Koka already provides information about the linearity of handlers in the runtime system. So it is more of a semantic guarantee and restriction, and should not be used for performance reasons.

For more fine grained restrictions on handlers and operations make your handler use `fun` or `val` operations. (You can even allow general `ctl` operations in the effect definition, but then give it a more restricted definition in the handler).


