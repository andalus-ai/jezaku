# spatial-trails-places

This project uses Quarkus, the Supersonic Subatomic Java Framework.

If you want to learn more about Quarkus, please visit its website: <https://quarkus.io/>.

## Spatial safety enforcement

Production defaults to `jezaku.spatial.safety.enforced=true`. Configure `JEZAKU_SAFETY_BASE_URL` and grant this service the `spatial:policy-evaluate` service-token scope. The service calls the central Safety API's `POST /safety/spatial/evaluate/batch` endpoint; it does not maintain a local copy of spatial restrictions. Development and test profiles explicitly disable the remote check for isolated demos.

- Creating an anchor evaluates its stored destination coordinate with activity `PUBLISH` before persistence. `ALLOWED` and `CAUTION` are accepted; blocking outcomes return 403.
- Nearby anchors and nearby places evaluate their stored anchor positions/place centers with `DISCOVER`. Restricted, prohibited, and emergency-lockdown results are omitted.
- Place detail evaluates the place center with `DISCOVER`; if denied, the place is returned as not found. Its associated anchors are evaluated with `RENDER` before inclusion.
- Every candidate set is evaluated in one bounded request (maximum 500). Missing, malformed, incomplete, unknown, or unavailable decisions fail closed with 503. Oversized sets require bounded pagination rather than splitting one logical snapshot into unrelated requests.

Trail history currently stores completed stop identifiers and timestamps; it does not own authoritative route geometry or expose a route-preview/navigation API. Therefore this integration does not claim to enforce route-segment safety. Before route guidance is introduced, the route provider must supply validated geometry and the route must be evaluated segment-by-segment (including corridor sampling and policy snapshot consistency), not merely by checking its endpoints. Completed trail history remains personal activity data and is not treated as a live route authorization.

## Running the application in dev mode

You can run your application in dev mode that enables live coding using:

```shell script
./mvnw compile quarkus:dev
```

> **_NOTE:_**  Quarkus now ships with a Dev UI, which is available in dev mode only at <http://localhost:8080/q/dev/>.

## Packaging and running the application

The application can be packaged using:

```shell script
./mvnw package
```

It produces the `quarkus-run.jar` file in the `target/quarkus-app/` directory.
Be aware that it’s not an _über-jar_ as the dependencies are copied into the `target/quarkus-app/lib/` directory.

The application is now runnable using `java -jar target/quarkus-app/quarkus-run.jar`.

If you want to build an _über-jar_, execute the following command:

```shell script
./mvnw package -Dquarkus.package.jar.type=uber-jar
```

The application, packaged as an _über-jar_, is now runnable using `java -jar target/*-runner.jar`.

## Creating a native executable

You can create a native executable using:

```shell script
./mvnw package -Dnative
```

Or, if you don't have GraalVM installed, you can run the native executable build in a container using:

```shell script
./mvnw package -Dnative -Dquarkus.native.container-build=true
```

You can then execute your native executable with: `./target/spatial-trails-places-1.0.0-SNAPSHOT-runner`

If you want to learn more about building native executables, please consult <https://quarkus.io/guides/maven-tooling>.

## Related Guides

- REST ([guide](https://quarkus.io/guides/rest)): Build RESTful web services and APIs using Jakarta REST (formerly JAX-RS)
- REST Jackson ([guide](https://quarkus.io/guides/rest#json-serialisation)): Jackson serialization support for Quarkus REST. This extension is not compatible with the quarkus-resteasy extension, or any of the extensions that depend on it
- SmallRye Health ([guide](https://quarkus.io/guides/smallrye-health)): Monitor service health
- Messaging - Kafka Connector ([guide](https://quarkus.io/guides/kafka-getting-started)): Connect to Kafka with Reactive Messaging
- Reactive PostgreSQL client ([guide](https://quarkus.io/guides/reactive-sql-clients)): Connect to the PostgreSQL database using the reactive pattern

## Provided Code

### Messaging codestart

Use Quarkus Messaging

[Related Apache Kafka guide section...](https://quarkus.io/guides/kafka-reactive-getting-started)


### REST

Easily start your REST Web Services

[Related guide section...](https://quarkus.io/guides/getting-started-reactive#reactive-jax-rs-resources)

### SmallRye Health

Monitor your application's health using SmallRye Health

[Related guide section...](https://quarkus.io/guides/smallrye-health)
