# vim: set et sta sw=4 ts=4 :

import tnetstring

let tnet_obj = parse_tnetstring( "35:2:hi,8:1:a,1:b,]5:there,8:1:c,1:d,]}" )

assert parse_tnetstring( "0:~" ).len == 0
assert tnet_obj.len == 2
assert parse_tnetstring( "8:1:1#1:2#]" ).len == 2
assert parse_tnetstring( "5:hallo," ).len == 5

