# vim: set et sta sw=4 ts=4 :

import tnetstring

let original = parse_tnetstring( "35:2:hi,8:1:a,1:b,]5:there,8:1:c,1:d,]}" )
let copied = original.copy

# Same values
assert copied == original

# Different instances
assert cast[pointer](original) != cast[pointer](copied)

