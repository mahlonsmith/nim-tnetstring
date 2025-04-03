
# vim: set et sta sw=4 ts=4 :

import
    std/re
import tnetstring

try:
    discard parse_tnetstring( "8:1:1#1:1#}" )
except TNetstringParseError as err:
    assert err.msg.contains( re"""Invalid data: Object keys must be strings.""" )

