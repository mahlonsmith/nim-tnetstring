# vim: set et sta sw=4 ts=4 :

import
    std/hashes,
    std/parseutils,
    std/strutils

const TNETSTRING_VERSION* = "0.2.0"

type
  TNetstringKind* = enum     ## enumeration of all valid types
    TNetstringString,        ## a string literal
    TNetstringInt,           ## an integer literal
    TNetstringFloat,         ## a float literal
    TNetstringBool,          ## a ``true`` or ``false`` value
    TNetstringNull,          ## the value ``null``
    TNetstringObject,        ## an object: the ``}`` token
    TNetstringArray          ## an array: the ``]`` token

  TNetstringNode* = ref TNetstringNodeObj
  TNetstringNodeObj* {.acyclic.} = object
      extra*: string
      case kind*: TNetstringKind
      of TNetstringString:
          str*: string
      of TNetstringInt:
          num*: BiggestInt
      of TNetstringFloat:
          fnum*: float
      of TNetstringBool:
          bval*: bool
      of TNetstringNull:
          nil
      of TNetstringObject:
          fields*: seq[ tuple[key: string, val: TNetstringNode] ]
      of TNetstringArray:
          elems*: seq[ TNetstringNode ]

  TNetstringParseError* = object of ValueError ## Raised for a TNetstring error


func newTNetstringString*( s: string ): TNetstringNode =
    ## Create a new String typed TNetstringNode.
    result = TNetstringNode( kind: TNetstringString )
    result.str = s


func newTNetstringInt*( i: BiggestInt ): TNetstringNode =
    ## Create a new Integer typed TNetstringNode.
    result = TNetstringNode( kind: TNetstringInt )
    result.num = i


func newTNetstringFloat*( f: float ): TNetstringNode =
    ## Create a new Float typed TNetstringNode.
    result = TNetstringNode( kind: TNetstringFloat )
    result.fnum = f


func newTNetstringBool*( b: bool ): TNetstringNode =
    ## Create a new Boolean typed TNetstringNode.
    result = TNetstringNode( kind: TNetstringBool )
    result.bval = b


func newTNetstringNull*(): TNetstringNode =
    ## Create a new nil typed TNetstringNode.
    result = TNetstringNode( kind: TNetstringNull )


func newTNetstringObject*(): TNetstringNode =
    ## Create a new Object typed TNetstringNode.
    result = TNetstringNode( kind: TNetstringObject )
    result.fields = @[]


func newTNetstringArray*(): TNetstringNode =
    ## Create a new Array typed TNetstringNode.
    result = TNetstringNode( kind: TNetstringArray )
    result.elems = @[]


func getStr*( node: TNetstringNode, default: string = "" ): string =
    ## Retrieves the string value of a `TNetstringString TNetstringNodee`.
    ## Returns ``default`` if ``node`` is not a ``TNetstringString``.
    if node.kind != TNetstringString: return default
    return node.str


func getInt*( node: TNetstringNode, default: BiggestInt = 0 ): BiggestInt =
    ## Retrieves the int value of a `TNetstringInt TNetstringNode`.
    ## Returns ``default`` if ``node`` is not a ``TNetstringInt``.
    if node.kind != TNetstringInt: return default
    return node.num


func getFloat*( node: TNetstringNode, default: float = 0.0 ): float =
    ## Retrieves the float value of a `TNetstringFloat TNetstringNode`.
    ## Returns ``default`` if ``node`` is not a ``TNetstringFloat``.
    if node.kind != TNetstringFloat: return default
    return node.fnum


func getBool*( node: TNetstringNode, default: bool = false ): bool =
    ## Retrieves the bool value of a `TNetstringBool TNetstringNode`.
    ## Returns ``default`` if ``node`` is not a ``TNetstringBool``.
    if node.kind != TNetstringBool: return default
    return node.bval


func getFields*( node: TNetstringNode,
    default: seq[tuple[key: string, val: TNetstringNode]] = @[] ):
        seq[tuple[key: string, val: TNetstringNode]] =
    ## Retrieves the key, value pairs of a `TNetstringObject TNetstringNode`.
    ## Returns ``default`` if ``node`` is not a ``TNetstringObject``.
    if node.kind != TNetstringObject: return default
    return node.fields


func getElems*( node: TNetstringNode, default: seq[TNetstringNode] = @[] ): seq[TNetstringNode] =
    ## Retrieves the values of a `TNetstringArray TNetstringNode`.
    ## Returns ``default`` if ``node`` is not a ``TNetstringArray``.
    if node.kind != TNetstringArray: return default
    return node.elems


