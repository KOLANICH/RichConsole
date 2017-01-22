	/*
	__all__ = ("ControlCodes", "Style", "Color", "BasicColor", "IndexedColor", "RGBColor", "StyleGroup", "groups", "Sheet", "RichStr", "rsjoin", "neutral", "neutralGroup", "neutralSheet")
	__author__="KOLANICH"
	__license__="Unlicense"
	__copyright__=r"""
	This == free and unencumbered software released into the public domain.

	Anyone == free to copy, modify, publish, use, compile, sell, or
	distribute this software, either in source code form or as a compiled
	binary, for any purpose, commercial or non-commercial, and by any
	means.

	In jurisdictions that recognize copyright laws, the author or authors
	of this software dedicate any and all copyright interest in the
	software to the public domain. We make this dedication for the benefit
	of the public at large and to the detriment of our heirs and
	successors. We intend this dedication to be an overt act of
	relinquishment in perpetuity of all present and future rights to this
	software under copyright law.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
	IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
	OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
	ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
	OTHER DEALINGS IN THE SOFTWARE.

	For more information, please refer to <https://unlicense.org/>
	"""
	*/

//import IterTools;
import haxe.rtti.Meta;

extern class Object {
	public var __dict__ : python.Dict<String, Dynamic>;
	public var __class__ : Type;
}
extern class PythonType extends Type {
	public function mro(): Array<PythonType>;
}

@doc("Represents a sequence of control codes")
class ControlCodes extends Object{
	public var codes : python.Tuple<UInt>;
	public function new(codes:Dynamic){
		if(!Std.is(codes, Iterable)){
			if(Std.is(codes, UInt)){
				codes = [codes];
			}else{
				throw new python.TypeError("The argument must be either tuple of ints or an int");
			}
		}
		this.codes=python.Tuple<UInt>(codes);
	}
	
	@:to
	public function toString():String{
		if(this.codes){
			return ["\x1b[",[for (c in this.codes) Std.string(c) ].join(";"),"m"].join("");
		}else{
			return "";
		}
	}
	
	@:to
	public function __repr__():String{
		return [Type.getClassName(Type.getClass(this)), "(", python.repr(this.codes), ")"].join("");
	}
	
	@:op(A == B)
	public function __eq__(other){
		return this.codes==other.codes;
	}
	public function __hash__(){
		return hash(this.codes);
	}
	
	@:op(A + B)
	public function __add__(other:ControlCodes){
		//if( Type.getClass(this) == Type.getClass(other)){
		//	this.codes+=other.codes
		//	return Type.createInstance(Type.getClass(this), [this.codes+other.codes])
		//}else
		//return __class__(this.codes+other.codes);
		return new ControlCodes(this.codes+other.codes);
		
	}
}

@doc("Represents a style of a string. Its groups contain groups of active styles")
class Style extends ControlCodes{
	public var name : String;
	public var group : StyleGroup;
	public function new(name:String, codes:Iterable<UInt>, group:StyleGroup=null){
		super(codes);
		this.name=name;
		this.group=group;
	}
	public function toCSSProperty(){
		return {};
	}
	public function __repr__(){
		return "".join(
			[
				Std.string(this),
				(if (this.group && this.group.name) (this.group.name+":") else ""),
				this.name,
				(if (this.group && this.group.reset) Std.string(this.group.reset) else "\x1b[0m")
			]
		);
	}
	
	@:op(A + B)
	public function __add__(other:Style){
		if(this.group == other.group){
			//return __class__(this.name+"&"+other.name, this.codes+other.codes);
			return new Style(this.name+"&"+other.name, this.codes+other.codes);
		}else{
			//return (__class__.mro()[1])(this.codes+other.codes);
			return new ControlCodes(this.codes+other.codes);
		}
	}
	public function __call__(strs:python.Tuple<Dynamic>){
		return new RichStr(strs, this);
	}
}

@doc("Represents a storage allowing access by both . and [] notation")
class Storage extends Object implements haxe.Constraints.IMap<String, Any>{
	public function new(val=null){
		if( val == null ){
			val=new Map();
		}
		if( Std.is(val, haxe.Constraints.IMap) ){
			this.__dict__=Type.createInstance(Type.getClass(this.__dict__), [val]);
		}
	}
	public function iterator(){
		return iter(this.__dict__);
	}
	
