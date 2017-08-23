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
%% Copyright (c) 2007-2017 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_auth_backend_amqp).

-include_lib("amqp_client/include/amqp_client.hrl").

-behaviour(rabbit_authn_backend).
-behaviour(rabbit_authz_backend).

-export([description/0]).

-export([user_login_authentication/2, user_login_authorization/1,
         check_vhost_access/3, check_resource_access/3]).

-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {connection, channel, exchange, reply_queue,
                correlation_id = 0, timeout}).

%%--------------------------------------------------------------------

description() ->
    [{name, <<"AMQP">>},
     {description, <<"AMQP authentication / authorisation">>}].

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%--------------------------------------------------------------------

user_login_authentication(Username, AuthProps) ->
    gen_server:call(?SERVER, {login, Username, AuthProps}, infinity).

user_login_authorization(Username) ->
    case user_login_authentication(Username, []) of
        {ok, #auth_user{impl = Impl}} -> {ok, Impl};
        Else                          -> Else
    end.

check_vhost_access(#auth_user{username = Username}, VHost, _Sock) ->
    gen_server:call(?SERVER, {check_vhost, [{username, Username},
                                            {vhost,    VHost}]},
                    infinity).

check_resource_access(#auth_user{username = Username},
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
    {ok, Timeout} = application:get_env(timeout),
    case open(params()) of
        {ok, Conn, Ch} ->
            erlang:monitor(process, Ch),
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
                        reply_queue = Q,
                        timeout     = Timeout}};
        E ->
            {stop, E}
    end.

handle_call({login, Username, AuthProps}, _From, State) ->
    Res = case rpc([{action,   login},
                    {username, Username}] ++ AuthProps, State) of
              <<"refused">>  -> {refused, "Denied by AMQP plugin", []};
              {error, _} = E -> E;
              Resp           -> Tags0 = string:tokens(binary_to_list(Resp),","),
                                Tags = [list_to_atom(T) || T <- Tags0],
                                {ok, #auth_user{username = Username,
                                                tags     = Tags,
                                                impl     = none}}
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

handle_info({'DOWN', _Ref, process, _Ch, Reason}, State) ->
    {stop, {channel_down, Reason}, State};

handle_info(_I, State) ->
    {noreply, State}.

terminate(_, #state{connection = Conn,
                    channel    = Ch}) ->
    ensure_closed(Conn, Ch),
    ok.

code_change(_, State, _) -> {ok, State}.

%%--------------------------------------------------------------------

open(Params) ->
    case amqp_connection:start(Params) of
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

%% TODO don't block while logging in!

rpc(Query, State = #state{channel        = Ch,
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
            await_reply(CId, State)
    end.

await_reply(CId, State = #state{timeout = Timeout}) ->
    receive
        {#'basic.deliver'{},
         #amqp_msg{props = #'P_basic'{correlation_id = CId2},
                   payload = Payload}} ->
            case CId2 of
                CId -> Payload;
                _   -> await_reply(CId, State)
            end
    after Timeout ->
            {error, rpc_timeout}
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
bin(B) when is_binary(B) -> B;
bin(C) when is_list(C) -> list_to_binary(C).

%%--------------------------------------------------------------------

params() ->
    {ok, VHost} = application:get_env(vhost),
    {ok, Username} = application:get_env(username),
    #amqp_params_direct{username     = Username,
                        virtual_host = VHost}.
