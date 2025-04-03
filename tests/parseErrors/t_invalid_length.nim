
# vim: set et sta sw=4 ts=4 :

import
    std/re
import tnetstring

try:
    discard parse_tnetstring( "what:ever" )
except TNetstringParseError as err:
    assert err.msg.contains( re"""invalid integer: what""" )