	@:arrayAccess
	public function get(key:String):Dynamic{
		return this.__dict__[key];
	}
	
	@:arrayAccess
	public function set(key:String, val:Dynamic){
		this.__dict__[key]=val;
	}
	
	
	public function __delitem__(key:String){
		del(this.__dict__[key]);
	}
	
	public function __hasitem__(item){
		return item in this.__dict__;
	}
	
	public function __len__(){
		return len(this.__dict__);
	}
	public function values(){
		return this.__dict__.values();
	}
	public function keys(){
		return this.__dict__.keys();
	}
	public function __repr__(){
		return Type.getClassName(Type.getClass(this))+"("+python.repr(this.__dict__)+")";
	}
}

@doc("Represent a group of mutually exclusive styles. ```reset``` == dedicated style returning style to default")
class StyleGroup extends Storage{
	public var reset:ControlCodes;
	public var name:String;
	public function new(name:String, styles:Iterable<Style>, reset:Style=null){
		if( reset != null && ! Std.is(reset, Style) ){
			throw new python.Exceptions.TypeError("Must be either ", Type.getClass(null), " or compatible with ", Style, " but ", Type.getClass(reset), " was given");
		}
		super();
		for(style in styles){
			this.addStyle(style);
		}
		this.reset=reset;
		this.name=name;
	}
	
	public function addStyle(style: Style){
		this[style.name]=style;
		style.group=this;
	}
	
	@:to
	public function toString():String{
		return python.repr(this.values());
	}
	
	@:to
	override public function __repr__():String{
		return [
			Type.getClassName(Type.getClass(this)),"(",
			[ python.repr(this.name), python.repr([for(v in this.values()) if (Std.is(v, Style)) v]), "reset="+python.repr(this.reset) ].join(", "),
			")"
		].join("");
	}
}


class Color extends Style{
	@doc("color-related control codes occupy the range between [30; 50)")
	static public var controlCodesColorRangeOffset:UInt = 30;
	@doc("you need to add 10 to make foreground color background")
	static public var backgroundOffset:UInt = 10;
	@doc("this is the basic index of color reserved for extended colors")
	static public var enchancedColorBasicIndex:UInt = 8;
	@doc("this is gcd(controlCodesColorRangeOffset, intensiveOffset). Since it == not 1 and > than maximum basic index we can use it to get the basic index")
	static public var offset_intensiveOffset_GCD:UInt = 30;
	
	public function splitBasicIndex(code){
		return code%offset_intensiveOffset_GCD;
	}
	public function new(name:String, codes:Iterable<UInt>){
		super(name, codes);
	}
	public var code(get, set):UInt;
	
	@doc("A main (with index zero) control code of the color code = controlCodesColorRangeOffset + basicIndex + (bg?10:0) + (intensive?60:0)")
	public function get_code():UInt{
		return this.codes[0];
	}
	public function set_code(code:UInt){
		this.codes=Utils.TupleReplace(this.codes, 0, code);
		return code;
	}
	
	@doc("An basicIndex of the color - its control code - controlCodesColorRangeOffset")
	public var basicIndex(get, set):UInt;
	public function get_basicIndex():UInt{
		return splitBasicIndex(this.code);
	}
	public function set_basicIndex(basicIndex:UInt){
		this.code+=(-this.basicIndex+basicIndex);
		return basicIndex;
	}
	
	@doc("Changes property name by magic in the right direction to make it have the value val")
	public function setNumeric(name:String, val:Bool, magic:UInt){
		var prev=python.getattr(name);
		this.code+=(UInt(val) - UInt(prev))*magic;
	}
	
	@doc("Is the color applied to background?")
	public var bg(get, set):Bool;
	public function get_bg():Bool{
		return this.basicIndex>=backgroundOffset;
	}
	public function set_bg(bg:Bool){
		this.setNumeric("bg", bg, backgroundOffset);
		return bg;
	}
	
