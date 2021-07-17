#! /bin/bash

# ENV:
#	EULA (bool): Agree to the EULA if truthy and not already agreed to.
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
		-XX:+DisableExplicitGC \
		-XX:+ParallelRefProcEnabled \
		-XX:+PerfDisableSharedMem \
		-XX:+UnlockExperimentalVMOptions \
		-XX:+UseG1GC \
	)
	GC_ARGS+=(
		"-XX:G1HeapRegionSize=8M" \
		"-XX:G1HeapWastePercent=5" \
		"-XX:G1MaxNewSizePercent=40" \
		"-XX:G1MixedGCCountTarget=4" \
		"-XX:G1MixedGCLiveThresholdPercent=90" \
		"-XX:G1NewSizePercent=30" \
		"-XX:G1RSetUpdatingPauseTimePercent=5" \
		"-XX:G1ReservePercent=20" \
		"-XX:InitiatingHeapOccupancyPercent=15" \
		"-XX:MaxGCPauseMillis=200" \
		"-XX:MaxTenuringThreshold=1" \
		"-XX:SurvivorRatio=32" \
	)
fi

if [ -n "$EULA" ]; then
	if [ -f /data/eula.txt ]; then
		sed -i s/false/true/ /data/eula.txt
	else
		echo 'eula=true' > /data/eula.txt
	fi
fi

exec java "${HEAP_ARGS[@]}" "${GC_ARGS[@]}" -jar /app/paper.jar nogui
