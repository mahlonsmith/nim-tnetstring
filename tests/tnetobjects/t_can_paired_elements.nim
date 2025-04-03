# vim: set et sta sw=4 ts=4 :

import tnetstring

let tnet_obj = newTNetstringObject()
tnet_obj.add( "yo", newTNetstringInt(1) )
tnet_obj.add( "yep", newTNetstringInt(2) )

assert tnet_obj["yo"].num == 1
assert tnet_obj["yep"].num == 2
assert tnet_obj.len == 2

tnet_obj[ "more" ] = newTNetstringInt(1)
tnet_obj[ "yo" ] = newTNetstringInt(1) # dup check

assert tnet_obj.len == 3

