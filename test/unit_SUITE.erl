%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
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
