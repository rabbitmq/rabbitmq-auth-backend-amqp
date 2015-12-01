#!/bin/sh

set -e

DIR=$(dirname $0)
SERVER_SRC=${DIR}/../examples/rabbitmq-auth-backend-java/src/
JAVA_AMQP_DIR=${DEPS_DIR}/rabbitmq_java_client/
JAVA_AMQP_CLASSES=${JAVA_AMQP_DIR}/build/classes/
BUILD=${DIR}/build
CP=${JAVA_AMQP_CLASSES}:${SERVER_SRC}
RUN_CP=${JAVA_AMQP_CLASSES}:${BUILD}

${MAKE:-make} -C ${JAVA_AMQP_DIR} all

mkdir -p ${BUILD}
javac -cp ${CP} -d ${BUILD} ${SERVER_SRC}/com/rabbitmq/authbackend/*.java
javac -cp ${CP} -d ${BUILD} ${SERVER_SRC}/com/rabbitmq/authbackend/examples/*.java
java -cp ${RUN_CP} com.rabbitmq.authbackend.examples.Main &
PID=$!
echo PID is $PID
sleep 5
set +e
java -cp ${RUN_CP} com.rabbitmq.authbackend.examples.TestMain
RES=$?
kill ${PID}
set -e
exit ${RES}
