-module(walktree_lib).
-compile(export_all).

-record(tnode, {
	  key :: atom(),
	  %% content :: term(),
	  children = [] :: [tnode()]}).

-type tnode() :: #tnode{}.

-spec make_tree() -> [tnode()].
make_tree() ->
    D1 = #tnode{key = d1},
    D2 = #tnode{key = d2},
    D3 = #tnode{key = d3},

    C1 = #tnode{key = c1},
    C2 = #tnode{key = c2},
    C3 = #tnode{key = c3, children = [D1, D2, D3]},
    C4 = #tnode{key = c4},

    B1 = #tnode{key = b1, children = [C1, C2]},
    B2 = #tnode{key = b2},
    B3 = #tnode{key = b3, children = [C3, C4]},

    [#tnode{key = a,
	    children = [B1, B2, B3]}].    

-spec walk_wide([tnode()]) -> ok.
walk_wide([]) ->
    ok;
walk_wide(Nodes) ->
    NextGeneration = 
	lists:foldl(fun(Node, Generation) ->
			    io:format("~p~n", [Node#tnode.key]),
			    Node#tnode.children ++ Generation
		    end, [], Nodes),
    walk_wide(NextGeneration).

-spec walk_heigh(tnode()) -> ok.
walk_heigh(Node) ->
    [walk_heigh(N) || N <- Node#tnode.children],
    io:format("~p~n", [Node#tnode.key]).

-spec walk_heigh_direct(tnode()) -> ok.
walk_heigh_direct(Node) ->
    io:format("~p~n", [Node#tnode.key]),
    [walk_heigh_direct(N) || N <- Node#tnode.children],
    ok.


-spec walk_heigh_concurent(tnode(), direct | opposite) -> ok.
walk_heigh_concurent(Node, direct) ->
    io:format("~p~n", [Node#tnode.key]),
    [spawn(?MODULE, walk_heigh_concurent, [N, direct]) || N <- Node#tnode.children],
    ok;
walk_heigh_concurent(Node, Mode) ->
    [spawn(?MODULE, walk_heigh_concurent, [N, Mode]) || N <- Node#tnode.children],
    io:format("~p~n", [Node#tnode.key]),
    ok.



