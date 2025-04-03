# vim: set et sta sw=4 ts=4 :

import tnetstring

let tnet_int = parse_tnetstring( "1:1#" )

assert tnet_int.kind == TNetstringInt
assert parse_tnetstring( "1:a," ).kind         == TNetstringString
assert parse_tnetstring( "3:1.0^" ).kind       == TNetstringFloat
assert parse_tnetstring( "5:false!" ).kind     == TNetstringBool
assert parse_tnetstring( "0:~" ).kind          == TNetstringNull
assert parse_tnetstring( "9:2:hi,1:1#}" ).kind == TNetstringObject
assert parse_tnetstring( "8:1:1#1:2#]" ).kind  == TNetstringArray

