## Less Known Features

### Integrated External Definitions

Koka supports the integration of external definitions from other languages. This is useful when you want to use a library that is not available in Koka, or when you want to use a library that is not yet available in Koka. The external definitions are integrated into the Koka program and can be used as if they were written in Koka.

You use the `extern` keyword to declare an external definition.

The simplest way to integrate external definitions is to provide an inline implementation for each target language. For example, the following code provides an inline implementation for C and JavaScript: (targets include "c", "js", and "cs" (csharp))

```koka
extern sizeofint(): int32
  c inline "sizeof(int)"
  js inline "4"
```

To provide arguments simply use a `#` followed by the argument number. For example, the following code provides an inline implementation for C and JavaScript:

```koka
extern add(x: int32, y: int32): int32
  c inline "(#1 + #2)"
  js inline "#1 + #2"
```

To delegate to a function defined already in the target language you can omit the `inline` keyword and provide the function name:

```koka
extern add(x: int32, y: int32): int32
  c "add"
  js "add"
```

If you need access to Koka's context parameter in your external definition, prefix the function name with "kk_" as follows:
  
```koka
extern kk_add(x: int32, y: int32): int32
  c "kk_add"
  js "kk_add"
```

In your C code you would then need to provide a function matching the number of arguments and types but with an additional `kk_context_t` parameter:

```
int32_t kk_add(int32_t x, int32_t y, kk_context_t ctx) {
  return x + y;
}
```
Note that you should always use `int32` or `int64` in Koka for C interop, as Koka `int` is arbitrary precision and not compatible with C's `int`.

To include external files use `extern import` and provide the path to the file. For example, the following code includes the file `my_file.h` (relative to the current file) for the C/Wasm backends and `my_file.js` for the Javascript backend.

```koka
extern import
  c file "my_file.h"
  js file "my_file.js"
```

To include both a ".h" and ".c" file for the C backend, just omit the file extension:

```koka
extern import
  c file "my_file"
```

To control where it get's placed in the generated code, you can use the `header-file` or `header-end-file` special identifiers instead of `file`.


To use koka's closures in C, you can use the `kk_function_t` type:

```koka
extern kk_closure(f: () -> int32): int32
  c "kk_closure"
```

```
int32_t kk_closure(kk_function_t f, kk_context_t _ctx) {
  // The signature of the kk_function_call macro is
  // return type, (arg types), closure, (arguments), context
  // Ensure that the closure always has a reference to itself as first argument, and the context as last argument
  return kk_function_call(int32_t, (kk_function_t, kk_context_t), f, (f, _ctx), _ctx);
}
```
