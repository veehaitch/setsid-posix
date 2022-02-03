# setsid-posix

On Linux, the `setsid(1)` command line tool is part of `util-linux`.
This tiny `setsid` implementation should help you out where that package is usually not available
(e.g., on macOS).

Please note that the `--ctty` switch is currently not implemented.

## Usage

```
setsid-posix 0.1.0
Vincent Haupert <mail@vincent-haupert.de>
A POSIX implementation of setsid(1)

USAGE:
    setsid [OPTIONS] <program> [arguments]...

ARGS:
    <program>         The program to run in a new session
    <arguments>...    The arguments to pass to `program`, if any

OPTIONS:
    -c, --ctty       Set the controlling terminal to the current one. Currently not implemented.
    -f, --fork       Always create a new process
    -h, --help       Print help information
    -V, --version    Print version information
    -w, --wait       Wait for the execution of the program to end, and return the exit value of this
                     program as the return value of setsid
```

#### Nix Flakes

##### Run

```ShellSession
nix run github:veehaitch/setsid-posix -- --help
```

##### Overlay

The Flake also provides an overlay for `util-linux` which links `setsid` to `setsid-posix` from this project on non-Linux systems.
On Linux, the overlay has no effect passing through the upstream `util-linux` package from `nixpkgs`.
Additionally, the overlay provides this project explicitly as `setsid-posix`.
