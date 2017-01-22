#!/usr/bin/env python3
__all__ = ("ControlCodes", "Style", "Color", "BasicColor", "IndexedColor", "RGBColor", "StyleGroup", "groups", "Sheet", "RichStr", "rsjoin", "neutral", "neutralGroup", "neutralSheet")
__author__ = "KOLANICH"
__license__ = "Unlicense"
__copyright__ = r"""
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or distribute this software, either in source code form or as a compiled binary, for any purpose, commercial or non-commercial, and by any means.

In jurisdictions that recognize copyright laws, the author or authors of this software dedicate any and all copyright interest in the software to the public domain. We make this dedication for the benefit of the public at large and to the detriment of our heirs and successors. We intend this dedication to be an overt act of relinquishment in perpetuity of all present and future rights to this software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org/>
"""

# pylint: disable=stop-iteration-return,too-many-ancestors,too-many-arguments,pointless-string-statement,multiple-imports

import re, itertools
from collections.abc import MutableMapping
from codecs import encode
import typing

try:
	ContainerTuple = typing._alias(tuple, typing.T, inst=False)  # pylint: disable=protected-access
except BaseException:  # pylint: disable=broad-except

	class ContainerTuple(tuple, typing.Sequence[typing.T], extra=tuple):
		pass


class ControlCodes:
	"""Represents a sequence of control codes"""

	def __init__(self, codes: ContainerTuple[int]) -> ContainerTuple[int]:
		if not isinstance(codes, tuple):
			codes = (codes,)
		self.codes = codes

	def __str__(self) -> str:
		if self.codes:
			return "".join(("\x1b[", ";".join(map(str, self.codes)), "m"))
		return ""

	def __repr__(self):
		return "".join((self.__class__.__name__, "(", repr(self.codes), ")"))

	def __eq__(self, other: "ControlCodes") -> bool:
		return self.codes == other.codes

	def __hash__(self):
		return hash(self.codes)

	def __add__(self, other: "ControlCodes"):
		# if type(self) is type(other):
			# self.codes+=other.codes
			# return type(self)(self.codes+other.codes)
		# else:
		return __class__(self.codes + other.codes)


class Style(ControlCodes):
	"""Represents a style of a string. Its groups contain groups of active styles"""

	def __init__(self, name: typing.Optional[str], codes: ContainerTuple[int], group: typing.Optional["StyleGroup"] = None) -> None:
		super().__init__(codes)
		self.name = name
		self.group = group

	def toCSSProperty(self):  # pylint: disable=no-self-use
		return {}

	def __repr__(self):
		return "".join([str(self), ((self.group.name + ":") if (self.group and self.group.name) else ""), (self.name if self.name else repr(self.name)), (str(self.group.reset) if self.group and self.group.reset else "\x1b[0m")])

	def __add__(self, other: "Style") -> typing.Union["Style", ControlCodes]:
		if self.group is other.group:
			return __class__(self.name + "&" + other.name, self.codes + other.codes, group=self.group)
		
		superclass = __class__.mro()[1]
		return superclass(self.codes + other.codes)

	def __call__(self, *strs: typing.Iterable[typing.Union["RichStr", str]]) -> "RichStr":
		return RichStr(*strs, sheet=self)


class Storage(MutableMapping):
	"""Represents a storage allowing access by both . and [] notation"""

	def __init__(self, new: typing.Optional[typing.Mapping[str, typing.Any]] = None) -> None:
		if new is None:
			new = {}
		if isinstance(new, MutableMapping):
			self.__dict__ = type(self.__dict__)(new)

	def __iter__(self):
		return iter(self.__dict__)

	def __getitem__(self, key: str) -> typing.Any:
		return self.__dict__[key]

	def __setitem__(self, key: str, val: typing.Any) -> None:
		self.__dict__[key] = val

	def __delitem__(self, key: str):
		del self.__dict__[key]

	def __contains__(self, item: str) -> bool:
		return item in self.__dict__

	def __len__(self) -> int:
		return len(self.__dict__)

	def values(self):
		return self.__dict__.values()

	def keys(self):
		return self.__dict__.keys()

	def __repr__(self):
		return self.__class__.__name__ + "(" + repr(self.__dict__) + ")"


