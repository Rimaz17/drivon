# ---- Build stage -----------------------------------------------------------
FROM eclipse-temurin:17.0.20_8-jdk-noble AS build
WORKDIR /workspace

# Resolve dependencies in their own layer so source edits don't re-download them.
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw -B -q dependency:go-offline

COPY src/ src/
# Tests and the formatting check run in CI before an image is ever built.
RUN ./mvnw -B -q package -DskipTests -Dspotless.check.skip=true \
 && java -Djarmode=tools -jar target/drivon-api.jar extract --layers --destination extracted

# ---- Runtime stage ---------------------------------------------------------
FROM eclipse-temurin:17.0.20_8-jre-noble
RUN groupadd --system drivon && useradd --system --gid drivon --no-create-home drivon
WORKDIR /app

# Least-frequently-changing layers first for better image layer reuse.
COPY --from=build /workspace/extracted/dependencies/ ./
COPY --from=build /workspace/extracted/spring-boot-loader/ ./
COPY --from=build /workspace/extracted/snapshot-dependencies/ ./
COPY --from=build /workspace/extracted/application/ ./

USER drivon
EXPOSE 8080

# Render's free instance has 512 MB: cap the heap (~300 MB) and leave room for
# metaspace, threads and the OS. Prod profile by default so a misconfigured
# deploy fails fast instead of silently using dev settings.
ENV SPRING_PROFILES_ACTIVE=prod \
    JAVA_OPTS="-XX:MaxRAMPercentage=60 -XX:+UseSerialGC -XX:+ExitOnOutOfMemoryError"

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar drivon-api.jar"]
