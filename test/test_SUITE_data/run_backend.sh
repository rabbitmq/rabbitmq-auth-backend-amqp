#!/bin/sh

set -ex

DIR=$(cd $(dirname $0) && pwd)

mkdir -p "$DIR/lib"
(
    cd "$DIR"
    mvn dependency:copy-dependencies -DoutputDirectory=lib
)
for file in "$DIR/lib"/*.jar; do
    JAVA_AMQP_CLASSES="$JAVA_AMQP_CLASSES:$file"
done
JAVA_AMQP_CLASSES=${JAVA_AMQP_CLASSES#:}

SERVER_SRC=${DIR}/../../examples/rabbitmq-auth-backend-java/src/
CP=${JAVA_AMQP_CLASSES}:${SERVER_SRC}
RUN_CP=${JAVA_AMQP_CLASSES}:${BUILD}

mkdir -p ${BUILD}
javac -cp ${CP} -d ${BUILD} ${SERVER_SRC}/com/rabbitmq/authbackend/*.java
javac -cp ${CP} -d ${BUILD} ${SERVER_SRC}/com/rabbitmq/authbackend/examples/*.java
exec java -cp ${RUN_CP} com.rabbitmq.authbackend.examples.Main ${AMQP_PORT}
