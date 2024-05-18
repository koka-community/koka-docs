// BEGIN:sum-first-two
fun sum-first-two(xs: list<int>): list<int>
  match xs
    Cons(x, tail as Cons(y, _)) -> Cons(x + y, tail)
    xs' -> xs'
// END:sum-first-two

// BEGIN:gather-positives
fun gather-positives(xs: list<int>): list<int>
  match xs
    Nil -> Nil
    Cons(x, xs) | x > 0 -> Cons(x, gather-positives(xs))
    Cons(_, xs) -> gather-positives(xs)
// END:gather-positives