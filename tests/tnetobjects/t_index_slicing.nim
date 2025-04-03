# vim: set et sta sw=4 ts=4 :

import tnetstring

let tnet_obj = parse_tnetstring( "20:1:1#1:2#1:3#1:4#1:5#]" )
assert tnet_obj[ 2 ].num == 3

