# Overview

This plugin provides the ability for your RabbitMQ server to perform
authentication (determining who can log in) and authorisation
(determining what permissions they have) by connecting to an
authorisation server over RPC-over-AMQP.

As with all authentication plugins, this one requires rabbitmq-server
2.3.1 or later.

Note: it's at an early stage of development, and could be made rather
more robust.

# Requirements

You can build and install it like any other plugin (see
[the plugin development guide](http://www.rabbitmq.com/plugin-development.html)).

This plugin depends on the Erlang client.

# Enabling the plugin

To enable the plugin, set the value of the `auth_backends` configuration item
for the `rabbit` application to include `rabbit_auth_backend_amqp`.
`auth_backends` is a list of authentication providers to try in order.

Obviously your authentication server cannot vouch for itself, so
you'll need another backend with at least one user in it. You should
probably use the internal database:

    [{rabbit,
      [{auth_backends, [rabbit_auth_backend_internal, rabbit_auth_backend_amqp]}]
     }].

# Configuring the plugin

You need to configure the plugin to know which exchange to publish
authentication requests to.

A minimal configuration file might look like:

    [
      {rabbit, [{auth_backends, [rabbit_auth_backend_internal,
                                 rabbit_auth_backend_amqp]}]},
      {rabbitmq_auth_backend_amqp,
       [{username, <<"guest">>},
        {password, <<"guest">>},
        {vhost,    <<"/">>},
        {exchange, <<"authentication">>}]}
    ].

Authentication requests will be packed into the headers of incoming messages.

# Example

In `examples/rabbitmq-auth-backend-java` there's a Java based
authentication server framework based around the
`com.rabbitmq.authbackend.AuthBackend` interface with a very trivial
implementation in `com.rabbitmq.authbackend.examples` (which will
authenticate "simon" / "simon").