	//public var group(get, set):StyleGroup;
	public function get_group():StyleGroup{
		return (if (this.bg) groups.Back else groups.Fore);
	}
	public function set_group(group:StyleGroup){
		if(group == null){
			return null;
		}
		if(group == groups.Back){
			this.bg=true;
			return this.group;
		}
		if(group == groups.Fore){
			this.bg=false;
			return this.group;
		}
		throw new AssertionError("".join(["Group must be euther ", groups.Fore.name, " or ", groups.Back.name, ", ", group.name, " given"]));
	}
	public function toCSSProperty(){
		var nm=((if (this.bg)"background-" else "")+"color");
		return {nm:this.toCSSColor()};
	}
}

@doc("code = controlCodesColorRangeOffset + basicIndex + (bg?10:0) + (intensive?60:0)")
@:yield
class _BasicColor extends Color{
	var intensiveOffset:UInt=60;
	
	public function new(code, name:String=null){
		super(name, [code,]);
	}
	
	@doc("Is the color intensive?")
	public var intensive(get, set):Bool;
	public function get_intensive():Bool{
		return this.code>=(this.intensiveOffset+Reflect.field(Type.getClass(this), "controlCodesColorRangeOffset"));
	}
	public function set_intensive(val:Bool){
		this.setNumeric("intensive", val, intensiveOffset);
		return val;
	}
	public function toRGB_(){
		for(i in 0...3){
			@yield return ((this.basicIndex >> i) & 1)*(if (this.intensive) 0xFF else 0x77);
		}
	}
	public function toRGB(){
		var res=new Map();
		var keys=["r", "g", "b"];
		var i=0;
		for(val in toRGB_()){
			res[keys[i]] = val;
			i++;
		}
		return res;
	}
	public function toRGBColor(){
		var rgb=[for(col in this.toRGB_()) col];
		return new RGBColor(this.name, rgb[0], rgb[1], rgb[2], bg=this.bg);
	}
	public function toCSSColor(){
		var rgb=[for(col in this.toRGB_()) col];
		return Utils.RGB2CSSHex(rgb[0], rgb[1], rgb[2]);
	}
}

class BasicColor extends _BasicColor{
	public function new(name:String, basicIndex:UInt, intensive:Bool=false, bg:Bool=false){
		super(Reflect.field(Type.getClass(this), "controlCodesColorRangeOffset"), name);
		this.basicIndex=basicIndex;
		this.bg=bg;
		this.intensive=intensive;
	}
	public function parse(name, code){
		var a = new _BasicColor(code, name);
		a.__class__=__class__;
		return a;
	}
}

@doc("Any color using enchancedColorBasicIndex as its basic index and extended with the other codes in a sequence")
class EnchancedColor extends Color{
	public function new(name:String, codes){
		super(name, codes);
		this.basicIndex=Reflect.field(Type.getClass(this), "enchancedColorBasicIndex");
	}
	public var typeIndex(get, set):UInt;
	public function get_typeIndex():UInt{
		return this.codes[1];
	}
	public function set_typeIndex(col:UInt){
		this.codes=Utils.TupleReplace(this.codes, 1, col);
		return col;
	}
}

@doc("An enchanced color from 256 color pallete. Remember, that the palete == defined by terminal")
class IndexedColor extends EnchancedColor{
	public function new(name:String, index:UInt, bg:Bool=false){
		//assert(index >= 0 && index <= 255);
		super(name, [Reflect.field(Type.getClass(this), "controlCodesColorRangeOffset"), 5, index]);
		this.bg=bg;
	}
	
	public var index(get, set):UInt;
	public function get_index():UInt{
		return this.codes[2];
	}
	public function set_index(index:UInt){
		this.codes=Utils.TupleReplace(this.codes, 2, index);
		return index;
	}
}

@doc("A TrueColor color")
class RGBColor extends EnchancedColor{
	
	/*public function new(name:String=null, colors:python.Tuple<UInt>, bg:Bool=false){
		this.new(name, colors[0], colors[1], colors[2], bg);
	}*/
	public function new(name:String=null, r:UInt=0, g:UInt=0, b:UInt=0, bg:Bool=false){
		super(name, python.Syntax.tuple(Reflect.field(Type.getClass(this), "controlCodesColorRangeOffset"), 2, r, g, b));
		this.bg=bg;
		//prUInt();
	}
	public var r(get, set):UInt;
	public function get_r():UInt{
		return this.codes[2];
	}
	public function set_r(col:UInt){
		this.codes=Utils.TupleReplace(this.codes, 2, col);
		return col;
	}
	
