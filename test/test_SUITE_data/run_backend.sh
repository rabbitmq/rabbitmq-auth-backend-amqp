#!/bin/sh

set -ex

DIR=$(cd $(dirname $0) && pwd)

EXAMPLE_DIRECTORY=${DIR}/../../examples/rabbitmq-auth-backend-java

cd $EXAMPLE_DIRECTORY
exec ./mvnw compile exec:java -Dexec.args="${AMQP_PORT}"