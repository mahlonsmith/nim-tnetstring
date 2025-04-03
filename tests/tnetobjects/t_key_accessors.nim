# vim: set et sta sw=4 ts=4 :

import tnetstring

let tnet_obj = parse_tnetstring( "11:2:hi,3:yep,}" )

assert $tnet_obj["hi"] == "yep"
assert tnet_obj.has_key( "hi" ) == true
assert tnet_obj.has_key( "nope-not-here" ) == false