class StyleGroup(Storage):
	"""Represent a group of mutually exclusive styles. ```reset``` is dedicated style returning style to default"""

	def __init__(self, name: str, styles: typing.Iterable[Style], reset: typing.Optional[Style] = None) -> None:
		if reset is not None and not isinstance(reset, Style):
			raise TypeError("Must be either ", type(None), " or compatible with ", Style, " but ", type(reset), " was given")
		super().__init__()
		for style in styles:
			self.addStyle(style)
		self.reset = reset
		self.name = name

	def addStyle(self, style: Style) -> None:
		self[style.name] = style
		style.group = self

	def __str__(self):
		return str(self.values())

	def __repr__(self):
		return "".join((
			self.__class__.__name__, "(",
			", ".join((repr(self.name), repr(tuple((v for v in self.values() if isinstance(v, Style)))), "reset=" + repr(self.reset))),
			")"
		))


def initGroups() -> Storage:
	reset = Style("reset", (0,))  # pylint: disable=unused-variable
	blinkReset = Style("reset", (25,))
	foreReset = Style("reset", (39,))
	backReset = Style("reset", (49,))
	brightReset = Style("reset", (21,))
	decorReset = Style("reset", (23,))
	underlineReset = Style("reset", (24,))
	concealReset = Style("reset", (28,))
	crossedOutReset = Style("reset", (29,))
	frameReset = Style("reset", (54,))
	overlineReset = Style("reset", (55,))
	ideogramReset = Style("reset", (65,))
	fontReset = Style("reset", (10,))

	fontsCodes = [Style("f" + str(i), (11 + i,)) for i in range(9)]
	fontsCodes.append(fontReset)

	"""This is our global storage of styles"""
	return Storage({
		"Back": StyleGroup("Back", [backReset], backReset),
		"Fore": StyleGroup("Fore", [foreReset], foreReset),
		"Brightness": StyleGroup("Brightness", [Style("bright", (1,)), Style("dim", (2,)), brightReset], brightReset),
		"Decor": StyleGroup("Decor", [Style("italic", (3,)), Style("fraktur", (20,)), decorReset], decorReset),
		"Underline": StyleGroup("Underline", [Style("underline", (4,)), underlineReset], underlineReset),
		"CrossedOut": StyleGroup("CrossedOut", [Style("crossedOut", (9,)), crossedOutReset], crossedOutReset),
		"Conceal": StyleGroup("Conceal", [Style("conceal", (8,)), concealReset], concealReset),
		"Blink": StyleGroup("Blink", [Style("slow", (5,)), Style("rapid", (6,)), blinkReset], blinkReset),
		"Frame": StyleGroup("Frame", [Style("framed", (51,)), Style("encircled", (52,)), frameReset], frameReset),
		"Overline": StyleGroup("Overline", [Style("overlined", (53,)), overlineReset], overlineReset),
		"Ideogram": StyleGroup("Ideogram", [Style("singleUnderOrRight", (60,)), Style("doubleUpperOrRight", (61,)), Style("singleOverOrLeft", (62,)), Style("doubleOverOrLeft", (63,)), Style("stress", (64,)), ideogramReset], ideogramReset),
		"Font": StyleGroup("Font", fontsCodes, fontReset),
	})


#groups:typing.Optional[Storage]=None
groups = initGroups()


def tupleReplace(tup: ContainerTuple[int], pos: int, new: int) -> ContainerTuple[int]:  # in fact tuple of ints of any length, but python.typing doesn't have means out of the box to express this
	prev = max((pos - 1, 0))
	return tup[0:prev] + (new,) + tup[(pos + 1):]


