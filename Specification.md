---
title: "TNetstrings Specification"
source: "https://tnetstrings.info/"
description: "Spec for typed netstrings."
---

## About Tagged Netstrings

TNetStrings stand for a "tagged netstrings" and are a modification of Dan Bernstein's [netstrings](http://cr.yp.to/proto/netstrings.txt) specification to allow for the same data structures as [JSON](http://www.json.org/) but in a format that meets these requirements:

1. Trivial to parse in every language without making errors.
2. Resistant to buffer overflows and other problems.
3. Fast and low resource intensive.
4. Makes no assumptions about string contents and can store binary data without **escaping** or **encoding** them.
5. Backward compatible with original netstrings.
6. Transport agnostic, so it works with streams, messages, files, anything that's 8-bit clean.

## Grammar

The grammar for the protocol is simply:

```
SIZE    = [0-9]{1,9}
COLON   = ':'
DATA    = (.*)
TYPE    = ('#' | '}' | ']' | ',' | '!' | '~' | '^')
payload = (SIZE COLON DATA TYPE)+
```

Each of these elements is defined as:

`SIZE`

A ascii encoded integer that is no longer than 9 digits long.

`COLON`

A colon character.

`DATA`

A sequence of bytes that is `SIZE` in length. The bytes **can** include any of the `TYPE` characters since the `SIZE` is used to determine the end, not a terminal `TYPE` char.

`TYPE`

A character indicating what type the `DATA` is.

Each `TYPE` is used to determine the contents and maps to:

`,`

string (byte array)

`#`

integer

`^`

float

`!`

boolean of 'true' or 'false'

`~`

null always encoded as 0:~

`}`

Dictionary which you recurse into to fill with key=value pairs inside the payload contents.

`]`

List which you recurse into to fill with values of any type.

## Failure Mode

TNetstrings are all or nothing. Either they parse cleanly and a value is returned, or it aborts and cleans up any in-process data returning nothing. As in the reference implementation below, it's normal to return the remainder of a given buffer for further processing, meaning all of a given buffer does not need to be parsed for a single parsing call to be successful.

Since the `SIZE` can be read before consuming any other data, anyone receiving a message can abort immediately if the data exceeds a limit on the number of bytes.

## Implementation Restrictions

You are not allowed to implement any of the following features:

UTF-8 Strings

String encoding is an application level, political, and display specification. Transport protocols should not have to decode random character encodings accurately to function properly.

Arbitrary Dict Keys

Keys must be **strings** only.

Floats Undefined

Floats are encoded with X.Y format, with no precision, accuracy, or other assurances.

These restrictions exist to make the protocol reliable for anyone who uses it and to act as a constraint on the design to keep it simple.

## Reference Implemenation

You should be able to work with this simple reference implementation written in Python 2.5 or greater (but not 3.x):

```python
# Note this implementation is more strict than necessary to demonstrate
# minimum restrictions on types allowed in dictionaries.

def dump(data):
    if type(data) is long or type(data) is int:
        out = str(data)
        return '%d:%s#' % (len(out), out)
    elif type(data) is float:
        out = '%f' % data
        return '%d:%s^' % (len(out), out)
    elif type(data) is str:
        return '%d:' % len(data) + data + ',' 
    elif type(data) is dict:
        return dump_dict(data)
    elif type(data) is list:
        return dump_list(data)
    elif data == None:
        return '0:~'
    elif type(data) is bool:
        out = repr(data).lower()
        return '%d:%s!' % (len(out), out)
    else:
        assert False, "Can't serialize stuff that's %s." % type(data)

def parse(data):
    payload, payload_type, remain = parse_payload(data)

    if payload_type == '#':
        value = int(payload)
    elif payload_type == '}':
        value = parse_dict(payload)
    elif payload_type == ']':
        value = parse_list(payload)
    elif payload_type == '!':
        value = payload == 'true'
    elif payload_type == '^':
        value = float(payload)
    elif payload_type == '~':
        assert len(payload) == 0, "Payload must be 0 length for null."
        value = None
    elif payload_type == ',':
        value = payload
    else:
        assert False, "Invalid payload type: %r" % payload_type

    return value, remain

def parse_payload(data):
    assert data, "Invalid data to parse, it's empty."
    length, extra = data.split(':', 1)
    length = int(length)

    payload, extra = extra[:length], extra[length:]
    assert extra, "No payload type: %r, %r" % (payload, extra)
    payload_type, remain = extra[0], extra[1:]

    assert len(payload) == length, "Data is wrong length %d vs %d" % (length, len(payload))
    return payload, payload_type, remain

def parse_list(data):
    if len(data) == 0: return []

    result = []
    value, extra = parse(data)
    result.append(value)

    while extra:
        value, extra = parse(extra)
        result.append(value)

    return result

def parse_pair(data):
    key, extra = parse(data)
    assert extra, "Unbalanced dictionary store."
    value, extra = parse(extra)

    return key, value, extra

def parse_dict(data):
    if len(data) == 0: return {}

    key, value, extra = parse_pair(data)
    assert type(key) is str, "Keys can only be strings."

    result = {key: value}

    while extra:
        key, value, extra = parse_pair(extra)
        result[key] = value
  
    return result

def dump_dict(data):
    result = []
    for k,v in data.items():
        result.append(dump(str(k)))
        result.append(dump(v))

    payload = ''.join(result)
    return '%d:' % len(payload) + payload + '}'

def dump_list(data):
    result = []
    for i in data:
        result.append(dump(i))

    payload = ''.join(result)
    return '%d:' % len(payload) + payload + ']'
```


## Conformance

If your implementation does not work with the above Python implementation then it is wrong and is not tnetstrings. It's that simple.

## Streaming

Tnetstrings put the length at the beginning and the type at the end so that you have to read all of the data element and cannot "stream" it. This makes it much easier to handle, since nested data structures need to be loaded into RAM anyway to handle them. It's also unnecessary to allow for streaming, since sockets/files/etc are already streamable. If you need to send 1000 DVDs, don't try to encode them in 1 tnetstring payload, instead send them as a sequence of tnetstrings as payload chunks with checks and headers like most other protocols. In other words: If you think you need to dive into a tnetstring data type to "stream", then you need to remove one layer and flatten it instead.

Here's an example to make this concrete. Many protocols have a simple `HEADER+BODY` design where the `HEADER` is usually some kind of dict, and the body is a raw binary blob of data. Your first idea might be to create one tnetstring of `[{HEADER}, "BODY"]`, but that'd only work if you expect to limit the request sizes. If the requests can be any size then you **actually** should do one of two things:

1. Design the protocol so that it's **always** `HEADER` followed by `BODY`, with no tnetstring wrapping them. Tnetstrings APIs are designed so that you can read, parse, then take the remainder and keep reading, so this is easy. It does limit asynchronous operations.
2. Design the protocol so that messages are a limited size `[{HEADER}, "BODY"]` design, of say 64k, and then let senders use the header to indicate a UUID and a `"SENDMORE"` flag. Usually the first header would indicate the full message size, a checksum, and a first body chunk. Then it sends each new piece with a small header and the original UUID. Finally when it's done it closes it off with a final message. This has the disadvantage of taking up a few more bytes on each message, but has the advantage that you can send multiple streams at once over the same pipe.

Finally, the general rule is senders should have to completely specify the size of what they send and receivers should be ready to reject it. If you allow arbitrary streaming then your servers will suffer attacks that eat your resources.






The contents of this page were copied and maintained by [Michael Granger](ged@deveiate.org), from an old archived copy of Zed A. Shaw's tnetstrings.org site (which has since disappeared). Most of the content contained herein was written by Zed.

