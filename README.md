# README #

### What's this? ###

This module implements a simple TNetstring parser and serializer.
TNetString stands for "tagged netstring" and is a modification of Dan
Bernstein's netstrings specification.  TNetstrings allow for the same
data structures as JSON but in a format that is resistant to buffer
overflows and backward compatible with original netstrings.  They make
no assumptions about string contents, allowing for easy transmission of
ascii and binary data mixed with strongly typed values.

See http://cr.yp.to/proto/netstrings.txt and http://tnetstrings.org/ for
additional information.


### Installation ###

The easiest way to install this module is via the nimble package manager, 
by simply running 'nimble install tnetstring'.

Alternatively, you can fetch the 'tnetstring.nim' file yourself, and put it in a place of your choosing.

### Usage ###

```
#!nimrod
import tnetstring

  let
      tnetstr = "52:4:test,3:1.3^4:key2,4:true!6:things,12:1:1#1:2#1:3#]}"
      tnetobj = parse_tnetstring( tnetstr )

  # tnetobj is now equivalent to the structure:
  # @[(key: test, val: 1.3), (key: key2, val: true), (key: things, val: @[1, 2, 3])]

  assert( tnetobj.kind == TNetstringObject )
  echo tnetobj[ "test" ]
  echo tnetobj[ "key2" ]
  for item in tnetobj[ "things" ]:
      echo item
```

Results in:

```
#!nimrod
  1.3
  true
  1
  2
  3
```

This module can also be used to reasonably create a serialized
TNetstring, suitable for network transmission:

```
#!nimrod
   let
       number  = 1000
       list    = @[ "thing1", "thing2" ]
       tnettop = newTNetstringArray() # top-level array
       tnetsub = newTNetstringArray() # sub array
   
   tnettop.add( newTNetstringInt(number) )
   for item in list:
       tnetsub.add( newTNetstringString(item) )
   tnettop.add( tnetsub )
   
   # Equivalent to: @[1000, @[thing1, thing2]]
   echo dump_tnetstring( tnettop )
```

Results in:

```
#!nimrod
   29:4:1000#18:6:thing1,6:thing2,]]
```