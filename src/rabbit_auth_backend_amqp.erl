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
%% The Original Code is RabbitMQ AMQP authentication.
%%
%% The Initial Developer of the Original Code is VMware, Inc.
%% Copyright (c) 2007-2011 VMware, Inc.  All rights reserved.
%%

-module(rabbit_auth_backend_amqp).

-include_lib("amqp_client/include/amqp_client.hrl").
-behaviour(rabbit_auth_backend).
-include_lib("rabbit_common/include/rabbit_auth_backend_spec.hrl").

-export([description/0]).
-export([check_user_login/2, check_vhost_access/3, check_resource_access/3]).

-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {connection, channel, exchange, reply_queue,
                correlation_id = 0}).

%%--------------------------------------------------------------------

description() ->
    [{name, <<"AMQP">>},
     {description, <<"AMQP authentication / authorisation">>}].

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%--------------------------------------------------------------------

check_user_login(Username, []) ->
    gen_server:call(?SERVER, {login, Username}, infinity);

check_user_login(Username, [{password, Password}]) ->
    gen_server:call(?SERVER, {login, Username, Password}, infinity);

check_user_login(Username, AuthProps) ->
    exit({unknown_auth_props, Username, AuthProps}).

check_vhost_access(#user{username = Username}, VHost, Permission) ->
    gen_server:call(?SERVER, {check_vhost, [{username,   Username},
                                            {vhost,      VHost},
                                            {permission, Permission}]},
                    infinity).

check_resource_access(#user{username = Username},
                      #resource{virtual_host = VHost, kind = Type, name = Name},
                      Permission) ->
    gen_server:call(?SERVER, {check_resource, [{username,   Username},
                                               {vhost,      VHost},
                                               {resource,   Type},
                                               {name,       Name},
                                               {permission, Permission}]},
                    infinity).

%%--------------------------------------------------------------------

init([]) ->
    {ok, X} = application:get_env(exchange),
    case open(direct, params()) of
        {ok, Conn, Ch} ->
            #'confirm.select_ok'{} =
                amqp_channel:call(Ch, #'confirm.select'{}),
            amqp_channel:register_confirm_handler(Ch, self()),
            amqp_channel:register_return_handler(Ch, self()),
            #'exchange.declare_ok'{} =
                amqp_channel:call(
                  Ch, #'exchange.declare'{exchange = X,
                                          type     = <<"fanout">>}),
            #'queue.declare_ok'{queue = Q} =
                amqp_channel:call(Ch, #'queue.declare'{exclusive = true}),
            #'basic.consume_ok'{} =
                amqp_channel:subscribe(Ch, #'basic.consume'{queue  = Q,
                                                            no_ack = true},
                                       self()),
            {ok, #state{connection  = Conn,
                        channel     = Ch,
                        exchange    = X,
                        reply_queue = Q}};
        E ->
            {stop, E}
    end.

%%handle_call({login, Username}, _From, State) ->
%%    with_ldap(fun(LDAP) -> do_login(Username, LDAP, State) end, State);

handle_call({login, Username, Password}, _From, State) ->
    Res = case rpc([{action,   login},
                    {username, Username},
                    {password, Password}], State) of
              <<"refused">>  -> {refused, "Denied by AMQP plugin", []};
              {error, _} = E -> E;
              Resp           -> {ok, #user{username     = Username,
                                           is_admin     = Resp =:= <<"admin">>,
                                           auth_backend = ?MODULE,
                                           impl         = none}}
          end,
    {reply, Res, incr(State)};

handle_call({check_vhost, Args}, _From, State) ->
    {reply, bool_rpc([{action, check_vhost} | Args], State), State};

handle_call({check_resource, Args}, _From, State) ->
    {reply, bool_rpc([{action, check_resource} | Args], State), State};

handle_call(_Req, _From, State) ->
    {reply, unknown_request, State}.

handle_cast(_C, State) ->
    {noreply, State}.

handle_info(_I, State) ->
    {noreply, State}.

terminate(_, _) -> ok.

code_change(_, State, _) -> {ok, State}.

%%--------------------------------------------------------------------

open(Type, Params) ->
    case amqp_connection:start(Type, Params) of
        {ok, Conn} -> case amqp_connection:open_channel(Conn) of
                          {ok, Ch} -> erlang:monitor(process, Ch),
                                      {ok, Conn, Ch};
                          E        -> catch amqp_connection:close(Conn),
                                      E
                      end;
        E -> E
    end.

ensure_closed(Conn, Ch) ->
    ensure_closed(Ch),
    catch amqp_connection:close(Conn).

ensure_closed(Ch) ->
    catch amqp_channel:close(Ch).

%%--------------------------------------------------------------------

rpc(Query, #state{channel        = Ch,
                  reply_queue    = Q,
                  exchange       = X,
                  correlation_id = Id}) ->
    CId = list_to_binary(integer_to_list(Id)),
    Props = #'P_basic'{headers        = table(Query),
                       reply_to       = Q,
                       correlation_id = CId},
    amqp_channel:cast(Ch, #'basic.publish'{exchange    = X,
                                           routing_key = <<>>,
                                           mandatory   = true},
                      #amqp_msg{props   = Props,
                                payload = <<>>}),
    receive
        {#'basic.return'{}, _} ->
            receive
                #'basic.ack'{} -> ok
            end,
            {error, rpc_server_not_listening};
        #'basic.ack'{} ->
            receive
                {#'basic.deliver'{},
                 #amqp_msg{props = #'P_basic'{correlation_id = CId},
                           payload = Payload}} ->
                    Payload
            end
    end.

bool_rpc(Query, State) ->
    case rpc(Query, State) of
        <<"allow">>    -> true;
        <<"deny">>     -> false;
        {error, _} = E -> E
    end.

incr(State = #state{correlation_id = Id}) ->
    State#state{correlation_id = Id + 1}.

table(Query) ->
    [table_row(Row) || Row <- Query].

table_row({K, V}) ->
    {bin(K), longstr, bin(V)}.

bin(A) when is_atom(A)   -> list_to_binary(atom_to_list(A));
bin(B) when is_binary(B) -> B.

%%--------------------------------------------------------------------

params() ->
    {ok, VHost} = application:get_env(vhost),
    {ok, Username} = application:get_env(username),
    {ok, Password} = application:get_env(password),
    #amqp_params{username     = Username,
                 password     = Password,
                 virtual_host = VHost}.
