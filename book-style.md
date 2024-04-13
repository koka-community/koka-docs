adown: []{.fa .fa-angle-double-down}
aup:   []{.fa .fa-angle-double-up}
acopy: []{.fa .fa-copy}

logo-ubuntu: []{.fa-brands .fa-ubuntu}
logo-suse: []{.fa-brands .fa-suse}
logo-rhel: []{.fa-brands .fa-redhat}
logo-alpine: ![logo-alpine]
logo-arch: ![logo-arch]
logo-debian: ![logo-debian]
logo-freebsd: ![logo-freebsd]
logo-macos: []{.fa-brands .fa-apple}
logo-windows: []{.fa-brands .fa-windows}
logo-linux: []{.fa-brands .fa-linux}

.title {
  font-size: xxx-large;
}

toc {
  .expand-all;
}

toc.toc-contents {
  before:clear;
}

.math-inline {
  input: mathpre;
}

.pre-fenced3, .code1 {
  language: koka;
}

.pre-indented, .console {
  replace: "/^( *[\$>][^\n\r]*)/\(**``\1``**\)/mg";
}

.mapsto {
  padding: 0ex 1em;
  align-self: center;
  font-size: 125%;
}

.learn {
  .button;
}

.small-button {
  .button
}

.download-button {
  .small-button
  .localref
}

.copy {
  float: left;
  font-size: 75%;
  html-title:"Copy";
  .button;
}

@if preview {
  .code1 {
    border-bottom: 1px solid green;
  }

  .pre-fenced3 {
    border-left: 0.5ex solid green;
  }

  .token.predefined {
    color: navy;
  }
}

h4 {
  @h1-h2-h3-h4: upper-alpha;
}

.toc, h1, h2, h3, h4, h5 {
  font-family: 'Nunito', 'Segoe UI', sans-serif;
}

li {
  margin-bottom: 1ex;
}

.note {
  font-style: italic;
}

.advanced {
  before: "[advanced]{.boxed-label}";
  border-left: 1px solid #AAA;
  padding: 0em 0em 0em 1em;
  margin: 1em 0em;
}

.translate {
  replace: "translation&nl;{.boxed-label}&nl;~begin translate-row&nl;&source;&nl;~end translate-row&nl;";
  border: 1px solid #AAA;
  padding: 0em 1em;  
  margin: 1em 0em;
}


.boxed-label {
  tight: true;
  margin: 0em 0em 0em -1em;
  display: block;
  font-size: 70%;
  color: #999;
}

.banner {
  before: "[&caption;]{.banner-caption}";
}

flexrow {
  display: flex;
  flex-flow: row wrap;
  align-items: center;
  .tight;
}