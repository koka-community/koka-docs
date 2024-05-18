
Title         : The &koka; Language Doc Updates
Title Note    : [(Daan Leijen, Koka-Community &date;)]{font-size:75%}
Heading Base  : 1
Heading Depth : 3
Toc Depth     : 3
Css           : styles/koka.css
Css           : styles/book.css
Css           : https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.4.0/css/font-awesome.min.css
Css           : https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/brands.min.css
Script        : scripts/book.js
Colorizer     : unchecked
Colorizer     : koka
Bibliography  : koka.bib
Koka          : Koka

[INCLUDE=./styles/webanchors.mdk]
[INCLUDE=./styles/webtoc.mdk]
[INCLUDE=./book-style.md]
body {
  .colored  
}

[koka-logo]: logo/koka-logo-filled.png { max-height: 120px; padding:1rem 1rem 1rem 1.5rem; }
[kokabook]: https://koka-lang.github.io/koka/doc/book.html  {target='_top'}
[libraries]: https://koka-lang.github.io/koka/doc/toc.html {target='_top'}
[kokarepo]: https://github.com/koka-lang/koka {target='_top'}
[kokaproject]: http://research.microsoft.com/en-us/projects/koka {target='_top'}
[releases]: https://github.com/koka-lang/koka/releases
[build]: https://github.com/koka-lang/koka/#build-from-source
[forum]: https://github.com/koka-lang/koka/discussions


~ Begin MainHeader

[TITLE]

~ End MainHeader

~ Begin FlexBody

~ Begin SidePanel

[![koka-logo]](https://github.com/koka-lang/koka)

[TOC]

~ End SidePanel

~ Begin MainPanel

~ Begin MainContent

# Why these docs?

This website has some updates to Koka's documentation with more information about less well-known or documented Koka features

[INCLUDE=new-features.kk.md]

[INCLUDE=less-documented-features.kk.md]

[INCLUDE=less-known-features.kk.md]

[INCLUDE=best-practices.kk.md]

[INCLUDE=tips-for-debugging.kk.md]

[INCLUDE=known-rough-edges.kk.md]

[INCLUDE=other-doc-updates.kk.md]


[BIB]

~ End MainContent

~ End MainPanel

~ End FlexBody
