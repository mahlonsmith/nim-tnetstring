version     = "0.2.0"
author      = "Mahlon E. Smith"
description = "Parsing and serialization for the TNetstring format."
license     = "BSD-3-Clause"
srcDir      = "src"

requires "nim ^= 2.0.0"

task test, "Run the test suite.":
    exec "testament all"
    exec "testament html"

task clean, "Remove all non-repository artifacts.":
    exec "fossil clean -x"

task docs, "Generate automated documentation.":
    exec "nim doc --project --outdir:docs src/tnetstring.nim"

