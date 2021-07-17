#! /bin/bash

set -euxo pipefail

fatal() {
	echo "$@" >&2
	exit 1
}

PORT="${PORT:-25565}"

exec 5<>/dev/tcp/127.0.0.1/"$PORT"

# Detect macOS/BSD cat, and try prefixed homebrew versions
if printf '\xff' | cat -v | grep -U -v 'M-'; then
	# shellcheck disable=2015
	command -v gcat >/dev/null 2>&1 \
	&& command -v ggrep >/dev/null 2>&1 \
	|| fatal "This script requires GNU Coreutils cat and GNU grep on macOS."

	# Inverted match to check for failure
	if \
		printf '\xfe\x01' >&5 \
		&& gcat -v <&5 \
		| tee /tmp/healthcheck.txt \
		| ggrep -q -v '^M-\^?' \
	; then
		cat /tmp/healthcheck.txt
		fatal 'Healthcheck failed: Invalid response from server'
	fi
else
	# Inverted match to check for failure
	if \
		printf '\xfe\x01' >&5 \
		&& cat -v <&5 \
		| tee /tmp/healthcheck.txt \
		| grep -q -v '^M-\^?' \
	; then
		fatal 'Healthcheck failed: Invalid response from server'
	fi
fi
