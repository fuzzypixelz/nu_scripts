# A collection of helpful commands under the `x` prefix.

# Run all tests under ./tests.
#
# Test files are executed as if they were typed line by line into a Nu REPL.
export def 'x run-tests' [] : [ nothing -> nothing ] {
  # TODO: check that nu --version >= 0.116.1
  # TODO: check that python3 exists
  # TODO: check that $nu.os-info.family == 'unix'

  const cwd = path self | path dirname
  # FIXME: tests still fail leaving $cwd
  mkdir workdir

  for test in (glob 'tests/**/*.nu') {
    let name = $test | path relative-to $cwd
    try {
	  with-env {PWD: 'workdir'} {
	    python3 ../test-driver.py $test
	  }
    } catch {
	  print -e $'(ansi red)KO(ansi reset): ($name)'
      continue
	}
	print $'(ansi green)OK(ansi reset): ($name)'
  }
}
	
