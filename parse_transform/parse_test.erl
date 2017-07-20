-module(parse_test).

-export([parse_transform/2]).

parse_transform(Forms, Options) ->
    io:format("~p~n~p~n",[Forms, Options]),
    Forms.
