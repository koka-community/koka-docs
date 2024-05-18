## Other Doc Updates
Here are some updates to pre-existing Koka documentation, including a few small updates to the fip section highlighting some of the new keywords.

## FBIP: Functional but In-Place { #sec-fbip; }

With [Perceus][#why-fbip] reuse analysis we can
write algorithms that dynamically adapt to use in-place mutation when
possible (and use copying when used persistently). Importantly,
you can rely on this optimization happening, &eg; see
the `match` patterns and pair them to same-sized constructors in each branch.

This style of programming leads to a new paradigm that we call FBIP:
"functional but in place". Just like tail-call optimization lets us
describe loops in terms of regular function calls, reuse analysis lets us
describe in-place mutating imperative algorithms in a purely functional
way (and get persistence as well).

Koka has a few keywords for guaranteeing that a function is optimized by the compiler.

The `fip` keyword is the most restrictive and guarantees that a function is fully optimized by the compiler to use in-place mutation when possible.
Higher order functions, or other variables used multiple times in a `fip` function must be marked as borrowed using the `^` prefix on their name (eg. `^f`). 
Borrowed parameters cannot be passed as owned parameters to functions or constructors, cannot be matched destructively, and cannot be returned. 

The `tail` keyword guarantees that a function is tail-recursive. These functions will not use stack space.

The `fbip` keyword guarantees that a function is optimized by the compiler to use in-place mutation when possible.
However, unlike `fip`, `fbip` allows for deallocation, and also allows for non tail calls, which means these functions can use non-constant stack space.

Both `fip` and `fbip` can allow for a constant amount of allocation using `fip(n)` or `fbip(n)` where `n` is the number of constructor allocations allowed.
This allows them to be used in insertion functions for datastructures, where at least one constructor for the inserted element is necessary.

Following are a few examples of the techniques of FBIP in action. 
For more information about the restrictions for `fip` and the new keywords, see
the recent papers: [@Lorenzen:fip;@Lorenzen:fip-t]

### Tree Rebalancing

As an example, consider insertion into a red-black tree [@guibas1978dichromatic]. 
A polymorphic version of this example is part of the [``samples``][samples] directory when you have
installed &koka; and can be loaded as ``:l`` [``samples/basic/rbtree``][rbtree].
We define red-black trees as:
```koka
type color
  Red
  Black

type tree
  Leaf
  Node(color: color, left: tree, key: int, value: bool, right: tree)
```
The red-black tree has the invariant that the number of black nodes from
the root to any of the leaves is the same, and that a red node is never a
parent of red node. Together this ensures that the trees are always
balanced. When inserting nodes, the invariants need to be maintained by
rebalancing the nodes when needed. Okasaki's algorithm [@Okasaki:rbtree]
implements this elegantly and functionally:
```koka
fbip(1) fun balance-left( l : tree, k : int, v : bool, r : tree ): tree
  match l
    Node(_, Node(Red, lx, kx, vx, rx), ky, vy, ry)
      -> Node(Red, Node(Black, lx, kx, vx, rx), ky, vy, Node(Black, ry, k, v, r))
    ...

fbip(1) fun ins( t : tree, k : int, v : bool ): tree  
  match t
    Leaf -> Node(Red, Leaf, k, v, Leaf)
    Node(Red, l, kx, vx, r)
      -> if k < kx then Node(Red, ins(l, k, v), kx, vx, r)
         ...
    Node(Black, l, kx, vx, r)
      -> if k < kx && is-red(l) then balance-left(ins(l,k,v), kx, vx, r)
         ...
```


The &koka; compiler will inline the `balance-left` function. At that point,
every matched `Node` constructor in the `ins` function has a corresponding `Node` allocation --
if we consider all branches we can see that we either match one `Node`
and allocate one, or we match three nodes deep and allocate three. Every
`Node` is actually reused in the fast path without doing any allocations!
When studying the generated code, we can see the Perceus assigns the
fields in the nodes in the fast path _in-place_ much like the
usual non-persistent rebalancing algorithm in C would do.

Essentially this means that for a unique tree, the purely functional
algorithm above adapts at runtime to an in-place mutating re-balancing
algorithm (without any further allocation). Moreover, if we use the tree
_persistently_ [@Okasaki:purefun], and the tree is shared or has
shared parts, the algorithm adapts to copying exactly the shared _spine_
of the tree (and no more), while still rebalancing in place for any
unshared parts.


### Morris Traversal

As another example of FBIP, consider mapping a function `f` over
all elements in a binary tree in-order as shown in the `tmap-inorder` example:

```
type tree
  Tip
  Bin( left: tree, value : int, right: tree )

fbip fun tmap-inorder( t : tree, f : int -> int ) : tree
  match t
    Bin(l,x,r) -> Bin( l.tmap-inorder(f), f(x), r.tmap-inorder(f) )
    Tip        -> Tip
```

This is already quite efficient as all the `Bin` and `Tip` nodes are
reused in-place when `t` is unique. However, the `tmap` function is not
tail-recursive and thus uses as much stack space as the depth of the
tree.

````cpp {.aside}
void inorder( tree* root, void (*f)(tree* t) ) {
  tree* cursor = root;
  while (cursor != NULL /* Tip */) {
    if (cursor->left == NULL) {
      // no left tree, go down the right
      f(cursor->value);
      cursor = cursor->right;
    } else {
      // has a left tree
      tree* pre = cursor->left;  // find the predecessor
      while(pre->right != NULL && pre->right != cursor) {
        pre = pre->right;
      }
      if (pre->right == NULL) {
        // first visit, remember to visit right tree
        pre->right = cursor;
        cursor = cursor->left;
      } else {
        // already set, restore
        f(cursor->value);
        pre->right = NULL;
        cursor = cursor->right;
      }
    }
  }
}
````

In 1968, Knuth posed the problem of visiting a tree in-order while using
no extra stack- or heap space [@Knuth:aocp1] (For readers not familiar
with the problem it might be fun to try this in your favorite imperative
language first and see that it is not easy to do). Since then, numerous
solutions have appeared in the literature. A particularly elegant
solution was proposed by @Morris:tree. This is an in-place mutating
algorithm that swaps pointers in the tree to "remember" which parts are
unvisited. It is beyond this tutorial to give a full explanation, but a C
implementation is shown here on the side. The traversal
essentially uses a _right-threaded_ tree to keep track of which nodes to
visit. The algorithm is subtle, though. Since it transforms the tree into
an intermediate graph, we need to state invariants over the so-called
_Morris loops_ [@Mateti:morris] to prove its correctness.

We can derive a functional and more intuitive solution using the FBIP
technique. We start by defining an explicit _visitor_ data structure
that keeps track of which parts of the tree we still need to visit. In
&koka; we define this data type as `:visitor`:
```
type visitor
  Done
  BinR( right:tree, value : int, visit : visitor )
  BinL( left:tree, value : int, visit : visitor )
```

(As an aside,
Conor McBride [@Mcbride:derivative] describes how we can
generically derive a _zipper_ [@Huet:zipper] visitor for any
recursive type $\mu x. F$ as a list of the derivative of that type,
namely $@list (\pdv{x} F\mid_{x =\mu x.F})$.
In our case, the algebraic representation of the inductive `:tree`
type is $\mu x. 1 + x\times int\times x  \,\cong\, \mu x. 1 + x^2\times int$.
Calculating the derivative $@list (\pdv{x} (1 + x^2\times int) \mid_{x = tree})$
and by further simplification,
we get $\mu x. 1 + (tree\times int\times x) + (tree\times int\times x)$,
which corresponds exactly to our `:visitor` data type.)

We also keep track of which `:direction` in the tree
we are going, either `Up` or `Down` the tree.

```
type direction
  Up
  Down
```

We start our traversal by going downward into the tree with an empty
visitor, expressed as `tmap(f, t, Done, Down)`:

```
fip fun tmap( f : int -> int, t : tree, visit : visitor, d : direction )
  match d
    Down -> match t     // going down a left spine
      Bin(l,x,r) -> tmap(f,l,BinR(r,x,visit),Down) // A
      Tip        -> tmap(f,Tip,visit,Up)           // B
    Up -> match visit   // go up through the visitor
      Done        -> t                             // C
      BinR(r,x,v) -> tmap(f,r,BinL(t,f(x),v),Down) // D
      BinL(l,x,v) -> tmap(f,Bin(l,x,t),v,Up)       // E
```

The key idea is that we
are either `Done` (`C`), or, on going downward in a left spine we
remember all the right trees we still need to visit in a `BinR` (`A`) or,
going upward again (`B`), we remember the left tree that we just
constructed as a `BinL` while visiting right trees (`D`). When we come
back up (`E`), we restore the original tree with the result values. Note
that we apply the function `f` to the saved value in branch `D` (as we
visit _in-order_), but the functional implementation makes it easy to
specify a _pre-order_ traversal by applying `f` in branch `A`, or a
_post-order_ traversal by applying `f` in branch `E`.

Looking at each branch we can see that each `Bin` matches up with a
`BinR`, each `BinR` with a `BinL`, and finally each `BinL` with a `Bin`.
Since they all have the same size, if the tree is unique, each branch
updates the tree nodes _in-place_ at runtime without any allocation,
where the `:visitor` structure is effectively overlaid over the tree
nodes while traversing the tree. Since all `tmap` calls are tail calls,
this also compiles to a tight loop and thus needs no extra stack- or heap
space.

Finally, just like with re-balancing tree insertion, the algorithm as
specified is still purely functional: it uses in-place updating when a
unique tree is passed, but it also adapts gracefully to the persistent
case where the input tree is shared, or where parts of the input tree are
shared, making a single copy of those parts of the tree.
