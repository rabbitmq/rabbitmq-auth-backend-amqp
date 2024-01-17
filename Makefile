PROJECT = rabbitmq_auth_backend_amqp
PROJECT_DESCRIPTION = RabbitMQ AMQP Authentication Backend
PROJECT_MOD = rabbit_auth_backend_amqp_app
RABBITMQ_VERSION ?= v3.12.x

define PROJECT_ENV
[
	    {exchange, <<"authentication">>},
	    {vhost,    <<"/">>},
	    {username, <<"guest">>},
	    {timeout,  infinity}
	  ]
endef

define PROJECT_APP_EXTRA_KEYS
	{broker_version_requirements, ["3.12.0"]}
endef

DEPS = rabbit_common rabbit amqp_client
TEST_DEPS = rabbitmq_ct_helpers rabbitmq_ct_client_helpers

DEP_EARLY_PLUGINS = rabbit_common/mk/rabbitmq-early-plugin.mk
DEP_PLUGINS = rabbit_common/mk/rabbitmq-plugin.mk

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_REPO = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_COMMIT = rabbitmq-tmp

include rabbitmq-components.mk

dep_amqp_client                = git_rmq-subfolder rabbitmq-erlang-client $(RABBITMQ_VERSION)
dep_rabbit_common              = git_rmq-subfolder rabbitmq-common $(RABBITMQ_VERSION)
dep_rabbit                     = git_rmq-subfolder rabbitmq-server $(RABBITMQ_VERSION)
dep_rabbitmq_ct_client_helpers = git_rmq-subfolder rabbitmq-ct-client-helpers $(RABBITMQ_VERSION)
dep_rabbitmq_ct_helpers        = git_rmq-subfolder rabbitmq-ct-helpers $(RABBITMQ_VERSION)
include erlang.mk