proc parseTNetstring*( data: string ): TNetstringNode =
    ## Given an encoded tnetstring, parse and return a TNetstringNode.
    var
        length:  int
        kind:    char
        payload: string
        extra:   string

    let sep_pos = data.skipUntil( ':' )
    if sep_pos == data.len:
        raise newException( TNetstringParseError, "Invalid data: No separator token found." )

    try:
        length = data[ 0 .. sep_pos - 1 ].parseInt

        if ($length).len > 9:
            raise newException( TNetstringParseError, "Invalid data: Size more than 9 digits." )

        kind    = data[ sep_pos + length + 1 ]
        payload = data[ sep_pos + 1 .. sep_pos + length ]
        extra   = data[ sep_pos + length + 2 .. ^1 ]

    except ValueError, IndexDefect:
        let msg = getCurrentExceptionMsg()
        raise newException( TNetstringParseError, msg )

    case kind:
        of ',':
            result = newTNetstringString( payload )

        of '#':
            try:
                result = newTNetstringInt( payload.parseBiggestInt )
            except ValueError:
                var msg = getCurrentExceptionMsg()
                raise newException( TNetstringParseError, msg )

        of '^':
            try:
                result = newTNetstringFloat( payload.parseFloat )
            except ValueError:
                var msg = getCurrentExceptionMsg()
                raise newException( TNetstringParseError, msg )

        of '!':
            result = newTNetstringBool( payload == "true" )

        of '~':
            if length != 0:
                raise newException(
                    TNetstringParseError,
                    "Invalid data: Payload must be 0 length for null."
                )
            result = newTNetstringNull()

        of ']':
            result = newTNetstringArray()

            var subnode = parse_tnetstring( payload )
            result.elems.add( subnode )

            while subnode.extra != "":
                subnode = parse_tnetstring( subnode.extra )
                result.elems.add( subnode )

        of '}':
            result = newTNetstringObject()
            var key = parse_tnetstring( payload )

            if ( key.extra == "" ):
                raise newException( TNetstringParseError, "Invalid data: Unbalanced tuple." )
            if ( key.kind != TNetstringString ):
                raise newException( TNetstringParseError, "Invalid data: Object keys must be strings." )

            var value = parse_tnetstring( key.extra )
            result.fields.add( (key: key.str, val: value) )

            while value.extra != "":
                var subkey = parse_tnetstring( value.extra )
                if ( subkey.extra == "" ):
                    raise newException( TNetstringParseError, "Invalid data: Unbalanced tuple." )
                if ( subkey.kind != TNetstringString ):
                    raise newException( TNetstringParseError, "Invalid data: Object keys must be strings." )

                value = parse_tnetstring( subkey.extra )
                result.fields.add( (key: subkey.str, val: value) )

        else:
            let msg =  "Invalid data: Unknown tnetstring type '$1'." % $kind
            raise newException( TNetstringParseError, msg )

    result.extra = extra


iterator items*( node: TNetstringNode ): TNetstringNode =
    ## Iterator for the items of `node`. `node` has to be a TNetstringArray.
    assert node.kind == TNetstringArray
    for i in items( node.elems ):
        yield i


iterator mitems*( node: var TNetstringNode ): var TNetstringNode =
    ## Iterator for the items of `node`. `node` has to be a TNetstringArray. Items can be
    ## modified.
    assert node.kind == TNetstringArray
    for i in mitems( node.elems ):
        yield i


iterator pairs*( node: TNetstringNode ): tuple[ key: string, val: TNetstringNode ] =
    ## Iterator for the child elements of `node`. `node` has to be a TNetstringObject.
    assert node.kind == TNetstringObject
    for key, val in items( node.fields ):
        yield ( key, val )


iterator mpairs*( node: var TNetstringNode ): var tuple[ key: string, val: TNetstringNode ] =
    ## Iterator for the child elements of `node`. `node` has to be a TNetstringObject.
    ## Items can be modified.
    assert node.kind == TNetstringObject
    for keyVal in mitems( node.fields ):
        yield keyVal


func `$`*( node: TNetstringNode ): string =
    ## Delegate stringification of `TNetstringNode` to its underlying object.
    return case node.kind:
    of TNetstringString:
        $node.str
    of TNetstringInt:
        $node.num
    of TNetstringFloat:
        $node.fnum
    of TNetstringBool:
        $node.bval
    of TNetstringNull:
        "(nil)"
    of TNetstringArray:
        $node.elems
    of TNetstringObject:
        $node.fields


func `==`*( a, b: TNetstringNode ): bool =
    ## Check two TNetstring nodes for equality.
    return a.kind == b.kind and $a == $b


func copy*( node: TNetstringNode ): TNetstringNode =
    ## Perform a deep copy of TNetstringNode.
    result = TNetstringNode( kind: node.kind )
    result.extra = node.extra

    case node.kind
    of TNetstringString:
        result.str = node.str
    of TNetstringInt:
        result.num = node.num
    of TNetstringFloat:
        result.fnum = node.fnum
    of TNetstringBool:
        result.bval = node.bval
    of TNetstringNull:
        discard
    of TNetstringArray:
        result.elems = @[]
        for item in items( node ):
            result.elems.add( copy(item) )
    of TNetstringObject:
        result.fields = @[]
        for key, value in items( node.fields ):
            result.fields.add( (key, copy(value)) )


