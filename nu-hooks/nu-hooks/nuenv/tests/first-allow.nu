#!/usr/bin/env nu

use std/assert

let tmp = mktemp -d

$'export-env { $env.X = ($env.X? | default 0) + 1 } # (random uuid)' | save ($tmp | path join '.env.nu')

cd $tmp
nuenv allow
assert equal $env.X 1
exit