	public var g(get, set):UInt;
	public function get_g():UInt{
		return this.codes[3];
	}
	public function set_g(col:UInt){
		this.codes=Utils.TupleReplace(this.codes, 3, col);
		return col;
	}
	
	public var b(get, set):UInt;
	public function get_b():UInt{
		return this.codes[4];
	}
	public function set_b(col:UInt){
		this.codes=Utils.TupleReplace(this.codes, 4, col);
		return col;
	}

	public function toCSSColor(){
		return Utils.RGB2CSSHex(this.r, this.g, this.b);
	}
}

@doc("Represents the set of string's styles at any moment of time")
class Sheet extends Storage{
	public function new(proto={}){
		if( proto == null){
			for(gr in groups){
				this[gr]=groups[gr].reset;
			}
		}
		if( Std.is(proto, Sheet)){
			this.__dict__=Type.createInstance(Type.getClass(this.__dict__), [proto.__dict__]);
		}
		if( Std.is(proto, Style)){
			//prUInt("new == ", proto)
			//prUInt("new group == ", proto.group);
			gn=proto.group.name;
			proto=python.dict([gn,proto]);
		}
		if( Std.is(proto, Array)){
			gn=n.group.name;
			proto=python.dict([for (n in proto) [gn, n]]);
		}
		super(proto);
	}
	public function diff(old, newO){
		patch=new Sheet({});
		for(gr in groups){
			o= if (gr in old) old[gr] else groups[gr].reset;
			n= if (gr in newO) newO[gr] else groups[gr].reset;
			if( o==neutral && n==groups[gr].reset){
				n=neutral;
			}
			if( o!=n){
				patch[gr]=n;
			}
		}
		return patch;
	}
	
	@:op(A - B)
	public function __sub__(other:Sheet){
		return other.diff(this);
	}
	
	@:op(A + B)
	public function __add__(other:Sheet){
		return this|other;
	}
	
	@:op(A | B)
	public function __or__(other:Sheet){
		tdic=dict(this.__dict__);
		tdic.update(other.__dict__);
		return new Sheet(tdic);
	}
	
	@:op(A + B)
	public function __iadd__(other:Sheet){
		this|=other;
	}
	
	@:op(A | B)
	public function __ior__(other:Sheet){
		this.__dict__.update(other.__dict__);
	}
	
	public function __call__(strs:python.Tuple<Dynamic>){
		return new RichStr(strs, this);
	}
}

@doc("Represents a string with rich formating. Makes a tree of strings and builds a string from that tree in the end")
@:yield
class RichStr {
	var subStrs:Array<Dynamic>;
	var sheet:Sheet;
	
	public function new(args:python.Tuple<Dynamic>, sheet:Sheet=null){
		sheet = if (sheet != null) new Sheet(sheet) else new Sheet();
		this.subStrs=[for(arg in args) arg];
		this.sheet=sheet;
	}
	
	@:op(A + B)
	public function __add__(args:Iterable<Dynamic>){
		return new RichStr(args);
	}
	
	@:op(A + B)
	public function __radd__(other){
		return new RichStr(other, this);
	}
	
	@:op(A + B)
	public function __iadd__(other){
		if( Std.is(other, str) || Std.is(other, RichStr)){
			this.subStrs.append(other);
		}
		else if( Std.is(other, Array) || Std.is(other, python.Tuple)){
			this.subStrs+=other;
		}
	}
	
	@doc("Transforms the directed acyclic graph of styles into an iterator of styles-applying operations and strings. It's your responsibility to ensure that the graph == acyclic, if it has a cycle you will have infinity recursion.")
	public function dfs(sheet){
		sheet=new Sheet(sheet)+this.sheet;
		for(subStr in this.subStrs){
			if( Std.is(subStr, RichStr)){
				return subStr.dfs(sheet);
			}
			else{
				@yield return sheet;
				@yield return str(subStr);
			}
		}
	}
	@doc("Returns flat representation of RichString - an array of (Sheet)s and (str)ings")
	public function sheetRepr(){
		sheet=new Sheet(null);
		buf=[for(item in this.dfs(sheet)) item];
		//prUInt(buf)
		buf.append(sheet);
		return buf;
	}
	@doc("Returns optimized representation of RichString where all the styles are replaced with control codes")
	public function optimizedCodeRepr(){
		var buf=[for(item in this.sheetRepr()) item];
		//prUInt(buf)
		buf=[for(item in optimizeSheetsToCodes(buf)) item];
		//prUInt(buf)
		if( mergeCodes){
			buf=mergeAdjacentCodes(buf);
		}
		return [for(item in buf) item];
	}
	public function plain():String{
		return "".join([for(tok in this.sheetRepr()) if(Std.is(tok, String)) tok]);
	}
	
