#Anansi [![Build Status](https://travis-ci.org/tcsc/anansi.svg?branch=master)](https://travis-ci.org/tcsc/anansi)

A graph manipulation library for the D Programming Language. Heavily inspired, possibly to the point of plaigiarism, by the boost graph library. At present Anansi implements only the tiniest subset of the BGL, but it should be at least at a point where it can be easily added to.

This first pass will probably be a pretty simple translation of (bits of) the BGL into D. The second pass will hopefully transform it into something more like idiomaitic D.

#As-yet-unasked Questions:#

**Q**: Why another graph handling library?

**A**: Because the only available graph handling library in the Dub package registry was GPL licensed, and I thought it might be nice to have a graph library that people can use in commercial code. Don't get me wrong; [the dgraph library](http://code.dlang.org/packages/dgraph) is awesome, and got me out of a hole in a personal project. It is also a hell of a lot simpler to use than this. I just wanted the option.

**Q**: Why "Anansi"?

**A**: Anansi is a West African spider god. And graphs are sorta-kinda like webs. Anansi is also a trickster god, who does whatever he wants, *to* whoever he wants, just to have a good time. I thought this was an apt comment on the probable quality of the code, given how little I actually know about D and graph theory.

If you think "anansi" is a silly name then you're probably right, but always rememer that things could be worse. It's original name was "spiderpig".

**Q**: Why is your D basically C++ with subtly different syntax?

**A**: For no reason other than I know C++ better than D, and don't know the idiomatic D way to do a lot of things yet.

#Usage example:#

```D
import std.stdio;
import anansi;

// Define a graph type that uses contiguous storage for vertex and edge data.
alias Graph = AdjacencyList!(VecS, VecS, DirectedS, char, string);

void fn() {
  Graph g;
  auto a = g.addVertex('a');
  auto b = g.addVertex('b');
  g.addEdge(a, b, "a -> b");

  // now dow something interesting with your graph
  foreach(v; g.vertices) {
    writeln("Hi from vertex ", g[v]);
  }
}
```

Also, check out the projects under the "examples" directory.
