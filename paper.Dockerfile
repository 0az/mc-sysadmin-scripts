ARG BUILDER_TAG=buster-20210511-slim
ARG MINECRAFT_VERSION=1.16.5
ARG PAPER_BUILD=669
ARG PAPER_NAME=paper-1.16.5-669.jar
ARG PAPER_SHA=6ca104b39feed5542cfceb9c39f78ca8a1297f5d19e8a11369487f7a1066b26e
ARG ARTIFACT_IMAGE=adoptopenjdk/openjdk16:jre-16.0.1_9-debianslim
ARG BUILD_IMAGE=adoptopenjdk/openjdk16:jdk-16.0.1_9-debianslim

FROM ${BUILD_IMAGE} as build

ARG MINECRAFT_VERSION
ARG PAPER_BUILD
ARG PAPER_NAME
ARG PAPER_SHA

WORKDIR /app

RUN \
	echo "${PAPER_SHA} /app/paper.jar" > /tmp/checksum.txt \
	&& echo \
	https://papermc.io/api/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${PAPER_BUILD}/downloads/${PAPER_NAME} >&2 \
	&& curl \
	-L --fail \
	-H 'Accept: application/java-archive' \
	https://papermc.io/api/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${PAPER_BUILD}/downloads/${PAPER_NAME} \
	-o /app/paper.jar \
	&& sha256sum /tmp/checksum.txt \
	&& rm -f /tmp/checksum.txt \
	&& true

COPY HealthcheckClient.java /app/HealthcheckClient.java
RUN \
	javac -d /app HealthcheckClient.java

FROM ${ARTIFACT_IMAGE} as artifact

VOLUME /data
WORKDIR /data

RUN mkdir /app
COPY --from=build /app/paper.jar /app/paper.jar
COPY --from=build /app/HealthcheckClient.class /app/HealthcheckClient.class
COPY start-paper.sh /app/start-paper.sh

CMD [ "bash", "/app/start-paper.sh" ]

HEALTHCHECK \
	--interval=15s \
	--timeout=1s \
	--start-period=3m \
	--retries=5 \
	CMD \
	[ "java", "-cp", "/app", "HealthcheckClient" ]
