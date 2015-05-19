#
# Copyright (c) 2015, Mahlon E. Smith <mahlon@martini.nu>
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of Mahlon E. Smith nor the names of his
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## This module implements a simple TNetstring parser and serializer.
## TNetString stands for "tagged netstring" and is a modification of Dan
## Bernstein's netstrings specification.  TNetstrings allow for the same data
## structures as JSON but in a format that is resistant to buffer overflows
## and backward compatible with original netstrings.  They make no assumptions
## about string contents, allowing for easy transmission of binary data mixed
## with strongly typed values.

## See http://cr.yp.to/proto/netstrings.txt and http://tnetstrings.org/ for additional information.
##
## This module borrows heavily (in both usage and code) from the nim JSON stdlib
## (json.nim) -- (c) Copyright 2015 Andreas Rumpf, Dominik Picheta.
## 
## Usage example:
##
## .. code-block:: nim
##
##   let
##       tnetstr = "52:4:test,3:1.3^4:key2,4:true!6:things,12:1:1#1:2#1:3#]}"
##       tnetobj = parse_tnetstring( tnetstr )
##
##   # tnetobj is now equivalent to the structure:
##   # @[(key: test, val: 1.3), (key: key2, val: true), (key: things, val: @[1, 2, 3])]
##
##   assert( tnetobj.kind == TNetstringObject )
##   echo tnetobj[ "test" ]
##   echo tnetobj[ "key2" ]
##   for item in tnetobj[ "things" ]:
##       echo item
##   
## Results in:
##
## .. code-block:: nim
##
##   1.3
##   true
##   1
##   2
##   3
##
## This module can also be used to reasonably create a serialized
## TNetstring, suitable for network transmission:
##
## .. code-block:: nim
##    
##    let
##        number  = 1000
##        list    = @[ "thing1", "thing2" ]
##        tnettop = newTNetstringArray() # top-level array
##        tnetsub = newTNetstringArray() # sub array
##    
##    tnettop.add( newTNetstringInt(number) )
##    for item in list:
##        tnetsub.add( newTNetstringString(item) )
##    tnettop.add( tnetsub )
##    
##    # Equivalent to: @[1000, @[thing1, thing2]]
##    echo dump_tnetstring( tnettop )
##
## Results in:
##
## .. code-block:: nim
##    
##    29:4:1000#18:6:thing1,6:thing2,]]
##

import
    hashes,
    parseutils,
    strutils

const version = "0.1.0"

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
      extra: string
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


proc raiseParseErr*( t: TNetstringNode, msg: string ) {.noinline, noreturn.} =
  ## Raises a `TNetstringParseError` exception.
  raise newException( TNetstringParseError, msg )


proc newTNetstringString*( s: string ): TNetstringNode =
    ## Create a new String typed TNetstringNode.
    new( result )
    result.kind = TNetstringString
    result.str = s


proc newTNetstringInt*( i: BiggestInt ): TNetstringNode =
    ## Create a new Integer typed TNetstringNode.
    new( result )
    result.kind = TNetstringInt
    result.num = i


proc newTNetstringFloat*( f: float ): TNetstringNode =
    ## Create a new Float typed TNetstringNode.
    new( result )
    result.kind = TNetstringFloat
    result.fnum = f


proc newTNetstringBool*( b: bool ): TNetstringNode =
    ## Create a new Boolean typed TNetstringNode.
    new( result )
    result.kind = TNetstringBool
    result.bval = b


proc newTNetstringNull*(): TNetstringNode =
    ## Create a new nil typed TNetstringNode.
    new( result )
    result.kind = TNetstringNull


proc newTNetstringObject*(): TNetstringNode =
    ## Create a new Object typed TNetstringNode.
    new( result )
    result.kind = TNetstringObject
    result.fields = @[]


proc newTNetstringArray*(): TNetstringNode =
    ## Create a new Array typed TNetstringNode.
    new( result )
    result.kind = TNetstringArray
    result.elems = @[]