	@doc("Returns the equivalent CSS style")
	public function getCSSStyle():String{
		cssSheet={};
		for(styleItem in this.sheet.values()){
			cssSheet.update(styleItem.toCSSProperty());
		}
		return ";".join([for(styleItem in cssSheet.items()) ":".join(styleItem)]);
	}
	public function join(els){
		return rsjoin(els);
	}
	
	@:to
	public function toString():String{
		buf=this.optimizedCodeRepr();
		buf=[for(it in buf) str(it)];
		return "".join(buf);
	}
	
	@:to
	public function __repr__():String{
		return Type.getClassName(Type.getClass(this))+"("+python.repr(this.sheetRepr())+")";
	}
	
	@doc("A very dirty conversion to HTML")
	public function toHTML(){
		buf=["<span style='"+this.getCSSStyle()+"'>"];
		for(el in this.subStrs){
			if( hasattr(el, "_repr_html_")){
				buf.append(el._repr_html_());
			}
			else if( hasattr(el, "toHTML")){
				buf.append(el.toHTML());
			}
			else{
				buf.append(str(el));
			}
		}
		buf.append("</span>");
		return "".join(buf);
	}
}

@:yield
class Utils{
	static public function initGroups(): Void{
		//global groups;
		var reset     =new Style("reset", python.Syntax.tuple(0));
		var blinkReset=new Style("reset", python.Syntax.tuple(25));
		var foreReset =new Style("reset", python.Syntax.tuple(39));
		var backReset =new Style("reset", python.Syntax.tuple(49));
		var brightReset=new Style("reset", python.Syntax.tuple(21));
		var decorReset=new Style("reset", python.Syntax.tuple(23));
		var underlineReset=new Style("reset", python.Syntax.tuple(24));
		var concealReset=new Style("reset", python.Syntax.tuple(28));
		var crossedOutReset=new Style("reset", python.Syntax.tuple(29));
		var frameReset=new Style("reset", python.Syntax.tuple(54));
		var overlineReset=new Style("reset", python.Syntax.tuple(55));
		var ideogramReset=new Style("reset", python.Syntax.tuple(65));
		var fontReset=new Style("reset", python.Syntax.tuple(10));

		var fontsCodes=python.Syntax.tuple([for(i in 0...9) new Style("f"+str(i), python.Syntax.tuple(11+i))]);
		fontsCodes.append(fontReset);

		@doc("This is our global storage of styles")
		groups=new Storage({
			"Back"   : new StyleGroup("Back" , python.Syntax.tuple(backReset), backReset),
			"Fore"   : new StyleGroup("Fore" , python.Syntax.tuple(foreReset), foreReset),
			"Brightness"  : new StyleGroup("Brightness", python.Syntax.tuple(new Style("bright", python.Syntax.tuple(1)), new Style("dim", python.Syntax.tuple(2)), brightReset), brightReset),
			"Decor"  : new StyleGroup("Decor", python.Syntax.tuple(new Style("italic", python.Syntax.tuple(3)), new Style("fraktur", python.Syntax.tuple(20)), decorReset ), decorReset),
			"Underline"  : new StyleGroup("Underline", python.Syntax.tuple(new Style("underline", python.Syntax.tuple(4)), underlineReset), underlineReset),
			"CrossedOut"  : new StyleGroup("CrossedOut", python.Syntax.tuple(new Style("crossedOut", python.Syntax.tuple(9)), crossedOutReset), crossedOutReset),
			"Conceal"  : new StyleGroup("Conceal", python.Syntax.tuple(new Style("conceal", python.Syntax.tuple(8)), concealReset), concealReset),
			"Blink"  : new StyleGroup("Blink", python.Syntax.tuple(new Style("slow", python.Syntax.tuple(5)), new Style("rapid", python.Syntax.tuple(6)), blinkReset), blinkReset),
			"Frame"  : new StyleGroup("Frame", python.Syntax.tuple(new Style("framed", python.Syntax.tuple(51)), new Style("encircled", python.Syntax.tuple(52)), frameReset), frameReset),
			"Overline"  : new StyleGroup("Overline", python.Syntax.tuple(new Style("overlined", python.Syntax.tuple(53)), overlineReset), overlineReset),
			"Ideogram"  : new StyleGroup("Ideogram", python.Syntax.tuple(new Style("singleUnderOrRight", python.Syntax.tuple(60)), new Style("doubleUpperOrRight", python.Syntax.tuple(61)), new Style("singleOverOrLeft", python.Syntax.tuple(62)), new Style("doubleOverOrLeft", python.Syntax.tuple(63)), new Style("stress", python.Syntax.tuple(64)) , ideogramReset), ideogramReset),
			"Font"  : new StyleGroup("Font", fontsCodes, fontReset),
		});
	}

