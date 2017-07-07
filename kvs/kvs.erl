-module(kvs).
-behaviour(gen_server).
-export([store/2, lookup/1]).
-export([stop/0]).
-export([start_link/0, init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

stop() ->
	gen_server:stop(?MODULE).
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
init(_Args) ->
	io:format("kvs started~n",[]),
	{ok, []}.

store(Key, Value) ->
	gen_server:call(?MODULE, {store, Key, Value}).
lookup(Key) ->
	gen_server:call(?MODULE, {lookup, Key}).

handle_call({store, Key, Value}, _From, State) ->
	put(Key, {ok, Value}),
	{reply, {kvs, true}, State};
handle_call({lookup, Key}, _From, State) ->
	case get(Key) of 
		{ok, Value} ->
			{reply, Value, State};
		_ ->
			{reply, undefined_value, State}
	end.

handle_cast(_Msg, State) ->
	{noreply, State}.
handle_info(_Msg, State) ->
	{noreply, State}.
code_change(_OldVsn, State, _Extra) ->
	{ok, State}.
terminate(_Reason, _State) ->
	ok.
