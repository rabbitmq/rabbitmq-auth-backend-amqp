%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is VMware, Inc.
%% Copyright (c) 2007-2012 VMware, Inc.  All rights reserved.
%%

-module(test_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-compile(export_all).

all() ->
    [
     {group, non_parallel_tests}
    ].

groups() ->
    [
     {non_parallel_tests, [], [
                               with_backend
                              ]}
    ].

%% -------------------------------------------------------------------
%% Testsuite setup/teardown.
%% -------------------------------------------------------------------
%%
configure_backend(Config) ->
    rabbit_ct_helpers:merge_app_env(Config,
                                    {rabbit, [
                                              {auth_backends,
                                               [rabbit_auth_backend_internal,
                                                rabbit_auth_backend_amqp]}]}).

init_per_suite(Config) ->
    rabbit_ct_helpers:log_environment(),
    Config1 = rabbit_ct_helpers:set_config(Config, [
                                                    {rmq_nodename_suffix, ?MODULE}
                                                   ]),

    rabbit_ct_helpers:run_setup_steps(Config1,
                                      [ fun configure_backend/1 ] ++
                                      rabbit_ct_broker_helpers:setup_steps()).

end_per_suite(Config) ->
    rabbit_ct_helpers:run_teardown_steps(Config,
                                         rabbit_ct_broker_helpers:teardown_steps()).

init_per_group(_, Config) -> Config.

end_per_group(_, Config) -> Config.

init_per_testcase(with_backend = Testcase, Config) ->
    PrivDir = ?config(priv_dir, Config),
    DataDir = ?config(data_dir, Config),
    BuildDir = filename:join([PrivDir, "build"]),
    ok = filelib:ensure_dir(filename:join(BuildDir, "dummy")),
    AmqpPort = rabbit_ct_broker_helpers:get_node_config(Config, 0, tcp_port_amqp),
    Script = filename:join([DataDir, "run_backend.sh"]),
    ct:pal(?LOW_IMPORTANCE, "starting port", []),
    Port = erlang:open_port({spawn, Script}, [use_stdio,
                                              stderr_to_stdout,
                                              exit_status,
                                              {env, [{"BUILD", BuildDir},
                                                     {"AMQP_PORT", integer_to_list(AmqpPort)}
                                                    ]}]),
    Config1 = rabbit_ct_helpers:set_config(Config, {backend_port, Port}),
    wait_for_backend(Config),
    rabbit_ct_helpers:testcase_started(Config1, Testcase).

end_per_testcase(with_backend = Testcase, Config) ->
    Port = ?config(backend_port, Config),
    print_port_data(Port, ""),
    case erlang:port_info(Port, os_pid) of
        {os_pid, OsPid} ->
            ct:pal(?LOW_IMPORTANCE, "backend os pid ~p", [OsPid]),
            KillCmd =
                case os:type() of
                    {unix, _} -> ["kill", integer_to_list(OsPid)];
                    {win32, _} -> ["taskkill", "/PID", integer_to_list(OsPid)]
                end,
            KillRes = rabbit_ct_helpers:exec(KillCmd, []),
            ct:pal(?LOW_IMPORTANCE, "kill: ~p", [KillRes]);
        _ -> ok
    end,
    true = erlang:port_close(Port),
    rabbit_ct_helpers:testcase_finished(Config, Testcase).

print_port_data(Port, Acc) ->
    receive
        {Port, {exit_status, X}} ->
            ct:pal(?LOW_IMPORTANCE, "port exited with ~p", [X]),
            ct:pal(?LOW_IMPORTANCE, "backend: ~s", [Acc]);
        {Port, {data, Out}} ->
            print_port_data(Port, Acc ++ Out)
    after 5000 ->
            ct:pal(?LOW_IMPORTANCE, "backend: ~s", [Acc])
    end.

wait_for_backend(Config) ->
    Source = #resource{
      virtual_host = <<"/">>,
      kind = exchange,
      name = <<"authentication">>},
    Bindings = rabbit_ct_broker_helpers:rpc(Config, 0,
      rabbit_binding, list_for_source, [Source]),
    case Bindings of
        [] ->
            timer:sleep(200),
            wait_for_backend(Config);
        _ ->
            %% Once there is a queue bound to the `authentication`
            %% exchange, we assume it's the test backend.
            ok
    end.

%% -------------------------------------------------------------------
%% Testcases.
%% -------------------------------------------------------------------

with_backend(Config) ->

    AmqpPort = rabbit_ct_broker_helpers:get_node_config(Config, 0, tcp_port_amqp),
    Host = rabbit_ct_helpers:get_config(Config, rmq_hostname),
    {ok, Con} = amqp_connection:start(#amqp_params_network{host = Host,
                                                           port = AmqpPort,
                                                           username = <<"simon">>,
                                                           password = <<"simon">>}),

    ok = amqp_connection:close(Con),

    {error, {auth_failure, _}} =
        amqp_connection:start(#amqp_params_network{host = Host,
                                                   port = AmqpPort,
                                                   username = <<"karl">>,
                                                   password = <<"bananas">>}).
