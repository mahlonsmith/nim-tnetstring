
# vim: set et sta sw=4 ts=4 :

import
    std/re
import tnetstring

try:
    discard parse_tnetstring( "2:25*" )
except TNetstringParseError as err:
    assert err.msg.contains( re"""Invalid data: Unknown tnetstring type '\*'.""" )

