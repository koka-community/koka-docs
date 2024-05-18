~ MathDefs
\newcommand{\pdv}[1]{\frac{\partial{}}{\partial{#1}}}
~
~ hidden
```
import std/num/float64
import std/num/random
```
~

## New Features

In order of newness, the following features have been added to &koka;:

### Qualified Names and Overloading { # sec-qualified; }

Qualified names and Implicits are two new features of Koka. 

Multiple dispatch style overloading (overloading that considers all the types of the arguments) has existed in Koka for a while, but was problematic for a few reasons:

- There was no way to disambiguate between functions with the same name if they were both brought into the same scope and operated on the same parameters, even if the return type was different.
- There was no good way to overload constants (i.e. zero for both types `int` and `float64`)

Recently we added a new feature called locally qualified names. 
Using qualifiers we can now precisely disambiguate when we have multiple functions with the same name.
For example we can define two mapping functions for lists, and specialize them to work on different types of lists:
```koka
fun int/map(xs: list<int>, f: int -> int): list<int> ...
fun float64/map(xs: list<float64>, f: float64 -> float64): list<float64> ...
```
and these can coexist peacefully with the normal definition for map
```koka
fun list/map(l: list<t>, f: t -> r): list<r> ...
```

Additionally all functions are also qualified by their module path so that you can distinguish between different
functions with the same name from different modules even if they are not locally qualified.

We split the standard library into smaller modules to avoid adding too many local qualifiers.
This seems to work well in practice, and we recommend putting functions that are defined with the same first parameter type in a module together.

### Implicits { # sec-implicits; }
Implicit arguments are Koka's answer to type classes or ad-hoc polymorphism. 
While several languages have implicit arguments, (e.g. Scala, Coq, Lean), most of them occur in proof systems, and are different than Koka's approach.

In particular, Koka's implicits are not resolved solely by finding an appropriate term of the matching type, but rather by finding a term matching the unqualified name of the parameter that unifies correctly. 
If multiple terms match, the type checker will report the ambiguity. 

A simple use case is for `show`ing a value that has generic type. For example, this is how `show` can be defined for a list.
```koka
fun list/show(l: list<a>, ?show: (a) -> string): string
  "[" ++ l.map(show).join(", ") ++ "]" 
```
Note the `?` prefixing the show parameter. This marks this parameter as being inferred using the name `show` at the application site.

Of course we can also define more specialized versions of `show` for specific lists, and they can be used when in scope.
```koka
// A special show for characters
// when resolving an implicit parameter `list/show` the
// `chars/show` will be preferred over `list/show` as the chain is shorter
fun chars/show( cs : list<char> ) : string
  "\"" ++ cs.map(string).join ++ "\""
```

Implicit arguments can also require other implicits, and the type checker will fill in the dependencies.
For example, to show a list `l2: list<list<int>>` koka will fill in the implicit `show` parameter for the inner list as well.
```koka
l2.show
// will be inferred as
l2.list/show(?show=fn(l) l.list/show(?show=int/show))
// with all of the implicit parameters eta expanded and filled in explicitly.
```
VSCode will show you the inferred implicits and qualified identifiers when you press `Ctrl+Alt`.

As a consequence of this design, implicits have no runtime machinery. We plan on measuring the impact on code size and deduplicating implicits in the future (but this is not implemented yet).

Implicits are purely a compile-time feature, and are resolved during type inference at the same time as overloading is resolved. 
However due to the stage at which they are resolved, the compiler cannot tell that you need an overloaded name to be inferred and type checked prior to a usage of that definition when trying to resolve an implicit.

Therefore, implicits enforce the following rule on usage
- Definitions used as implicit arguments should be defined prior to their usage in the file

When resolving any usage of an identifier Koka follows the following rules to resolve overloading
- If a qualified name is used, than it refers to a definition unambiguously and proceeds to resolve implicits
- If a local variable of the correct name and type is in scope, it is given preference over other definitions
- If the name is unique and no overloads exists, that singular definition is used and implicits are resolved
- If the name is ambiguous, try to infer the type of the minimum number of arguments that makes the overloaded identifier uniquely unifiable and then proceed to resolve implicits
- If the name is still ambiguous, report an ambiguity
When proceeding to resolve implicits
- The name of the parameter (without local qualifiers) is used to search for a definition avaiable at the call site 
- The overloading an implicit rules are used recursively to resolve the implicits
- Shorter chains of implicits are preferred over longer chains
- If the compiler cannot find a unique shortest implicit chain, it will report an ambiguity
- If the compiler cannot find a corresponding definition with the correct type it will report an error

As such, overuse of static overloading or deeply nesting implicits is bad practice for the following reasons: 
(1) It makes implicit resolution more expensive
(2) It can make code harder to read and understand
(3) It can result in ambiguities in the middle of an implicit chain which you have to expand manually

It is best practice to:
(1) Only overload unambiguously (i.e. with different types)
(2) Prefer overloading where the first argument type can distinguish the definitions completely
(3) Avoid deeply nesting generic types

If you absolutely need to create an ambiguous overloaded definition that is likely to be used in a nested implicit
there are ways to mitigate issue number (3), which has something to do with best practice (3).
Let's suppose you have an overloaded definition for `show` on lists, because you want to show lists with each element on their own line.
```koka
fun nl/show(l: list<a>, ?show: (a) -> string): string
  l.map(show).join("\n")
```
And then lets suppose that you have a nested list of lists and you want the outer list to be shown with each element on its own line, but the inner list to be shown with each element on the same line. This is easy
```koka
val l2: list<list<int>> = ...
l2.nl/show()
```
Qualifying the outer show is enough in this case.
However, let's say that you want to now overload show on integers, to pad them with a single zero if less than 10.
```koka
fun padded/show(i: int): string
  if i < 10 then "0" ++ i.show else i.show
```

Well now your deeply nested list is ambiguous, and you have to manually expand it.
```
val l2: list<list<int>> = ...
l2.nl/show(?show=list/show(?show=padded/show))
```
This is a bit of a pain. To mitigate this we can define a new value type that wraps our list of integers.
```koka
value struct paddedlist {inner : list<int>}
fun padded/show(pl: paddedlist): string
  pl.inner.show(?show=padded/show)
```
And now the `list<paddedlist>` using a shortest chain rule will definitely resolve to the correct definition.

I hope we add newtypes & proxying to Koka to make this even cleaner and not introducing a new type at runtime.

### Named and Scoped Handlers { #sec-namedh; }

Named handlers allow us to define multiple handlers for the same effect that are lexically distinct from one another. For example, to define a handler for managing a file, we can write:
```koka
named effect file
  fun read-line() : string   // `:(file)   -> <exn> a`
// a (named) handler instance for files
fun file(fname, action) 
  var content := read-text-file(fname.path).lines
  with f <- named handler 
    fun read-line() 
      match content  
        Nil -> "" 
        Cons(x,xx) -> { content := xx; x }
  action(f)
pub fun main() 
  with f1 <- file("package.yaml")
  with f2 <- file("stack.yaml")
  println( f1.read-line() ++ "\n" ++ f2.read-line() )
```
This allows us to have two separate handlers for the same effect, and to use them in the same scope. The `named` keyword is used to define a handler instance, and the `with` statement is used to bind a handler instance to a variable. The handler instance can then be used as a regular handler, and it can be passed to other functions. 

When used with handlers that involve multiple resumptions, you must be careful to ensure that the handler instance does not escape the scope of the resumption. For example, the following code is incorrect, and will fail at runtime:

```koka
fun wrong-escape1() 
  with f <- file("stack.yaml")
  f
pub fun test() 
  val f = wrong-escape1()
  f.read-line.println
```

To ensure that the handler instance does not escape, you can mark the effect as a scoped effect. 

```koka
named scoped effect file<s::S> 
  fun read-line() : string  // `: (f : file<s>) -> scope<s> string`
// a handler instance for files
fun file(fname : string, action : forall<s> file<s> -> <scope<s>|e> a ) : e a 
  var i := 0
  with f <- named handler 
    fun read-line()
      i := i + 1
      (fname ++ ": line " ++ i.show)
  action(f)
``` 

When creating the file the function `file` quantifies the `action` function by a polymorphic scope `s`, and connects that to the scope of the `file` instance passed to the `action`. Each action is guaranteed to not escape the scope of the action method due to the scope polymorphism. Scope types which are recognized by the `::S` kind annotation are not limited to just effect handlers, and can be used with other variables. See the [``samples/named-handlers``][named-handlers] directory on github or in your Koka installation for more complex examples of both named handlers and scoped effects and types.

[named-handlers]: https://github.com/koka-lang/koka/tree/master/samples/named-handlers {target='_top'}


## Less Documented

The following keywords or features are less well-known or documented in Koka:

### Type Qualifiers and Features

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

### Parameters
All parameters to top level functions must be named.
As such, arguments can be passed named or in order.

Additionally parameters can be marked as borrowed by prefixing the name with the caret `^`.

This can be useful to avoid unnecessary reference counting on parameters that you know will be live for the duration of the function call (such as higher order function parameters, including implicits).
However, it will mean that the parameter including any variables captured under a lambda will not be freed as early as it could.
For data structures that will be destructed using a match statement, it is almost always better to rely on the default owned semantics, which will let Koka reuse the memory in place.



### Return Statement


### Divergence Inference


### Function Modifiers

### Vectors

### Implicits Versus Effects

### Matching

### Linear Effects

## Best Practices
- utf8
- tests
- vectors
- implicits versus effects
- formatting

## Some Rough Edges

### Partial Type Checking

### Standard Library

#### Documentation

#### Testing Library

#### Red Black Tree

#### List / Ssslice

#### Tuple accessors on parameters

### Conditional Effects

