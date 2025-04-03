# vim: set et sta sw=4 ts=4 :

import tnetstring

var
    keys: seq[ string ]
    vals: seq[ string ]

for key, val in parse_tnetstring( "35:2:hi,8:1:a,1:b,]5:there,8:1:c,1:d,]}" ):
    keys.add( key )

    for item in val:
        vals.add( item.str )

assert keys == @["hi","there"]
assert vals == @["a","b","c","d"]


