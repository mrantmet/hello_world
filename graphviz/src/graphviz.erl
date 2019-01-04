-module(graphviz).
-compile(export_all).

%% API exports
-export([graph_to_graphviz/1]).

%%====================================================================
%% API functions
%%====================================================================

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
-spec graph_to_graphviz(digraph:graph()) -> string().
%%--------------------------------------------------------------------
graph_to_graphviz(G) ->
    Edges = 
	lists:foldl(fun(E, Acc) ->
			    [print_edge(G, E) | Acc]
		    end, [], digraph:edges(G)),
    VerticesAndEdges = 
	lists:foldl(fun(V, Acc) ->
			    [print_node(G, V) | Acc]
		    end, Edges, digraph:vertices(G)),

    "digraph G {\n" ++
	VerticesAndEdges ++
	"}\n".

%%====================================================================
%% Internal functions
%%====================================================================

print_node(G, V) ->
    {_, Opts} = digraph:vertex(G, V),
    VLabel = proplists:get_value("label", Opts),
    OptsString = props_to_attr_string(Opts),
    io_lib:format("~s [~s]~n", [VLabel, OptsString]).
    

print_edge(G, E) ->
    {_, V1, V2, Opts} = digraph:edge(G, E),
    {_, V1Opts} = digraph:vertex(G, V1),
    {_, V2Opts} = digraph:vertex(G, V2),
    V1Label = proplists:get_value("label", V1Opts),
    V2Label = proplists:get_value("label", V2Opts),
    OptString = props_to_attr_string(Opts),
    io_lib:format("~s -> ~s [~s]~n", [V1Label, V2Label, OptString]).

props_to_attr_string(Proplist) ->
    AttrList = 
	[io_lib:format("~s=~s", [K, V]) || {K, V} <- Proplist],
    string:join(AttrList, " ,").
    
mk_test_graph() ->
    G = digraph:new(),
    %% V1 = digraph:add_vertex(G),
    V1 = digraph:add_vertex(G, [{"label", "V1"}, {"color", "blue"}]),
    %% V2 = digraph:add_vertex(G),
    V2 = digraph:add_vertex(G, [{"label", "V2"}, {"color", "green"}]),
    %% E = digraph:add_edge(G, V1, V2),
    digraph:add_edge(G, V1, V2, [{"label","E1"},{"color", "red"}]),
    G.