class Color(Style):
	controlCodesColorRangeOffset = 30  # color-related control codes occupy the range between [30; 50)
	backgroundOffset = 10  # you need to add 10 to make foreground color background
	enchancedColorBasicIndex = 8  # this is the basic index of color reserved for extended colors
	offset_intensiveOffset_GCD = 30  # this is gcd(controlCodesColorRangeOffset, intensiveOffset). Since it is not 1 and > than maximum basic index we can use it to get the basic index

	@staticmethod
	def splitBasicIndex(code: int) -> int:
		return code % __class__.offset_intensiveOffset_GCD

	def __init__(self, name: typing.Optional[str], codes: typing.Tuple[int]) -> None:
		super().__init__(name, codes)

	@property
	def code(self):
		"""A main (with index zero) control code of the color
		code = controlCodesColorRangeOffset + basicIndex + (bg?10:0) + (intensive?60:0)
		"""
		return self.codes[0]

	@code.setter
	def code(self, code: int):
		self.codes = tupleReplace(self.codes, 0, code)

	@property
	def basicIndex(self):
		"""An basicIndex of the color - its control code - controlCodesColorRangeOffset"""
		return __class__.splitBasicIndex(self.code)

	@basicIndex.setter
	def basicIndex(self, basicIndex: int):
		self.code += (-self.basicIndex + basicIndex)

	def setNumeric(self, name: str, val: bool, magic: int) -> None:
		"""Changes property name by magic in the right direction to make it have the value val"""
		prev = getattr(self, name)
		self.code += (int(bool(val)) - int(prev)) * magic

	@property
	def bg(self):
		"""Is the color applied to background?"""
		return self.basicIndex >= self.backgroundOffset

	@bg.setter
	def bg(self, bg: bool):
		self.setNumeric("bg", bg, self.backgroundOffset)

	@property
	def group(self):
		return groups.Back if self.bg else groups.Fore  # pylint: disable=no-member

	@group.setter
	def group(self, group: bool):
		if group is None:
			return
		if group is groups.Back:  # pylint: disable=no-member
			self.bg = True
			return
		if group is groups.Fore:  # pylint: disable=no-member
			self.bg = False
			return
		raise AssertionError("".join(["Group must be euther ", groups.Fore.name, " or ", groups.Back.name, ", ", group.name, " given"]))  # pylint: disable=no-member

	def toCSSProperty(self):
		return {(("background-" if self.bg else "") + "color"): self.toCSSColor()}
	
	def toCSSColor(self):
		raise NotImplementedError()
	
	def toRGBColor(self):
		raise NotImplementedError()

class _BasicColor(Color):
	"""
	code = controlCodesColorRangeOffset + basicIndex + (bg?10:0) + (intensive?60:0)
	"""

	intensiveOffset = 60

	def __init__(self, code: int, name: typing.Optional[str] = None) -> None:
		super().__init__(name, (code,))

	@property
	def intensive(self):
		"""Is the color intensive?"""
		return self.code >= (self.intensiveOffset + self.controlCodesColorRangeOffset)

	@intensive.setter
	def intensive(self, val: bool):
		self.setNumeric("intensive", val, self.intensiveOffset)

	def toRGB(self):
		res = [None] * 3
		for i in range(3):
			res[i] = ((self.basicIndex >> i) & 1) * (0xFF if self.intensive else 0x77)
		return dict(zip(("r", "g", "b"), res))

	def toRGBColor(self):
		return RGBColor(self.name, bg=self.bg, **self.toRGB())

	def toCSSColor(self):
		return RGB2CSSHex(**self.toRGB())


class BasicColor(_BasicColor):
	def __init__(self, name, basicIndex, intensive=False, bg=False):
		super().__init__(self.controlCodesColorRangeOffset, name)
		self.basicIndex = basicIndex
		self.bg = bg
		self.intensive = intensive

	@staticmethod
	def parse(name: str, code: int) -> "BasicColor":
		a = (__class__.mro()[1])(code, name)
		a.__class__ = __class__
		return a


class EnchancedColor(Color):
	"""Any color using enchancedColorBasicIndex as its basic index and extended with the other codes in a sequence"""

	def __init__(self, name: typing.Optional[str], codes: ContainerTuple[int]) -> None:
		super().__init__(name, codes)
		self.basicIndex = self.enchancedColorBasicIndex

	@property
	def typeIndex(self):
		return self.codes[1]

	@typeIndex.setter
	def typeIndex(self, col: int):
		self.codes = tupleReplace(self.codes, 1, col)


class IndexedColor(EnchancedColor):
	"""An enchanced color from 256 color pallete. Remember, that the palete is defined by terminal"""

	def __init__(self, name: typing.Optional[str], index: int, bg: bool = False) -> None:
		assert 0 <= index <= 255
		super().__init__(name, (self.controlCodesColorRangeOffset, 5, index))
		self.bg = bg

	@property
	def index(self):
		return self.codes[2]

	@index.setter
	def index(self, index: int):
		self.codes = tupleReplace(self.codes, 2, index)


