#!/usr/bin/env python3
import sys
from pathlib import Path
import unittest
import itertools, re
import colorama

sys.path.insert(0, str(Path(__file__).parent.parent))

from collections import OrderedDict

dict = OrderedDict

import RichConsole
from RichConsole import *

red = groups.Fore.red
green = groups.Back.lightgreenEx
cyan = groups.Fore.cyan
blue = groups.Back.blue

trueRed = RGBColor("TrueRed", 0xFF, bg=True)
indexedRed = IndexedColor("IndexedRed", 1)


class Tests(unittest.TestCase):
	reference = (
		(
			RichStr("RRR", sheet=red),
			"".join((colorama.Fore.RED    ,"RRR", colorama.Fore.RESET))
		),
		(
			RichStr("RRR", sheet=indexedRed),
			"".join(("\x1b[38;5;1m"      , "RRR", colorama.Fore.RESET))
		),
		(
			RichStr("RRR", sheet=trueRed),
			"".join(("\x1b[48;2;255;0;0m", "RRR", colorama.Back.RESET))
		),
		(
			RichStr(    "DDD", RichStr("RRR",     RichStr("GGG", sheet=green), "rrr", sheet=red),"ddd"),
			RichStr(    "DDD",     red("RRR",       green("GGG"),              "rrr"),           "ddd"),
			rsjoin("", ("DDD",     red("RRR",       green("GGG"),              "rrr"),           "ddd")),
			(           "DDD"  +   red("RRR",       green("GGG"),              "rrr") +          "ddd"),
			(           "DDD"  +   red("RRR") + red(green("GGG"))    +     red("rrr") +          "ddd"),
			"".join(("DDD", colorama.Fore.RED, "RRR", colorama.Back.LIGHTGREEN_EX, "GGG", colorama.Back.RESET, "rrr", colorama.Fore.RESET, "ddd"))
		),
		(
			RichStr( "DDD",                red("RRR",                        green("GGG"),                     "rrr"),                     "ddd" ),
			"".join(("DDD", colorama.Fore.RED, "RRR", colorama.Back.LIGHTGREEN_EX, "GGG", colorama.Back.RESET, "rrr", colorama.Fore.RESET, "ddd"))
		),
	)
	
	controlCodeRx=re.compile("\x1b\[(\d+;)*?\d+?m")
	
	def testReferenceCases(self):
		for case in self.reference:
			for i, testRStr in enumerate(case[:-1]):
				self.assertEqual(str(testRStr), case[-1])

	def testPlain(self):
		"""tests plaing method, which should return unstyled string"""
		for case in self.reference:
			for i, testRStr in enumerate(case[:-1]):
				self.assertEqual(testRStr.plain(), self.controlCodeRx.sub("", case[-1]))

	def testSideEffects(self):
		"""Test that renering child and parent RichStrs doesn't influence each other"""
		order = []
		order.append(RichStr("GGG", sheet=green))
		order.append(RichStr("CCC", sheet=cyan))
		order.append(RichStr("RRR", order[0], "rrr", order[1], "RRR", sheet=red))
		order.append(RichStr("DDD", order[2], "ddd"))

		perms = list(itertools.permutations(range(len(order))))[1:]
		reference = [str(rs) for rs in order]

		for perm in perms:
			self.assertEqual([str(rs) for rs in (order[pos] for pos in perm)], [reference[pos] for pos in perm])


class TestCodeMerger(unittest.TestCase):
	def testCodeMerger1(self):
		"""Test control codes merger"""
		data = ["1", red, blue, "2", green, "3", blue, "4", groups.Fore.reset, groups.Back.reset, "5"]
		res = list(RichConsole.mergeAdjacentCodes(data))
		expected = ["1", red + blue, "2", green, "3", blue, "4", groups.Fore.reset + groups.Back.reset, "5"]
		self.assertEqual(res, expected)


if __name__ == "__main__":
	unittest.main()
