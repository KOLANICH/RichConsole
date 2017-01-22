RichConsole.py [![Unlicensed work](https://raw.githubusercontent.com/unlicense/unlicense.org/master/static/favicon.png)](https://unlicense.org/)
===============
[![PyPi Status](https://img.shields.io/pypi/v/RichConsole.svg)](https://pypi.org/pypi/RichConsole)
[wheel (GHA via `nightly.link`)](https://nightly.link/KOLANICH-libs/RichConsole.py/workflows/CI/master/RichConsole-0.CI-py3-none-any.whl)
[![GitLab Build Status](https://gitlab.com/KOLANICH/RichConsole.py/badges/master/pipeline.svg)]( https://gitlab.com/KOLANICH/RichConsole.py/pipelines/master/latest)
[![Coveralls Coverage](https://img.shields.io/coveralls/KOLANICH-libs/RichConsole.py.svg)](https://coveralls.io/r/KOLANICH-libs/RichConsole.py)
![GitLab Coverage](https://gitlab.com/KOLANICH/RichConsole.py/badges/master/coverage.svg)
[![GitHub Actions](https://github.com/KOLANICH-libs/RichConsole.py/workflows/CI/badge.svg)](https://github.com/KOLANICH-libs/RichConsole.py/actions/)
[![Libraries.io Status](https://img.shields.io/librariesio/github/KOLANICH-libs/RichConsole.py.svg)](https://libraries.io/github/KOLANICH-libs/RichConsole.py)

>Yo dawg so we heard you like text styles so we put styles in your styles so you can style while you styling.

This is a tool to output "poor" (because it is limited by standardized control codes, which are very limited) rich text into a console. When dealing with control codes there is a problem with nesting styles because you have to restore the state, and the state you have to restore depends on the style of the level much distant from the one you are in. This library solves this problem.

You create a [directed acyclic graph](https://en.wikipedia.org/wiki/Directed_acyclic_graph) structure `RichStr` where each piece of string has its own [style`Sheet`](https://en.wikipedia.org/wiki/Style_sheet_(desktop_publishing)). After you have finished forming the output message you convert it into a string. The library does the rest.

How does it work?
-----------------

The algorithm is damn simple: it just traverses the directed acyclic graph in depth-first way, determines exact style of each string, computes differences between them and emits control codes to apply them.

Requirements
------------
* [`Python 3`](https://www.python.org/downloads/). [`Python 2` is dead, stop raping its corpse.](https://python3statement.org/). Use `2to3` with manual postprocessing to migrate incompatible code to `3`. It shouldn't take so much time. For unit-testing you need Python 3.6+ or PyPy3 because their `dict` is ordered and deterministic.
* A terminal supporting color codes.
  * Any Linux distro usually has one
  * Windows:
    * Windows 10 [has built-in support](https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences)
    * [ansicon](https://github.com/adoxa/ansicon) or [ConEmu](https://github.com/Maximus5/ConEmu) or [MinTTY](https://github.com/mintty/mintty) for older Windows
    * you can call [colorama.init()](https://github.com/tartley/colorama) to enable filtering the output with python, but this is VERY glitchy. It raises exceptions even on simple strings. The good thing in it that it supports more codes than `ansicon`.

Optional requirements
---------------------
This library automatically imports colors and other control codes from the following libraries:
* [`colorama`](https://github.com/tartley/colorama/)
  [![PyPi Status](https://img.shields.io/pypi/v/colorama.svg)](https://pypi.org/pypi/colorama)
  [![TravisCI Build Status](https://travis-ci.org/tartley/colorama.svg?branch=master)](https://travis-ci.org/tartley/colorama)
  ![License](https://img.shields.io/github/license/tartley/colorama.svg)

* [`plumbum.colorlib`](https://github.com/tomerfiliba/plumbum/)
  [![PyPi Status](https://img.shields.io/pypi/v/plumbum.svg)](https://pypi.org/pypi/plumbum)
  [![TravisCI Build Status](https://travis-ci.org/tomerfiliba/plumbum.svg?branch=master)](https://travis-ci.org/tomerfiliba/plumbum)
  ![License](https://img.shields.io/github/license/tomerfiliba/plumbum.svg)

* [`colored`](https://gitlab.com/dslackw/colored/)
  [![PyPi Status](https://img.shields.io/pypi/v/colored.svg)](https://pypi.org/pypi/colored)

Tutorial
--------
See [`Tutorial.ipynb`](./Tutorial.ipynb) ([NBViewer](https://nbviewer.jupyter.org/github/KOLANICH-libs/RichConsole.py/blob/master/Tutorial.ipynb)).