func delete*( node: TNetstringNode, key: string ) =
    ## Deletes ``node[key]`` preserving the order of the other (key, value)-pairs.
    assert( node.kind == TNetstringObject )
    for i in 0..node.fields.len - 1:
        if node.fields[i].key == key:
            node.fields.delete( i )
            return
    raise newException( IndexDefect, "key not in object" )


func hash*( node: TNetstringNode ): Hash =
    ## Compute the hash for a TNetstringString node
    return case node.kind
    of TNetstringString:
        hash( node.str )
    of TNetstringInt:
        hash( node.num )
    of TNetstringFloat:
        hash( node.fnum )
    of TNetstringBool:
        hash( node.bval.int )
    of TNetstringNull:
        hash( 0 )
    of TNetstringArray:
        hash( node.elems )
    of TNetstringObject:
        hash( node.fields )


func len*( node: TNetstringNode ): int =
    ## If `node` is a `TNetstringArray`, it returns the number of elements.
    ## If `node` is a `TNetstringObject`, it returns the number of pairs.
    ## If `node` is a `TNetstringString`, it returns strlen.
    ## Else it returns 0.
    return case node.kind
    of TNetstringString:
        node.str.len
    of TNetstringArray:
        node.elems.len
    of TNetstringObject:
        node.fields.len
    else:
        0


func `[]`*( node: TNetstringNode, name: string ): TNetstringNode =
    ## Gets a field from a `TNetstringNode`, which must not be nil.
    ## If the value at `name` does not exist, returns nil
    assert( not isNil(node) )
    assert( node.kind == TNetstringObject )
    for key, item in node:
        if key == name:
            return item
    return nil


func `[]`*( node: TNetstringNode, index: int ): TNetstringNode =
    ## Gets the node at `index` in an Array. Result is undefined if `index`
    ## is out of bounds.
    assert( not isNil(node) )
    assert( node.kind == TNetstringArray )
    return node.elems[ index ]


func hasKey*( node: TNetstringNode, key: string ): bool =
    ## Checks if `key` exists in `node`.
    assert( node.kind == TNetstringObject )
    for k, item in items( node.fields ):
        if k == key: return true


func add*( parent, child: TNetstringNode ) =
    ## Appends `child` to a TNetstringArray node `parent`.
    assert( parent.kind == TNetstringArray )
    parent.elems.add( child )


func add*( node: TNetstringNode, key: string, val: TNetstringNode ) =
    ## Adds ``(key, val)`` pair to the TNetstringObject `node`.
    ## For speed reasons no check for duplicate keys is performed.
    ## (Note, ``[]=`` performs the check.)
    assert( node.kind == TNetstringObject )
    node.fields.add( (key, val) )


func `[]=`*( node: TNetstringNode, index: int, val: TNetstringNode ) =
    ## Sets an index for a `TNetstringArray`.
    assert( node.kind == TNetstringArray )
    node.elems[ index ] = val


func `[]=`*( node: TNetstringNode, key: string, val: TNetstringNode ) =
    ## Sets a field from a `TNetstringObject`. Performs a check for duplicate keys.
    assert( node.kind == TNetstringObject )
    for i in 0 .. node.fields.len - 1:
        if node.fields[i].key == key:
            node.fields[i].val = val
            return
    node.fields.add( (key, val) )


func dump_tnetstring*( node: TNetstringNode ): string =
    ## Renders a TNetstring `node` as a regular string.
    case node.kind
    of TNetstringString:
        result = $( node.str.len ) & ':' & node.str & ','
    of TNetstringInt:
        let str = $( node.num )
        result = $( str.len ) & ':' & str & '#'
    of TNetstringFloat:
        let str = $( node.fnum )
        result = $( str.len ) & ':' & str & '^'
    of TNetstringBool:
        result = if node.bval: "4:true!" else: "5:false!"
    of TNetstringNull:
        result = "0:~"
    of TNetstringArray:
        result = ""
        for n in node.items:
            result = result & n.dump_tnetstring
        result = $( result.len ) & ':' & result & ']'
    of TNetstringObject:
        result = ""
        for key, val in node.pairs:
            result = result & $( key.len ) & ':' & key & ',' # key
            result = result & val.dump_tnetstring            # val
        result = $( result.len ) & ':' & result & '}'


# Quickie round-tripper.
#
when isMainModule and defined( testing ):
    while true:
        for line in readline( stdin ).split_lines:
            let input = line.strip
            try:
                var tnetstring = parse_tnetstring( input )
                echo "  parsed     --> ", tnetstring
                echo "  serialized --> ", tnetstring.dump_tnetstring, "\n"
            except TNetstringParseError:
                echo input, " --> ", getCurrentExceptionMsg()