proc parse_tnetstring*( data: string ): TNetstringNode =
    ## Given an encoded tnetstring, parse and return a TNetstringNode.
    var
        length:  int
        kind:    char
        payload: string
        extra:   string

    let sep_pos = data.skipUntil( ':' )
    if sep_pos == data.len: raiseParseErr( result, "Invalid data: No separator token found." )

    try:
        length       = data[ 0 .. sep_pos - 1 ].parseInt
        kind         = data[ sep_pos + length + 1 ]
        payload      = data[ sep_pos + 1 .. sep_pos + length ]
        extra        = data[ sep_pos + length + 2 .. ^1 ]

    except ValueError, IndexError:
        var msg = getCurrentExceptionMsg()
        raiseParseErr( result, msg )

    case kind:
        of ',':
            result = newTNetstringString( payload )

        of '#':
            try:
                result = newTNetstringInt( payload.parseBiggestInt )
            except ValueError:
                var msg = getCurrentExceptionMsg()
                raiseParseErr( result, msg )

        of '^':
            try:
                result = newTNetstringFloat( payload.parseFloat )
            except ValueError:
                var msg = getCurrentExceptionMsg()
                raiseParseErr( result, msg )

        of '!':
            result = newTNetstringBool( payload == "true" )

        of '~':
            if length != 0: raiseParseErr( result, "Invalid data: Payload must be 0 length for null." )
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

            if ( key.extra == "" ): raiseParseErr( result, "Invalid data: Unbalanced tuple." )
            if ( key.kind != TNetstringString ): raiseParseErr( result, "Invalid data: Object keys must be strings." )

            var value = parse_tnetstring( key.extra )
            result.fields.add( (key: key.str, val: value) )

            while value.extra != "":
                var subkey = parse_tnetstring( value.extra )
                if ( subkey.extra == "" ): raiseParseErr( result, "Invalid data: Unbalanced tuple." )
                if ( subkey.kind != TNetstringString ): raiseParseErr( result, "Invalid data: Object keys must be strings." )

                value = parse_tnetstring( subkey.extra )
                result.fields.add( (key: subkey.str, val: value) )

        else:
            raiseParseErr( result, "Invalid data: Unknown tnetstring type '$1'." % $kind )

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


proc `$`*( node: TNetstringNode ): string =
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


proc `==`* ( a, b: TNetstringNode ): bool =
    ## Check two TNetstring nodes for equality.
    if a.isNil:
        if b.isNil: return true
        return false
    elif b.isNil or a.kind != b.kind:
        return false
    else:
        return case a.kind
        of TNetstringString:
            a.str == b.str
        of TNetstringInt:
            a.num == b.num
        of TNetstringFloat:
            a.fnum == b.fnum
        of TNetstringBool:
            a.bval == b.bval
        of TNetstringNull:
            true
        of TNetstringArray:
            a.elems == b.elems
        of TNetstringObject:
            a.fields == b.fields


proc copy*( node: TNetstringNode ): TNetstringNode =
    ## Perform a deep copy of TNetstringNode.
    new( result )
    result.kind  = node.kind
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


proc delete*( node: TNetstringNode, key: string ) =
    ## Deletes ``node[key]`` preserving the order of the other (key, value)-pairs.
    assert( node.kind == TNetstringObject )
    for i in 0..node.fields.len - 1:
        if node.fields[i].key == key:
            node.fields.delete( i )
            return
    raise newException( IndexError, "key not in object" )


proc hash*( node: TNetstringNode ): THash =
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


proc len*( node: TNetstringNode ): int =
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


proc `[]`*( node: TNetstringNode, name: string ): TNetstringNode =
    ## Gets a field from a `TNetstringNode`, which must not be nil.
    ## If the value at `name` does not exist, returns nil
    assert( not isNil(node) )
    assert( node.kind == TNetstringObject )
    for key, item in node:
        if key == name:
            return item
    return nil


proc `[]`*( node: TNetstringNode, index: int ): TNetstringNode =
    ## Gets the node at `index` in an Array. Result is undefined if `index`
    ## is out of bounds.
    assert( not isNil(node) )
    assert( node.kind == TNetstringArray )
    return node.elems[ index ]


