#!/bin/sh

set -ex

DIR=$(dirname $0)
SERVER_SRC=${DIR}/../../examples/rabbitmq-auth-backend-java/src/
JAVA_AMQP_DIR=${DEPS_DIR}/rabbitmq_java_client/
JAVA_AMQP_CLASSES=${JAVA_AMQP_DIR}/target/classes/
CP=${JAVA_AMQP_CLASSES}:${SERVER_SRC}
RUN_CP=${JAVA_AMQP_CLASSES}:${BUILD}

mkdir -p ${BUILD}
javac -cp ${CP} -d ${BUILD} ${SERVER_SRC}/com/rabbitmq/authbackend/*.java
javac -cp ${CP} -d ${BUILD} ${SERVER_SRC}/com/rabbitmq/authbackend/examples/*.java
exec java -cp ${RUN_CP} com.rabbitmq.authbackend.examples.Main ${AMQP_PORT}
