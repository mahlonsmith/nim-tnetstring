# vim: set et sta sw=4 ts=4 :

import tnetstring

let tnet_int = parse_tnetstring( "1:1#" )

# equal to itself
assert tnet_int == tnet_int

# equal to another object
assert tnet_int == parse_tnetstring( "1:1#" )

# type equalities
assert parse_tnetstring( "0:~" ) == parse_tnetstring( "0:~" )
assert parse_tnetstring( "3:hi!," ) == parse_tnetstring( "3:hi!," )
assert parse_tnetstring( "3:100#" ) == parse_tnetstring( "3:100#" )
assert parse_tnetstring( "3:1.1^" ) == parse_tnetstring( "3:1.1^" )
assert parse_tnetstring( "4:true!" ) == parse_tnetstring( "4:true!" )
assert parse_tnetstring( "4:true!" ) != parse_tnetstring( "5:false!" )
assert parse_tnetstring( "8:1:1#1:2#]" ) == parse_tnetstring( "8:1:1#1:2#]" )
assert parse_tnetstring( "8:1:1#1:2#]" ) != parse_tnetstring( "8:1:1#1:1#]" )
assert parse_tnetstring( "21:2:hi,1:1#5:there,1:2#}" ) == parse_tnetstring( "21:2:hi,1:1#5:there,1:2#}" )

