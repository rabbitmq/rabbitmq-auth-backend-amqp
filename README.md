# Overview

This plugin provides the ability for your RabbitMQ server to perform
authentication (determining who can log in) and authorisation
(determining what permissions they have) by connecting to an
authorisation server over RPC-over-AMQP.

The plugin has been tested against RabbitMQ 3.2.x. It will probably work with other recent versions.

Note: it's at an early stage of development, and could be made rather
more robust.

# Downloading

You can download a pre-built binary of this plugin from
http://www.rabbitmq.com/community-plugins.html.

# Building

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

For `rabbitmq.conf`:

    auth_backends.1 = internal
    auth_backends.2 = amqp

    auth_amqp.username = guest
    auth_amqp.vhost    = /
    auth_amqp.exchange = authentication

For `rabbitmq.config` (prior to 3.7.0) or `advanced.config`:

    [
      {rabbit, [{auth_backends, [rabbit_auth_backend_internal,
                                 rabbit_auth_backend_amqp]}]},
      {rabbitmq_auth_backend_amqp,
       [{username, <<"guest">>},
        {vhost,    <<"/">>},
        {exchange, <<"authentication">>}]}
    ].

Authentication requests will be packed into the headers of incoming
messages. There are three types of request: `login`, `check_vhost` and
`check_resource`. Responses should be returned in the message
body. Responses to `login` requests should be "refused" if login is
unsuccessful or a comma-separated list of tags for the user if login
is successful. Responses to the other types should be the words
"allow" or "deny".

It will probably be a good idea to look at the Java example for more
details.

You can also specify a `timeout` config item. This should be an
integer number of milliseconds to wait for a response from the RPC
server, or `infinity` to wait forever (the default). If the RPC server
does not respond in time, the request for access is denied.

# Example

In `examples/rabbitmq-auth-backend-java` there's a Java based
authentication server framework based around the
`com.rabbitmq.authbackend.AuthBackend` interface with a very trivial
implementation in `com.rabbitmq.authbackend.examples` (which will
authenticate "simon" / "simon").
