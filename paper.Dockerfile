ARG MINECRAFT_VERSION=1.18.1
ARG PAPER_BUILD=108
ARG PAPER_NAME=paper-${MINECRAFT_VERSION}-${PAPER_BUILD}.jar
ARG PAPER_SHA=685bc76293c6f5bc352e3f5ab8bfad91b3744b0a0131cc69a15f9c78f9694532

ARG ARTIFACT_IMAGE=eclipse-temurin:17-alpine
ARG BUILD_IMAGE=eclipse-temurin:17-alpine

FROM ${BUILD_IMAGE} as build

ARG MINECRAFT_VERSION
ARG PAPER_BUILD
ARG PAPER_NAME
ARG PAPER_SHA

WORKDIR /app

RUN \
	echo "${PAPER_SHA} /app/paper.jar" > /tmp/checksum.txt \
	&& apk add --no-cache curl \
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

RUN \
	mkdir /app \
	&& apk add --no-cache bash \
;
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
