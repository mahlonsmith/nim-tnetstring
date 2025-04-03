
# vim: set et sta sw=4 ts=4 :

import
    std/re
import tnetstring

try:
    discard parse_tnetstring( "1000000000:1" )
except TNetstringParseError as err:
    assert err.msg.contains( re"""Invalid data: Size more than 9 digits.""" )

