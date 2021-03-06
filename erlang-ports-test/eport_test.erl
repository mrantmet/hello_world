-module(eport_test).
-export([start/0, stop/0, f1/1, f2/1, init/1]).

start() ->
    spawn(?MODULE, init, [[]]).
stop() ->
    eport_test!stop.

f1(X) ->
    call_port({f1,X}).
f2(X) ->
    call_port({f2,X}).

call_port(Msg) ->
    eport_test!{call, self(), Msg},
    receive
	{eport_test, Result} ->
	    Result
    end.

init([]) ->
    register(eport_test, self()),
    process_flag(trap_exit, true),
    Port = open_port({spawn, "./cmodule"}, [{packet, 2}]),
    loop(Port).

loop(Port) ->
    receive
	{call, Caller, Msg} ->
	    Port ! {self(), {command, encode(Msg)}},
	    receive
		{Port, {data, Data}} ->
		    Caller ! {eport_test, decode(Data)}
	    end,
	    loop(Port);
	stop ->
	    Port ! {self(), close},
	    receive
		{Port, closed} ->
		    exit(normal) end;
	{'EXIT', Port, _Reason} ->
	    exit(port_terminated)
    end.

encode({f1,X}) ->
    [1,X];
encode({f2,X}) ->
    [2, X].
decode([Int]) ->
    Int.

