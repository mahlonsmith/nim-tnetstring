# vim: set et sta sw=4 ts=4 :

import tnetstring

let tnet_array = newTNetstringArray()
for i in 1 .. 10:
    let tnet_obj = newTNetstringInt( i )
    tnet_array.add( tnet_obj )
tnet_array[ 6 ] = newTNetstringString( "yep" )

assert tnet_array.len == 10
assert tnet_array[ 4 ].num == 5
assert tnet_array[ 6 ].str == "yep"


