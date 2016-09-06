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
    rabbit_ct_helpers:testcase_started(Config, Testcase),
    start_backend(Config).

end_per_testcase(with_backend = Testcase, Config) ->
    stop_backend(Config),
    rabbit_ct_helpers:testcase_finished(Config, Testcase).

start_backend(Config) ->
    Parent = self(),
    Child = spawn(fun() -> start_backend(Config, Parent) end),
    Config1 = rabbit_ct_helpers:set_config(Config, {backend_pid, Child}),
    wait_for_backend(Config1).

start_backend(Config, Parent) ->
    Script = filename:join([?config(data_dir, Config), "run_backend.sh"]),
    BuildDir = filename:join([?config(priv_dir, Config), "build"]),
    ok = filelib:ensure_dir(filename:join(BuildDir, "dummy")),
    AmqpPort = rabbit_ct_broker_helpers:get_node_config(Config, 0,
      tcp_port_amqp),
    Port = erlang:open_port({spawn_executable, Script}, [
        use_stdio,
        stderr_to_stdout,
        exit_status,
        {env, [
            {"BUILD", BuildDir},
            {"AMQP_PORT", integer_to_list(AmqpPort)}
          ]}]),
    backend_loop(Port, Parent, "").

backend_loop(Port, Parent, Output) ->
    receive
        {Port, {data, Line}} ->
            backend_loop(Port, Parent, Output ++ Line);
        {Port, {exit_status, X}} ->
            print_port_data(Output),
            ct:pal(?LOW_IMPORTANCE, "Backend exited with ~p",
              [integer_to_list(X)]),
            Parent ! {backend_exited, X};
        stop ->
            print_port_data(Output),
            {os_pid, Pid} = erlang:port_info(Port, os_pid),
            ct:pal(?LOW_IMPORTANCE, "Stopping backend (system PID: ~p)...", [Pid]),
            KillCmd = case os:type() of
                {unix, _}  -> ["kill", integer_to_list(Pid)];
                {win32, _} -> ["taskkill", "/PID", integer_to_list(Pid)]
            end,
            rabbit_ct_helpers:exec(KillCmd, []),
            backend_loop(Port, Parent, "")
    after 200 ->
            print_port_data(Output),
            backend_loop(Port, Parent, "")
    end.

print_port_data([])     -> ok;
print_port_data(Output) -> ct:pal(?LOW_IMPORTANCE, "Backend:~n~s", [Output]).

wait_for_backend(Config) ->
    Source = #resource{
      virtual_host = <<"/">>,
      kind = exchange,
      name = <<"authentication">>},
    Bindings = rabbit_ct_broker_helpers:rpc(Config, 0,
      rabbit_binding, list_for_source, [Source]),
    case Bindings of
        [] ->
            receive
                {backend_exited, X} ->
                    Code = integer_to_list(X),
                    exit("Failed to start backend; exited with code " ++ Code)
            after 200 ->
                    wait_for_backend(Config)
            end;
        _ ->
            %% Once there is a queue bound to the `authentication`
            %% exchange, we assume it's the test backend.
            Config
    end.

stop_backend(Config) ->
    Child = ?config(backend_pid, Config),
    Child ! stop,
    receive
        {backend_exited, _} ->
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