	static public function TupleReplace(tp:python.Tuple<UInt>, pos:UInt, newVal:UInt):python.Tuple<UInt>{
		var prev=Math.max(pos-1, 0);
		//return python.Syntax.tuple(tp[python.slice(0,prev)]+[newVal,]+tp[python.slice(pos+1)]);
		return python.Syntax.tuple(tp[python.slice(0,prev)]+[newVal,]+tp[python.slice(pos+1)]);
	}

	static public function RGB2CSSHex(r:UInt, g:UInt, b:UInt):String{
		//"""Converts an rgb triple into a CSS hex color representation"""
		return "#"+StringTools.hex(r)+StringTools.hex(g)+StringTools.hex(b);
	}

	static var under_score2camelCaseRx=~/_(\w)/;
	static public function under_score2camelCase(str){
		i=0;
		res=[];
		for(token in under_score2camelCaseRx.split(str)){
			if(i%2==1){
				res.append(token.upper());
			}else{
				res.append(token.lower());
			}
			i+=1;
		}
		return res.join("");
	}

	@doc("Used to import color codes from other installed packages")
	static public function importGroups(): Void{
		//global groups;
		
		try{
			function importColoredColors(){
				clrd=python.colored.colored("");
				for([colorName, colValue] in clrd.paint.items()){
					colValue=UInt(colValue);
					colorName=under_score2camelCase(colorName);
					groups.Fore.addStyle(new IndexedColor(colorName, colValue, bg=false));
					groups.Back.addStyle(new IndexedColor(colorName, colValue, bg=true));
				}
			}
			
			importColoredColors();
		} catch(err:ImportError){
			pass;
		}
		try{
			function importPlumbumColors(){
				for(st in python.plumbum.colors){
					col=st.full.fg;
					colorName=under_score2camelCase(col.name);
					groups.Fore.addStyle(new RGBColor(colorName, col.rgb, bg=false));
					groups.Back.addStyle(new RGBColor(colorName, col.rgb, bg=true));
				}
			}
			importPlumbumColors();
		}catch(err:ImportError){
			pass;
		}
		
		try{
			coloramaColRx=~/^[A-Z_]+$/;
			
			@doc("Converts control codes from colorama to our styles")
			function importColoramaGroup(groupName, styleConstructor){
				coloramaGroup=python.getattr(python.colorama.ansi, "Ansi"+groupName);
				for(colorName in dir(coloramaGroup)){
					if( coloramaColRx.match(colorName)){ //colorama color names are written in UPPERCASE
						newName=under_score2camelCase(colorName);
						groups[groupName].addStyle(styleConstructor(newName, python.getattr(coloramaGroup, colorName)));
					}
				}
			};
			
			for(groupName in ["Back", "Fore"]){
				importColoramaGroup(groupName, BasicColor.parse);
			}
			
		}catch(err:ImportError){
			pass;
		}
	}

	@doc("Removes unneeded control codes. To do it computes diffs between initial state and final state ")
	static public function optimizeSheetsToCodes(buf){
		initialState=new Sheet();
		state=Type.createInstance(Type.getClass(initialState), [initialState]);
		prevState=Type.createInstance(Type.getClass(state), [state]);
		
		for(it in buf){
			if( Std.is(it, Sheet)){
				state=Type.createInstance(Type.getClass(state), [it]);
			}
			else{
				for(v in (state-prevState).values()){
					@yield return v;
				}
				prevState=Type.createInstance(Type.getClass(state), [state]);
				@yield return it;
			}
		}
		
		for(v in (initialState-prevState).values()){
			@yield return v;
		}
	}

