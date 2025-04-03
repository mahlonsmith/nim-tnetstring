# vim: set et sta sw=4 ts=4 :

import tnetstring


let tstr = "308:9:givenName,6:Mahlon,16:departmentNumber,22:Information Technology," &
    "5:title,19:Senior Technologist,13:accountConfig,48:7:vmemail,4:true!7:allpage," &
    "5:false!7:galhide,0:~}13:homeDirectory,14:/home/m/mahlon,3:uid,6:mahlon,9:yubi" &
    "KeyId,12:vvidhghkhehj,5:gecos,12:Mahlon Smith,2:sn,5:Smith,14:employeeNumber,5:12921#}"
let tnet_null = newTNetstringNull()
var tnet_obj = parse_tnetstring( tstr )

# full round trip
assert tstr == tnet_obj.dump_tnetstring

# objects and their defaults

tnet_obj = newTNetstringString( "Hello." )

assert tnet_obj.getStr == "Hello."
assert tnet_null.getStr("nope") == "nope"
assert tnet_null.getStr == ""

tnet_obj = newTNetstringInt( 42 )
assert tnet_obj.getInt == 42
assert tnet_null.getInt == 0
assert tnet_null.getInt(1) == 1

tnet_obj = newTNetstringFloat( 1.0 )
assert tnet_obj.getFloat == 1.0
assert tnet_null.getFloat == 0
assert tnet_null.getFloat(0.1) == 0.1

tnet_obj = newTNetstringObject()
tnet_obj[ "yay" ] = newTNetstringInt( 1 )
assert tnet_obj.getFields[0].val == newTNetstringInt(1)
assert tnet_null.getFields.len == 0

tnet_obj = newTNetstringArray()
tnet_obj.add( newTNetstringInt(1) )
assert tnet_obj.getElems[0] == newTNetstringInt(1)
assert tnet_null.getElems.len == 0

