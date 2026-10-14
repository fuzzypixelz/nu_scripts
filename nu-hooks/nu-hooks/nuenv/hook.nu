# TODO: use a path -> SHA-256 record?
const NUENV_FILE = ($nu.cache-dir | path join 'nuenv' 'allowed.txt')

def get-allowed []: [ nothing -> list<string> ] {
    if ($NUENV_FILE | path exists) {
        open $NUENV_FILE | lines
    } else {
        []
    }
}

# Load an allowed `.env.nu` in an overlay, and unload it when leaving the
# directory containing it.
#
# # Example
# ```nushell
# use nu-hooks/nuenv/hook.nu [ 'nuenv allow', 'nuenv disallow' ]
# $env.config.hooks.env_change.PWD = (use nu-hooks/nuenv/hook.nu; hook setup)
# ```
export def setup []: [ nothing -> list<record<condition: closure, code: string>> ] {
    # NOTE: the hook order matters as the 1st hook relies on the previous
    # overlays' $NUENV_OVERLAY. And the reason the 1st hooks needs to be
    # separate is that its condition protects its code from failing to parse,
    # while the 2nd hook's condition cannot.
    [
        {
            condition: {|before, after|
                $before != null and $before != $after and (
                    ($before | path join '.env.nu' | path expand) in (overlay list | where active | get name)
                )
            }
            code: 'overlay hide $NUENV_OVERLAY --keep-env [PWD]'
        }
        {
            condition: {||
                if not ('.env.nu' | path exists) {
                    return false
                }

                if (open '.env.nu' | hash sha256) not-in (get-allowed) {
                    # NOTE: throwing an error here makes nushell retry the hook
                    # see https://github.com/nushell/nushell/blob/4b60dee2f6be0b8bbb4db274d472e06f8d9e5681/crates/nu-cmd-base/src/hook.rs#L25-L33
                    warning 'is not allowed; run `nuenv allow` first'
                    return false
                }

                true
            }
            # NOTE: when leaving a .env.nu dir with e.g. cd, $env.PWD is modified
            # in the /path/to/.env.nu overlay, hence the need for `cd $after` when
            # reloading an previously active .env.nu overlay
            code: r#'
                const NUENV_OVERLAY = ('.env.nu' | path expand)
                overlay new --reload $NUENV_OVERLAY
                cd $after
                print $'[(ansi yellow_bold)nu-hooks nuenv(ansi reset)] loading env file (ansi purple).env.nu(ansi reset)'
                source .env.nu
            '#
        }
    ]
}

def _log [msg: string, color: string] {
    print $'[(ansi $color)nu-hooks nuenv(ansi reset)] (ansi purple)('.env.nu' | path expand)(ansi reset) ($msg)'
}

def warning [msg: string] {
    _log $msg 'yellow_bold'
}

def info [msg: string] {
    _log $msg 'green_bold'
}

def check-env-file [] {
    if not ('.env.nu' | path exists) {
        error make --unspanned {
            msg: $'(ansi red_bold)env file not found(ansi reset)',
            help: $'no (ansi yellow).env.nu(ansi reset) in (ansi purple)(pwd)(ansi reset)',
        }
    }
}

# adds `./.env.nu` to the list of allowed 'env' files
export def --env 'nuenv allow' [] {
    check-env-file

    let allowed = get-allowed

    let hash = open '.env.nu' | hash sha256
    if $hash in $allowed {
        warning 'is already allowed'
    } else {
        mkdir ($nu.cache-dir | path join 'nuenv')
        $hash | $in + "\n" out>> $NUENV_FILE
        info 'has been allowed'
    }
    let target = '.env.nu' | path expand

    # NOTE: we reload even if already allowed: contents might've been reverted

    $env.config.hooks.env_change.NUENV_RELOAD = [
        {
            condition: {|_, _| true},
            code: {|_, _|
                # NOTE: nushell clones $env.config.hooks.env_change before evaluating them
                # see https://github.com/nushell/nushell/blob/92165027ce8c5ca7d443c633508b1ba52f6287b5/crates/nu-cli/src/repl.rs#L646
                $env.config.hooks.env_change = $env.config.hooks.env_change
                    | reject --optional NUENV_RELOAD
                hide-env --ignore-errors NUENV_RELOAD
            }
        }
        {
            condition: {|before, after|
                let current = '.env.nu' | path expand
                if not ($current | path exists) {
                    return false
                }
                $current == $target and $current in (overlay list | where active | get name)
            },
            code: 'overlay hide $NUENV_OVERLAY'
        }
        {
            # NOTE: condition cannot always be `true`
            # e.g. `nuenv allow; cd dir-with-unallowed-file-or-no-file`
            condition: {|_, _|
                let current = '.env.nu' | path expand
                if not ($current | path exists) {
                    return false
                }
                $current == $target and (open $current | hash sha256) in (get-allowed)
            },
            code: r#'
                const NUENV_OVERLAY = ('.env.nu' | path expand)
                overlay new --reload $NUENV_OVERLAY
                print $'[(ansi yellow_bold)nu-hooks nuenv(ansi reset)] loading env file (ansi purple).env.nu(ansi reset)'
                source .env.nu
            '#
        }
    ]
    # NOTE: $before is the previously observed $env.NUENV_RELOAD value upon a hook evaluation,
    # since we discard $env.NUENV_RELOAD in each hook evaluation, we need a random value (i.e. no counter)
    # see https://github.com/nushell/nushell/blob/d211796628a2f9d3ebb3953724018dab1e253ee4/crates/nu-cmd-base/src/hook.rs#L19-L20
    $env.NUENV_RELOAD = (random uuid)
}

# removes `./.env.nu` from the list of allowed 'env' files
export def 'nuenv disallow' [] {
    check-env-file

    let allowed = get-allowed

    let hash = open .env.nu | hash sha256
    if $hash not-in $allowed {
        warning 'is already disallowed'
        return
    }

    $allowed | find --invert $hash | to text | save --force $NUENV_FILE
    info 'has been disallowed'

    # TODO: unload?
}
