# vim: set et sta sw=4 ts=4 :

import
    std/hashes
import tnetstring

# Hashes to the underlying object type.

let tnet_int = parse_tnetstring( "1:1#" )

assert tnet_int.hash == 1.hash
assert parse_tnetstring( "4:true!" ).hash == hash( true.int )

