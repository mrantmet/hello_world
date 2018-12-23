%%%-------------------------------------------------------------------
%% @doc walktree public API
%% @end
%%%-------------------------------------------------------------------

-module(walktree_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) ->
    walktree_sup:start_link().

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================