def RGB2CSSHex(r: int, g: int, b: int):
	"""Converts an rgb triple into a CSS hex color representation"""
	return "#" + str(encode(bytes((r, g, b)), "hex"), encoding="ascii")


class RGBColor(EnchancedColor):
	"""A TrueColor color"""

	def __init__(self, name: typing.Optional[str], r: int = 0, g: int = 0, b: int = 0, bg: bool = False) -> None:
		if name is None:
			name = RGB2CSSHex(r, g, b)
		super().__init__(name, (self.controlCodesColorRangeOffset, 2, r, g, b))
		self.bg = bg
		#print(self)

	@property
	def r(self):
		return self.codes[2]

	@r.setter
	def r(self, col: int):
		self.codes = tupleReplace(self.codes, 2, col)

	@property
	def g(self):
		return self.codes[3]

	@g.setter
	def g(self, col: int):
		self.codes = tupleReplace(self.codes, 3, col)

	@property
	def b(self):
		return self.codes[4]

	@b.setter
	def b(self, col: int):
		self.codes = tupleReplace(self.codes, 4, col)
	
	def invert(self) -> "RGBColor":
		return self.__class__(0xFF - self.r, 0xFF - self.g, 0xFF - self.b)

	def toCSSColor(self):
		return RGB2CSSHex(self.r, self.g, self.b)


under_score2camelCaseRx = re.compile(r"""_(\w)""")


def under_score2camelCase(s: str) -> str:
	i = 0
	res = []
	for token in under_score2camelCaseRx.split(s):
		if i % 2 == 1:
			res.append(token.upper())
		else:
			res.append(token.lower())
		i += 1
	return "".join(res)


def importGroups(groups: Storage) -> None:  # pylint: disable=redefined-outer-name
	"""Used to import color codes from other installed packages"""

	try:
		from colored import colored

		def importColoredColors():
			clrd = colored("")
			for colorName, colValue in clrd.paint.items():
				colValue = int(colValue)
				colorName = under_score2camelCase(colorName)
				# pylint: disable=no-member
				groups.Fore.addStyle(IndexedColor(colorName, colValue, bg=False))
				groups.Back.addStyle(IndexedColor(colorName, colValue, bg=True))

		importColoredColors()
	except ImportError:
		pass
	try:
		import plumbum.colors

		def importPlumbumColors():
			for st in plumbum.colors:
				col = st.full.fg
				colorName = under_score2camelCase(col.name)
				# pylint: disable=no-member
				groups.Fore.addStyle(RGBColor(colorName, *col.rgb, bg=False))
				groups.Back.addStyle(RGBColor(colorName, *col.rgb, bg=True))

		importPlumbumColors()
	except ImportError:
		pass

	try:
		import colorama

		coloramaColRx = re.compile("^[A-Z_]+$")

		def importColoramaGroup(groupName, styleConstructor):
			"""Converts control codes from colorama to our styles"""
			coloramaGroup = getattr(colorama.ansi, "Ansi" + groupName)
			for colorName in dir(coloramaGroup):
				if coloramaColRx.match(colorName):  # colorama color names are written in UPPERCASE
					newName = under_score2camelCase(colorName)
					groups[groupName].addStyle(styleConstructor(newName, getattr(coloramaGroup, colorName)))

		for groupName in ["Back", "Fore"]:
			importColoramaGroup(groupName, BasicColor.parse)

	except ImportError:
		pass


importGroups(groups)


