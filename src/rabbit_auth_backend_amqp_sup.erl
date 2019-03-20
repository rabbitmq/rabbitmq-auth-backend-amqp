%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at https://www.mozilla.org/MPL/
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

-module(rabbit_auth_backend_amqp_sup).

-include_lib("rabbit_common/include/rabbit.hrl").

-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).

%%----------------------------------------------------------------------------

start_link() ->
    supervisor2:start_link(?MODULE, []).

init([]) ->
    {ok, {{one_for_one,3,10},
          [{rabbit_auth_backend_amqp,
            {rabbit_auth_backend_amqp, start_link, []},
            transient, ?WORKER_WAIT, worker, [rabbit_auth_backend_amqp]}]}}.
