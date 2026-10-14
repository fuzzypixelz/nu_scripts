#!/usr/bin/env python3

import argparse
import os
import pty
import sys

parser = argparse.ArgumentParser()
parser.add_argument('script')
args = parser.parse_args()

pid, fd = pty.fork()

if pid == 0:
    config = '''
        $env.config.hooks.env_change.PWD = (use ../hook.nu 'setup'; setup)
        use ../hook.nu ['nuenv allow']
    '''
    os.execvpe(
        'nu',
        ['nu', '--no-config-file', '--no-history', '-e', config],
        {**os.environ, 'TERM': 'dumb'}
    )

with open(args.script, 'rt') as script:
    for line in script:
        os.write(fd, line.encode())

with os.fdopen(fd, 'rt') as output:
    print(output.read())
    pass

_, status = os.waitpid(pid, 0)
exit_code = os.waitstatus_to_exitcode(status)
sys.exit(exit_code)