class Sheet(Storage):
	"""Represents the set of string's styles at any moment of time"""

	def __init__(self, new: typing.Optional[typing.Union[typing.Union[Style, "Sheet"], typing.List[Style], typing.Mapping[str, Style]]] = {}) -> None:
		if new is None:
			for gr in groups:
				self[gr] = groups[gr].reset
		else:
			if isinstance(new, Sheet):
				self.__dict__ = type(self.__dict__)(new.__dict__)
			elif isinstance(new, Style):
				#print("new is ", new)
				#print("new group is ", new.group)
				new = {new.group.name: new}
			elif isinstance(new, list):
				new = {n.group.name: n for n in new}
			super().__init__(new)

	def diff(self, new: "Sheet") -> "Sheet":
		old = self
		patch = Sheet({})
		for gr in groups:
			o = old[gr] if gr in old else groups[gr].reset
			n = new[gr] if gr in new else groups[gr].reset
			if o == neutral and n == groups[gr].reset:
				n = neutral

			if o != n:
				patch[gr] = n
		return patch

	def __sub__(self, other: "Sheet") -> "Sheet":
		return other.diff(self)

	def __add__(self, other: "Sheet") -> "Sheet":
		return self | other

	def __or__(self, other: "Sheet") -> "Sheet":
		tdic = dict(self.__dict__)
		tdic.update(other.__dict__)
		return Sheet(tdic)

	def __iadd__(self, other: "Sheet") -> "Sheet":
		self |= other
		return self

	def __ior__(self, other: "Sheet"):
		self.__dict__.update(other.__dict__)

	def __call__(self, *strs: typing.Iterable[typing.Union["RichStr", str]]):
		return RichStr(*strs, sheet=self)


def optimizeSheetsToCodes(buf: typing.List[typing.Union[Sheet, str]]) -> typing.Iterator[typing.Union[ControlCodes, str]]:
	"""Removes unneeded control codes. To do it computes diffs between initial state and final state """
	initialState = Sheet()
	state = type(initialState)(initialState)
	prevState = type(state)(state)

	for it in buf:
		if isinstance(it, Sheet):
			state = type(state)(it)
		else:
			yield from (state - prevState).values()
			prevState = type(state)(state)
			yield it

	yield from (initialState - prevState).values()


def mergeAdjacentCodes(buf: typing.Iterator[typing.Union[str, ControlCodes]]) -> typing.Iterator[typing.Union[str, ControlCodes]]:
	"""Merges adjacent Codes into a single Code"""
	accum = None
	for it in buf:
		if isinstance(it, ControlCodes):
			if accum is None:
				accum = it
			else:
				accum += it
		else:
			if accum is not None:
				yield accum
				accum = None
			yield it
	if accum is not None:
		yield accum


mergeCodes = True


class RichStr:
	"""Represents a string with rich formating. Makes a tree of strings and builds a string from that tree in the end"""

	def __init__(self, *args, sheet: typing.Optional[typing.Union[Style, Sheet]] = None) -> None:
		sheet = Sheet(sheet) if sheet is not None else Sheet()
		self.subStrs = list(args)
		self.sheet = sheet

	def __add__(self, other: typing.Union["RichStr", str]) -> "RichStr":
		return __class__(self, other)

	def __radd__(self, other: typing.Union["RichStr", str]) -> "RichStr":
		return __class__(other, self)

	def __iadd__(self, other: typing.Union["RichStr", str]) -> "RichStr":
		if isinstance(other, (str, RichStr)):
			self.subStrs.append(other)
		elif isinstance(other, list):
			self.subStrs += other
		return self

	def dfs(self, sheet: Sheet) -> typing.Iterator[typing.Union[Sheet, str]]:
		"""Transforms the directed acyclic graph of styles into an iterator of styles-applying operations and strings. It's your responsibility to ensure that the graph is acyclic, if it has a cycle you will have infinity recursion."""
		sheet = Sheet(sheet) + self.sheet
		for subStr in self.subStrs:
			if isinstance(subStr, RichStr):
				yield from subStr.dfs(sheet)
			else:
				yield sheet
				yield str(subStr)

	def sheetRepr(self) -> typing.List[typing.Union[Sheet, str]]:
		"""Returns flat representation of RichString - an array of (Sheet)s and (str)ings"""
		sheet = Sheet(None)
		buf = list(self.dfs(sheet))
		# print(buf)
		buf.append(sheet)
		return buf

	def optimizedCodeRepr(self) -> typing.List[typing.Union[str, ControlCodes]]:
		"""Returns optimized representation of RichString where all the styles are replaced with control codes"""
		buf = optimizeSheetsToCodes(self.sheetRepr())
		if mergeCodes:
			buf = mergeAdjacentCodes(buf)
		return list(buf)

	def plain(self) -> str:
		return "".join((tok for tok in self.sheetRepr() if isinstance(tok, str)))

	def getCSSStyle(self) -> str:
		"""Returns the equivalent CSS style"""
		#cssSheet:typing.Mapping[str, str]
		cssSheet = {}
		for styleItem in self.sheet.values():
			cssSheet.update(styleItem.toCSSProperty())
		return ";".join((":".join(styleItem) for styleItem in cssSheet.items()))

	def join(self, els) -> "RichStr":
		return rsjoin(self, els)

	def __str__(self) -> str:
		buf = (str(it) for it in self.optimizedCodeRepr())
		return "".join(buf)

	def __repr__(self) -> str:
		return self.__class__.__name__ + "(" + repr(self.sheetRepr()) + ")"

	def toHTML(self) -> str:
		"""A very dirty conversion to HTML"""
		buf = ["<span style='" + self.getCSSStyle() + "'>"]
		for el in self.subStrs:
			# pylint: disable=protected-access
			if hasattr(el, "_repr_html_"):
				buf.append(el._repr_html_())
			elif hasattr(el, "toHTML"):
				buf.append(el.toHTML())
			else:
				buf.append(str(el))
		buf.append("</span>")
		return "".join(buf)


