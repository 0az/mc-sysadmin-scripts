#! /bin/bash

root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd || exit 1 )"

exec rcon-cli --config "$root/rcon-cli.yml"
