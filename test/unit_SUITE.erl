%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License at
%% http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%% License for the specific language governing rights and limitations
%% under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2017-2020 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(unit_SUITE).

-include_lib("common_test/include/ct.hrl").

-compile(export_all).

all() ->
    [
        {group, non_parallel_tests}
    ].

groups() ->
    [
        {non_parallel_tests, [], [
            table
        ]}
    ].

init_per_group(_, Config) -> Config.
end_per_group(_, Config) -> Config.

table(_Config) ->
    [{<<"action">>,longstr,<<"check_resource">>},
     {<<"username">>,longstr,<<"simon">>},
     {<<"vhost">>,longstr,<<"/">>},
     {<<"resource">>,longstr,<<"queue">>},
     {<<"name">>,longstr,<<"mqtt-subscription-01">>},
     {<<"permission">>,longstr,<<"read">>}] = rabbit_auth_backend_amqp:table(
        [{action,check_resource},
         {username,<<"simon">>},
         {vhost,<<"/">>},
         {resource,queue},
         {name,<<"mqtt-subscription-01">>},
         {permission,read}]
    ),

    [{<<"action">>,longstr,<<"check_topic">>},
     {<<"routing_key">>,longstr,<<"amq.topic">>},
     {<<"variable_map.client_id">>,longstr,<<"TestPublisher">>},
     {<<"variable_map.username">>,longstr,<<"simon">>},
     {<<"variable_map.vhost">>,longstr,<<"/">>}] = rabbit_auth_backend_amqp:table(
       [{action,check_topic},
        {routing_key,<<"amq.topic">>},
        {variable_map,#{<<"client_id">> => <<"TestPublisher">>,
                        <<"username">> => <<"simon">>,
                        <<"vhost">> => <<"/">>}}]),
    ok.