def interleavedChain(delim, *iters):
	"""str.join for iterators """
	iters = iter(iters)
	yield next(iters)
	for item in iters:
		yield delim
		yield item


def rsjoin(delim: typing.Union[str, RichStr], itr: typing.Iterable[typing.Union[str, RichStr]], sheet: None = None) -> RichStr:
	"""Joins (RichStr)ings into a (RichStr)ing"""
	if delim:
		substrs = list(interleavedChain(delim, *itr))
	else:
		substrs = list(itr)
	return RichStr(*substrs, sheet=sheet)


"""Neutral stuff doing nothing for the cases where styles are required"""
neutral = Style("neutral", ())
neutralGroup = StyleGroup("Neutral", [neutral], neutral)
neutralSheet = Sheet({name: neutral for name in groups})

if __name__ == "__main__":
	import os

	thisLibName = os.path.splitext(os.path.basename(__file__))[0]

	wordDelimiter = re.compile("([\\W]+)")
	wordsStylers = itertools.cycle((groups.Back.red, groups.Back.green, groups.Back.blue))  # pylint: disable=no-member
	#import random
	#wordsStylers = itertools.cycle((random.choice(list(groups.Back.values())) for st in range(5)))  # pylint: disable=no-member

	def decorateWords(sent):
		"""Here we use styles as functors"""
		i = 0
		for token in wordDelimiter.split(sent):
			if i % 2 == 0:
				yield (next(wordsStylers))(token)
			else:
				yield token
			i += 1

	sentDelimiter = re.compile("([\\.?!])")
	sentenceStyles = itertools.cycle((Sheet({"Fore": groups.Fore.black, "Blink": groups.Blink.slow}), Sheet({"Fore": groups.Fore.yellow})))

	def decoratedSentences(par):
		"""Here we create RichString from iterator over substrings"""
		i = 0
		st = next(sentenceStyles)
		for token in sentDelimiter.split(par):
			if i % 2 == 1:
				st = next(sentenceStyles)
				yield RichStr(*decorateWords(token), sheet=st)
			else:
				yield RichStr(*decorateWords(token), sheet=st)

	def decorateSentences(par):
		return rsjoin("", decoratedSentences(par))

	paragraphDelimiter = "\n\n"
	paragraphsStylers = itertools.cycle((groups.Back.lightblackEx, groups.Back.white))

	def demo(text: str):
		"""Returns a string with paragraphs formatted"""
		return rsjoin(
			paragraphDelimiter,
			(
				(next(paragraphsStylers))(
					decorateSentences(par)
				)
				for par in text.split(paragraphDelimiter)
			)
		)

	print(demo(thisLibName))
	print(groups.Underline.underline(demo("https://gitlab.com/" + __author__ + "/" + thisLibName)))
	print(groups.Blink.rapid(
		groups.Underline.underline("Yo dawg"), " ", groups.Fore.red(groups.Back.lightcyanEx("so we heard")), " ",
		groups.Fore.lightyellowEx(
			"you", groups.Fore.lightredEx(" like "), groups.Brightness.bright("text styles")
		),
		" so we put styles ", groups.Back.green("in your styles"), " ", demo("so you can style while you styling"), "."
	))
	print(demo(__copyright__))
