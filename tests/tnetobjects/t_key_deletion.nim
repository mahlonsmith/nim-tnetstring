# vim: set et sta sw=4 ts=4 :

import tnetstring

let tnet_obj = parse_tnetstring( "35:2:hi,8:1:a,1:b,]5:there,8:1:c,1:d,]}" )

assert tnet_obj.fields.len == 2
tnet_obj.delete( "hi" )
assert tnet_obj.fields.len == 1

