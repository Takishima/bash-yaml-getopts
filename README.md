# bash-yaml-getopts

This project is aimed at easily generating and customizing command line arguments for Bash scripts using no external tools. The main functionality does require at least Bash 4.x (due to associative array support).

In short, given a YAML file like this:

```yaml
parameters: # Comments are ignored
  build:
    short_option: "B"
    help: Build directory
    type: path # Here as well!
    default: 'build'
  compile-db:
    help: >
    Generate
    compile_commands.json
    type: bool
  source:
    short_option: 'S'
    help: Compile from source
    type: int
```

and a Bash script like this:

```bash
PARAM_YAML_CONFIG="/path/to/config.yaml"
. "/path/to/setup_and_getopts_long.bash"
```

You can generate a Bash script that can produce a help message like this:

```
[INFO ] Reading YAML file: /tmp/test.yaml

Usage:
  ./test.bash [options]

Options:
  -h,--help        Show this help message and exit
  --log-level      Bash logger level
                   Default value: info
                   Values:
                     fatal    Fatal level
                     warn     Warning level
                     info     Informational level
                     debug    Debug level
                     silent   Silent level (ie. disable output)
  -B,--build       Build directory
                   Default value: build
  --compile-db     Generate compile_commands.json
  -S,--source      Compile from source
```

Also, invoking the script with a command line like this:

```bash
./test.bash --no-compile-db -Bbuild --source=10
```

will result in the following values being set:

```bash
LOG_LEVEL=INFO
build=/tmp
source=10
compile_db=0
```

# Usage/API

TODO.

# Limitations

YAML parsing script is only able to read well-formatted YAML files. In addition, it can only read YAML files that have a particular structure:

- Elements with indentation level 0 must not have any inline values
- Elements with indentation level 1 must not have any inline values
- Elements with indentation level 2 must have inline values (multiline strings are supported)
- Elements values on indentation level 2 may not be arrays or arrays of objects
- Elements with indentation level 3 or higher will be ignored with a warning message

The width of an indentation level is not hard-coded, but must be consistent for all items of a given level (e.g. 2 spaces throughout).