proc hasKey*( node: TNetstringNode, key: string ): bool =
    ## Checks if `key` exists in `node`.
    assert( node.kind == TNetstringObject )
    for k, item in items( node.fields ):
        if k == key: return true


proc add*( parent, child: TNetstringNode ) =
    ## Appends `child` to a TNetstringArray node `parent`.
    assert( parent.kind == TNetstringArray )
    parent.elems.add( child )


proc add*( node: TNetstringNode, key: string, val: TNetstringNode ) =
    ## Adds ``(key, val)`` pair to the TNetstringObject `node`.
    ## For speed reasons no check for duplicate keys is performed.
    ## (Note, ``[]=`` performs the check.)
    assert( node.kind == TNetstringObject )
    node.fields.add( (key, val) )


proc `[]=`*( node: TNetstringNode, index: int, val: TNetstringNode ) =
    ## Sets an index for a `TNetstringArray`.
    assert( node.kind == TNetstringArray )
    node.elems[ index ] = val


proc `[]=`*( node: TNetstringNode, key: string, val: TNetstringNode ) =
    ## Sets a field from a `TNetstringObject`. Performs a check for duplicate keys.
    assert( node.kind == TNetstringObject )
    for i in 0 .. node.fields.len - 1:
        if node.fields[i].key == key:
            node.fields[i].val = val
            return
    node.fields.add( (key, val) )


proc dump_tnetstring*( node: TNetstringNode ): string =
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


