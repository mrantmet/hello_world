-module(lists_tricks).
-compile(export_all).

append_begin(Element, List) ->
	[Element | List].
append_end(Element, List) ->
	List++[Element].

append([])->
[];
append([H | ListOfLists]) ->
	H++append(ListOfLists).

append_tr(ListOfLists) ->
	append_tr(ListOfLists, []).
append_tr([], Acc) ->
	Acc;
append_tr([H|List], Acc) ->
	append_tr(List, Acc++H).

append_tr_fast(ListOfLists) ->
	append_tr_fast(ListOfLists, []).
append_tr_fast([], Acc) ->
	Acc;
append_tr_fast([H|List],Acc) ->
	append_tr_fast(List, H++Acc).

measure(Fun, Nlists, Nelems) ->
	%% first we should construct list of N lists with Nelems elements each
	Input = construct_list(Nlists, Nelems),
	%% second - to remember current time
	T0 = erlang:monotonic_time(),
	Output = Fun(Input),
	T1 = erlang:monotonic_time(),
	TimeDiff = erlang:convert_time_unit(T1-T0, native, millisecond),
	io:format("Time measured: ~p~n", [TimeDiff]),
	f(Output).

construct_list(0, _) ->
	[];
construct_list(Nlists, Nelems) ->
	[construct(Nelems) | construct_list(Nlists-1, Nelems)].
construct(Nelems) ->
	construct(Nelems, []).
construct(0, List) ->
	List;
construct(Nelems, List) ->
	construct(Nelems - 1, [Nelems | List]).

f(_)->
	ok.
