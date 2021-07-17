#! /bin/bash

# ENV:
#	HEAP_SIZE (int): Java heap size in MB.
#	XTUNE_VIRTUALIZED (bool): Apply -Xtune:virtualized if truthy.

set -exo pipefail

fatal() {
	echo "$@" >&2
	exit 1
}

if [ ! -d /data ] && [ -n "$IGNORE_MISSING_DATA_DIR" ]; then
	fatal 'Directory /data must exist!'
else
	mkdir -p /data
fi

if [ -z "$HEAP_SIZE" ]; then
	fatal 'HEAP_SIZE must be set!'
fi

HEAP_ARGS=("-Xms${HEAP_SIZE}M" "-Xmx${HEAP_SIZE}M")

if 2>&1 java -version | grep -q 'OpenJ9'; then
	NURSERY_MIN=$((HEAP_SIZE / 2))
	NURSERY_MAX=$((HEAP_SIZE * 4 / 5))

	GC_ARGS=(
		-Xgcpolicy:gencon \
		"-Xmns${NURSERY_MIN}M" \
		"-Xmnx${NURSERY_MAX}M" \
	)
	GC_ARGS+=(
		-Xdisableexplicitgc \
		-Xgc:concurrentScavenge \
		-Xgc:scvNoAdaptiveTenure \
		"-Xgc:dnssExpectedTimeRatioMaximum=3" \
	)

	if [ -n "$XTUNE_VIRTUALIZED" ]; then
		GC_ARGS+=(-Xtune:virtualized)
	fi
else
	GC_ARGS=(
		-XX:+AlwaysPreTouch \
		-XX:+ParallelRefProcEnabled \
		-XX:+UnlockExperimentalVMOptions \
		-XX:+UseG1GC \
	)
	GC_ARGS+=(
		-XX:G1HeapRegionSize=4M \
		-XX:MaxInlineLevel=15 \
	)
fi
exec java "${HEAP_ARGS[@]}" "${GC_ARGS[@]}" -jar /app/velocity.jar
