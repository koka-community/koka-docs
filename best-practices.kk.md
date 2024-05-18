
## Best Practices
- utf8
- tests
- vectors
- implicits versus effects
- formatting

### Effects
Always use the most restricted operation type in handler definitions.
For example, you can use `fun` for an operator even if the effect definition allows `ctl` operations.

### Implicits Versus Effects