#
# Tests!
#
when isMainModule:

    # Expected exceptions
    #
    try:
        discard parse_tnetstring( "totally invalid" )
    except TNetstringParseError:
        doAssert( true, "invalid tnetstring" )
    try:
        discard parse_tnetstring( "what:ever" )
    except TNetstringParseError:
        doAssert( true, "bad length" )
    try:
        discard parse_tnetstring( "3:yep~" )
    except TNetstringParseError:
        doAssert( true, "null w/ > 0 length" )
    try:
        discard parse_tnetstring( "8:1:1#1:1#}" )
    except TNetstringParseError:
        doAssert( true, "hash with non-string key" )
    try:
        discard parse_tnetstring( "7:4:test,}" )
    except TNetstringParseError:
        doAssert( true, "hash with odd number of elements" )
    try:
        discard parse_tnetstring( "2:25*" )
    except TNetstringParseError:
        doAssert( true, "unknown netstring tag" )

    # Equality
    #
    let tnet_int = parse_tnetstring( "1:1#" )
    doAssert( tnet_int == tnet_int )
    doAssert( tnet_int == parse_tnetstring( "1:1#" ) )
    doAssert( parse_tnetstring( "0:~" ) == parse_tnetstring( "0:~" ) )

    # Type detection
    #
    doAssert( tnet_int.kind == TNetstringInt )
    doAssert( parse_tnetstring( "1:a," ).kind         == TNetstringString )
    doAssert( parse_tnetstring( "3:1.0^" ).kind       == TNetstringFloat )
    doAssert( parse_tnetstring( "5:false!" ).kind     == TNetstringBool )
    doAssert( parse_tnetstring( "0:~" ).kind          == TNetstringNull )
    doAssert( parse_tnetstring( "9:2:hi,1:1#}" ).kind == TNetstringObject )
    doAssert( parse_tnetstring( "8:1:1#1:2#]" ).kind  == TNetstringArray )

    # Iteration (both array and tuple)
    #
    var
        keys: array[ 2, string ]
        vals: array[ 4, string ]
        k_idx = 0
        idx = 0
    for key, val in parse_tnetstring( "35:2:hi,8:1:a,1:b,]5:there,8:1:c,1:d,]}" ):
        keys[ idx ] = key
        idx = idx + 1
        for item in val:
            vals[ k_idx ] = item.str
            k_idx = k_idx + 1
    doAssert( keys == ["hi","there"] )
    doassert( vals == ["a","b","c","d"] )

    # Deep copies
    #
    var original = parse_tnetstring( "35:2:hi,8:1:a,1:b,]5:there,8:1:c,1:d,]}" )
    var copied   = original.copy
    doAssert( original == copied )
    doAssert( original.repr != copied.repr )
    doAssert( original.fields.pop.val.elems.pop.repr != copied.fields.pop.val.elems.pop.repr )

    # Key deletion
    #
    var tnet_obj = parse_tnetstring( "35:2:hi,8:1:a,1:b,]5:there,8:1:c,1:d,]}" )
    tnet_obj.delete( "hi" )
    doAssert( tnet_obj.fields.len == 1 )

    # Hashing
    #
    doAssert( tnet_int.hash == 1.hash )
    doAssert( parse_tnetstring( "4:true!" ).hash == hash( true.int ) )

    # Length checks.
    #
    tnet_obj = parse_tnetstring( "35:2:hi,8:1:a,1:b,]5:there,8:1:c,1:d,]}" )
    doAssert( parse_tnetstring( "0:~" ).len == 0 )
    doAssert( tnet_obj.len == 2 )
    doAssert( parse_tnetstring( "8:1:1#1:2#]" ).len == 2 )
    doAssert( parse_tnetstring( "5:hallo," ).len == 5 )

    # Index accessors
    #
    tnet_obj = parse_tnetstring( "20:1:1#1:2#1:3#1:4#1:5#]" )
    doAssert( tnet_obj[ 2 ].num == 3 )

    # Key accessors
    #
    tnet_obj = parse_tnetstring( "11:2:hi,3:yep,}" )
    doAssert( $tnet_obj["hi"] == "yep" )
    doAssert( tnet_obj.has_key( "hi" ) == true )
    doAssert( tnet_obj.has_key( "nope-not-here" ) == false )

    # Adding elements to an existing TNetstring array
    #
    var tnet_array = newTNetstringArray()
    for i in 1 .. 10:
        tnet_obj = newTNetstringInt( i )
        tnet_array.add( tnet_obj )
    tnet_array[ 6 ] = newTNetstringString( "yep" )
    doAssert( tnet_array.len == 10 )
    doAssert( tnet_array[ 4 ].num == 5 )
    doAssert( tnet_array[ 6 ].str == "yep" )

    # Adding pairs to an existing TNetstring aobject.
    #
    tnet_obj = newTNetstringObject()
    tnet_obj.add( "yo", newTNetstringInt(1) )
    tnet_obj.add( "yep", newTNetstringInt(2) )
    doAssert( tnet_obj["yo"].num == 1 )
    doAssert( tnet_obj["yep"].num == 2 )
    doAssert( tnet_obj.len == 2 )
    tnet_obj[ "more" ] = newTNetstringInt(1)
    tnet_obj[ "yo" ] = newTNetstringInt(1) # dup check
    doAssert( tnet_obj.len == 3 )

    # Serialization.
    #
    var tstr = "308:9:givenName,6:Mahlon,16:departmentNumber,22:Information Technology," &
        "5:title,19:Senior Technologist,13:accountConfig,48:7:vmemail,4:true!7:allpage," &
        "5:false!7:galhide,0:~}13:homeDirectory,14:/home/m/mahlon,3:uid,6:mahlon,9:yubi" &
        "KeyId,12:vvidhghkhehj,5:gecos,12:Mahlon Smith,2:sn,5:Smith,14:employeeNumber,5:12921#}"
    tnet_obj = parse_tnetstring( tstr )
    doAssert( tstr == tnet_obj.dump_tnetstring )

    echo "* Tests passed!"


    while true and defined( testing ):
        for line in readline( stdin ).split_lines:
            let input = line.strip
            try:
                var tnetstring = parse_tnetstring( input )
                echo "  parsed     --> ", tnetstring
                echo "  serialized --> ", tnetstring.dump_tnetstring, "\n"
            except TNetstringParseError:
                echo input, " --> ", getCurrentExceptionMsg()