	@doc("Merges adjacent Codes into a single Code")
	static public function mergeAdjacentCodes(buf){
		accum=null;
		for(it in buf){
			if( Std.is(it, ControlCodes)){
				if( accum == null){
					accum=it;
				}else{
					accum+=it;
				}
			}
			else{
				if( accum != null){
					@yield return accum;
					accum=null;
				}
				@yield return it;
			}
		}
		if( accum != null){
			@yield return accum;
		}
	}

	static var mergeCodes:Bool=true;

	@doc("str.join for iterators")
	static public function interleavedChain(delim, iters){
		iters=iter(iters);
		@yield return (next(iters));
		for(item in iters){
			@yield return (delim);
			@yield return (item);
		}
	}

	@doc("Joins (RichStr)ings into a (RichStr)ing")
	static public function rsjoin(delim, iter, sheet=null): RichStr{
		if( delim){
			substrs=list(interleavedChain(delim, iter));
		}
		else{
			substrs=list(iter);
		}
		return new RichStr(substrs, sheet=sheet);
	}

	@doc("Neutral stuff doing nothing for the cases where styles are required")
	var neutral=new Style("neutral", []);
	var neutralGroup=new StyleGroup("Neutral", [neutral], neutral);
	var neutralSheet=new Sheet(python.dict([for(name in groups) [name,neutral]]));
}

class Main {
	static public function main():Void {
		Utils.initGroups();
		Utils.importGroups();
		
		//import os, random;
		//from pprint import pprint;
		thisLibName=os.path.splitext(os.path.basename(__file__))[0];
		
		wordDelimiter=~/([\W]+)/;
		wordsStylers=IterTools.cycle([groups.Back.red, groups.Back.green, groups.Back.blue]);
		//wordsStylers=IterTools.cycle((random.choice(list(groups.Back.values())) for(st in 0...5)));
		
		
		function decorateWords(sent){
			//Here we use styles as functors
			i=0;
			for(token in wordDelimiter.split(sent)){
				if( i%2==0){
					@yield return (next(wordsStylers))(token);
				} else {
					@yield return token;
				}
				i+=1;
			}
		}
		sentDelimiter=~/([\.?!])/;
		sentenceStyles=IterTools.cycle([new Sheet({"Fore":groups.Fore.black, "Blink":groups.Blink.slow}), new Sheet({"Fore":groups.Fore.yellow})]);
		
		@doc("Here we create RichString from iterator over substrings")
		function decoratedSentences(par){
			i=0;
			st=next(sentenceStyles);
			for(token in sentDelimiter.split(par)){
				if( i%2==1){
					st=next(sentenceStyles);
					@yield return new RichStr(decorateWords(token), st);
				}
				else{
					@yield return new RichStr(decorateWords(token), st);
				}
			}
		}
		
		function decorateSentences(par){
			return rsjoin("", decoratedSentences(par));
		}
		
		paragraphDelimiter="\n\n";
		paragraphsStylers=IterTools.cycle([groups.Back.lightblackEx, groups.Back.white]);
		
		@doc("Returns a string with paragraphs formatted")
		function demo(text:String){
			return rsjoin(
				paragraphDelimiter,
				[
					for(par in text.split(paragraphDelimiter))
					
					(next(paragraphsStylers))(
						decorateSentences(par)
					)
				]
			);
		}

		prUInt(demo(thisLibName));
		prUInt(groups.Underline.underline(demo("https://github.com/"+__author__+"/"+thisLibName)));
		prUInt(groups.Blink.rapid(groups.Underline.underline("Yo dawg"), " ", groups.Fore.red(groups.Back.lightcyanEx("so we heard")), " ", groups.Fore.lightyellowEx("you", groups.Fore.lightredEx(" like "), groups.Brightness.bright("text styles")), " so we put styles ", groups.Back.green("in your styles"), " ", demo("so you can style while you styling"), "."));
		prUInt(demo(__copyright__));

	}
}
