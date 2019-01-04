-module(ptree).
-compile(export_all).

%% API exports
-export([run/1, run/2]).

-type proc_map() :: #{term() => tuple()}.
-type vertex_name() :: pid().
-type content() :: [{show_properties, [proplists:property()]} |
		    {render_properties, [proplists:property()]}].
-type edge_dir() :: forward | back | both.

%%====================================================================
%% API functions
%%====================================================================

%%--------------------------------------------------------------------
-spec run(file:filename()) -> ok.
%%--------------------------------------------------------------------
run(Filename) ->
    make_dot(collect_process_info(), Filename).

%%--------------------------------------------------------------------
-spec run(file:filename(), pid()) -> ok.
%%--------------------------------------------------------------------
run(Filename, TopPid) ->
    PMap = collect_process_info(),
    PMapReduced = maps:with(sets:to_list(get_all_descendents(TopPid, PMap)), PMap),
    make_dot(PMapReduced, Filename),
    make_svg(Filename).

%%--------------------------------------------------------------------
-spec collect_process_info() -> proc_map().
%%--------------------------------------------------------------------
collect_process_info() ->
    lists:foldl(fun(Pid, AccMap) ->
                        maps:put(Pid, process_info(Pid), AccMap)
                end, #{}, processes()).

%%--------------------------------------------------------------------
-spec make_dot(proc_map()) -> string().
%%--------------------------------------------------------------------
make_dot(PMap) ->
    {VertexList, EdgeMap} =
        maps:fold(fun(Pid, ProcInfo, {VAcc, EAcc}) ->
                          NewEdges = 
			      lists:foldl(fun(P, Acc) when is_pid(P) ->
						  case maps:get(P, PMap, undefined) of
						      undefined ->
							  Acc;
						      _ ->
							  [make_edge(Pid, P, both) | Acc]
						  end;
					     (_, Acc) ->
						  Acc				      
					  end, [], proplists:get_value(links, ProcInfo)),
			  %% NewEdges = [make_edge(Pid, P, both) || 
			  %%     P <- proplists:get_value(links, ProcInfo), is_pid(P)],
                          {[make_vertex(Pid, [initial_call, registered_name], ProcInfo) | VAcc],
                           merge_props_to_map(NewEdges, EAcc)}
                  end, {[], #{}}, PMap),

    "digraph G {\n" ++
        lists:foldl(fun({Pid, ShowProps}, Acc) ->
			    VName = pid_to_list(Pid),
                            render_vertex(VName, [VName | ShowProps]) ++ Acc
                    end, "", lists:sort(VertexList)) ++
        maps:fold(fun([P1, P2], Type, Acc) ->
                          render_edge(pid_to_list(P1), pid_to_list(P2), Type, []) ++ Acc
                  end, "", EdgeMap) ++
        "}".

make_svg(Filename) ->
    os:cmd("neato -Tsvg -Goverlap=scale "++ Filename ++ " > " ++ filename:rootname(Filename) ++ ".svg").

%% filters:

%% get all descendents
%% get all supervisors
%% get all workers
%% get all non-supervisers and non-workers

%%--------------------------------------------------------------------
%%
%% This function takes a process pid and proc_map()
%% and attempts to select processes which are direct or
%% indirect descendents of the provided process.
%% Since the process links are bi-directional and don't define 
%% parent - child relationship certain "rules" are applied to
%% figure out this relation
%%
%%--------------------------------------------------------------------
-spec get_all_descendents(pid(), proc_map()) -> sets:set(pid()).
%%--------------------------------------------------------------------
get_all_descendents(Pid, PMap) ->
    Ancestors = sets:new(),
    do_get_all_descendents(Pid, PMap, sets:add_element(Pid, Ancestors)).

do_get_all_descendents(Pid, PMap, Ancestors) ->
    ProcInfo = maps:get(Pid, PMap), %% assume the Pid is always in PMap
    AllLinks = proplists:get_value(links, ProcInfo),    

    case AllLinks -- sets:to_list(Ancestors) of
	[] ->
	    %% if process has no links except links to its ancestors, end the traverse branch
	    Ancestors;
	OtherLinks -> %% links not connecting to ancestors
	    %% lets consider following "types" of processes:
	    %% process - process which is not a supervisor or child of a supervisor
	    %% worker - process which is a child of a supervisor
	    %% supervisor
	    %%
	    %% one of the following conditions required to go to the link:
	    %%
	    %% p | w -> w | s - end traverse branch
	    %% p | w -> p     - continue on next p
	    %% w     -> s     - end traverse branch
	    %% s     -> w | s - continue on all supervisor links (not sure about p)
	    %% s     -> p     - end traverse branch
	    %%
	    %% the logic above is based on the following rules:
	    %% - only supervisor can start another supervisor or worker
	    %% - worker may or may not spawn child processes	   

	    %% first figure out the type of the provided process	       
	    MyType = guess_process_type(Pid, PMap),
	    ForwardLinks =
		if MyType == supervisor orelse 
		   MyType == worker ->
			Dict = proplists:get_value(dictionary, ProcInfo),
			SupTreeAncestors = 
			    [if is_pid(P) -> P; true -> get_pid_by_name(P, PMap) end || 
				P <- proplists:get_value('$ancestors', Dict)],
			OtherLinks -- SupTreeAncestors
		end,
	    %% loop through links	    
	    lists:foldl(fun(NextPid, AncAcc) ->
				ProcType = guess_process_type(NextPid, PMap),
				case {MyType, ProcType} of
				    {process, ProcType} when ProcType == worker orelse 
							     ProcType == supervisor ->
					%% sets:add_element(NextPid, AncAcc);
					AncAcc;
				    {worker, ProcType} when ProcType == worker orelse 
							    ProcType == supervisor ->
					%% sets:add_element(NextPid, AncAcc);
					AncAcc;
				    {supervisor, process} ->
					%% sets:add_element(NextPid, AncAcc);
					AncAcc;
				    %% this should be a stronger condition - if {supervisor, worker} or {supervisor, supervisor} 
				    %% we need to check if child actually belongs to supervisor being processed		
				    %% {supervisor, ProcType} when ProcType == worker orelse
				    %% 				ProcType == supervisor ->
				    %% 	tbd;
				    %% {MyType, process} when MyType == worker orelse
				    %% 			   MyType == process ->
				    %% 	tbd
				    _ -> 
					do_get_all_descendents(NextPid, PMap, sets:add_element(NextPid, AncAcc))
				end
			end, Ancestors, ForwardLinks)
    end.

%%--------------------------------------------------------------------
-spec make_dot(proc_map(), file:filename()) -> ok.
%%--------------------------------------------------------------------
make_dot(PMap, Filename) ->
    file:write_file(Filename, make_dot(PMap)).

%%====================================================================
%% Internal functions
%%====================================================================

%%--------------------------------------------------------------------
-spec make_vertex(vertex_name(), 
		  [proplists:property()], 
		  [erlang:process_info_result_item()]) -> {vertex_name(), content()}.
%%--------------------------------------------------------------------
make_vertex(Name, ShowPropKeys, ProcInfo) ->
    ShowProps = [{PropKey, proplists:get_value(PropKey, ProcInfo)} || 
		    PropKey <- ShowPropKeys -- [initial_call]],
    ShowProps2 =
	case lists:member(initial_call, ShowPropKeys) of
	    true ->
		[{initial_call, get_initial_call(ProcInfo)} | ShowProps];
	    _ ->
		ShowProps
	end,
    
    RenderProps = 
	case is_supervisor(ProcInfo) of
	    true -> [{fillcolor, "\"#706cf8\""}, {style, filled}];
	    _ -> 
		case is_supervisor_child(ProcInfo) of
		    true -> [{fillcolor, "\"#bbffb6\""}, {style, filled}];
		    _ -> []
		end
	end,

    {Name, [{show_properties, ShowProps2},
	    {render_properties, RenderProps}]}.

%%--------------------------------------------------------------------
-spec make_edge(vertex_name(), vertex_name(), edge_dir()) -> 
		       {[vertex_name()], edge_dir()}.
%%--------------------------------------------------------------------
make_edge(V1Name, V2Name, Type) ->
    {lists:sort([V1Name, V2Name]), Type}.

%%--------------------------------------------------------------------
-spec render_vertex(Name :: term(),
		    Properties ::[{term(), term()}]) -> string().
%%--------------------------------------------------------------------
render_vertex(Name, Properties) ->
    ShowProperties = proplists:get_value(show_properties, Properties),
    RenderProperties = proplists:get_value(render_properties, Properties),
    io_lib:format("~p [", [Name]) ++ 
	make_gv_props([{label, make_label([Name | ShowProperties])} | RenderProperties]) 
	++ "];\n".
    %% io_lib:format("\"~s\" [~s];~n", 
    %% 		  [Name, make_gv_props([{label,  make_label(ShowProperties)}])]).

%%--------------------------------------------------------------------
-spec render_edge(V1Name :: term(),
		  V2Name :: term(),
		  Type :: edge_dir(),
		  ShowProperties :: [{term(), term()}]) -> string().
%%--------------------------------------------------------------------
render_edge(V1Name, V2Name, Type, ShowProperties) ->
    io_lib:format("~p -> ~p [", [V1Name, V2Name]) ++ make_gv_props([{label, make_label(ShowProperties)},
                                                  {dir, Type}]) ++ "];\n".
    %% io_lib:format("\"~s\" -> \"~s\" [~s];\n",
    %%               [V1Name, V2Name, make_gv_props([{label, make_label(ShowProperties)},
    %%                                               {dir, Type}])]).

%%--------------------------------------------------------------------
-spec make_gv_props(Properties :: list()) -> string().
%%--------------------------------------------------------------------
make_gv_props(Properties) ->
    make_prop_str(Properties, ", ").

%%--------------------------------------------------------------------
-spec make_show_props(Properties :: list()) -> string().
%%--------------------------------------------------------------------
make_show_props(Properties) ->
    make_prop_str(Properties, "\\n").

%%--------------------------------------------------------------------
%% @doc
%% This function transform list of {K, V} or K properties into a string
%% of form ^(<K>=<V><Sep>)*$
%% @spec 
%% @end
%%--------------------------------------------------------------------
-spec make_prop_str(Properties :: list(), Sep :: string()) -> string().
%%--------------------------------------------------------------------
make_prop_str([], _) ->
    [];
make_prop_str([FirstProp | Properties], Sep) ->
    InitAcc = prop_to_str(FirstProp),
    lists:foldl(fun(Prop, Acc) ->
                        prop_to_str(Prop) ++ Sep ++ Acc
                end, InitAcc, Properties).


%%--------------------------------------------------------------------
-spec prop_to_str(Prop :: term()) -> string().
%%--------------------------------------------------------------------
prop_to_str({K, V}) ->
    case io_lib:deep_char_list(V) of
	true ->	    
	    lists:flatten(io_lib:format("~p=~s",[K, V]));
	false ->
	    lists:flatten(io_lib:format("~p=~p",[K, V]))
    end;
prop_to_str(K) ->
    case io_lib:deep_char_list(K) of
	true ->
	    lists:flatten(io_lib:format("~s",[K]));
	false ->
	    lists:flatten(io_lib:format("~p",[K]))
    end.

make_label(ShowProps) ->
    quote(make_show_props(ShowProps)).

quote(Str) ->
    "\"" ++ Str ++ "\"".

is_supervisor(undefined) ->
    false;
is_supervisor(ProcInfo) ->
    case get_initial_call(ProcInfo) of 
	{supervisor, _, _} ->
	    true;
	_ ->
	    false    
    end.

get_initial_call(ProcInfo) ->
    case proplists:get_value(dictionary, ProcInfo) of
	undefined ->
	    proplists:get_value(initial_call, ProcInfo);
	ProcDict ->
	    case proplists:get_value('$initial_call', ProcDict) of
		undefined ->
		    proplists:get_value(initial_call, ProcInfo);
		MFA ->
		    MFA
	    end
    end.

%% this is an example of graph analysis - this must be reconsidered!
%% it would be good to get process_info only once and then process
%% the data
is_supervisor_child(undefined) ->
    false;
is_supervisor_child(ProcInfo) ->
    case proplists:get_value(dictionary, ProcInfo) of
	undefined ->
	    false;
	ProcDict ->
	    case proplists:get_value('$ancestors', ProcDict) of
		undefined ->
		    false;
		Ancestors ->
		    Results = [case Anc of
				   Pid when is_pid(Pid) ->
				       is_supervisor(process_info(Anc)); %% this and next clause may fail if ancestor is from another node (is that possible?)
				   RegName ->
				       is_supervisor(process_info(whereis(RegName)))
			       end || Anc <- Ancestors],
		    io:format("Results: ~p~n", [Results]),
		    lists:member(true, Results)
	    end
    end.


%%--------------------------------------------------------------------
-spec guess_process_type(pid(), proc_map()) -> supervisor |
					       worker |
					       process.		
%%--------------------------------------------------------------------				   
guess_process_type(Pid, PMap) ->
    ProcInfo = maps:get(Pid, PMap), %% assume the Pid is always in PMap
    case proplists:get_value(dictionary, ProcInfo) of
	undefined ->
	    %% no dictionary, p type
	    process;
	Dict ->
	    case proplists:get_value('$initial_call', Dict) of
		%% undefined -> %% very strange case
		%%     error_logger:error_msg("~p: process ~p has no $initial_call in dictionary:~n~p~n",
		%% 			   [?MODULE, Pid, Dict]),
		%%     {error, Dict};
		{supervisor, _, _} -> %% a supervisor
		    supervisor;
		_ ->
		    %% this is probably a worker, should have supervisors in ancestors
		    MyParents = proplists:get_value('$ancestors', Dict),
		    case proplists:get_value('$ancestors', Dict) of
			undefined ->
			    process;
			MyParents ->
			    case lists:filter(fun IsSup(P) when is_pid(P) ->
						      supervisor == guess_process_type(P, PMap);
						  IsSup(P) when is_atom(P) ->
						      IsSup(get_pid_by_name(P, PMap)) %% whereis shouldn't be used, need to only use proc_map
					      end, MyParents) of
				[] ->
				    process;
				_ ->
				    worker
			    end
		    end
	    end
    end.

%%--------------------------------------------------------------------
-spec get_pid_by_name(atom(), proc_map()) -> pid() | undefined.
%%--------------------------------------------------------------------
get_pid_by_name(Name, PMap) ->
    Iter = maps:iterator(PMap),
    
    HasName = fun(_Pid, ProcInfo) ->
		      case proplists:get_value(registered_name, ProcInfo) of
			  Name ->
			      true;
			  _ ->
			      false
		      end
	      end,
    case first_in_map(HasName, Iter) of
	undefined ->
	    undefined;
	{Pid, _} ->
	    Pid
    end.



%%====================================================================
%% Internal functions abstract
%%====================================================================

%%--------------------------------------------------------------------
-spec merge_props_to_map([{term(), term()}], #{}) -> #{}.
%%--------------------------------------------------------------------
merge_props_to_map(Props, Map) ->
    lists:foldl(fun({K, V}, Acc) ->
			maps:put(K, V, Acc)
		end, Map, Props).


%%--------------------------------------------------------------------
-spec first_in_map(fun((Key :: term(), Value :: term()) -> boolean()), 
		   maps:iterator()) -> 
			  {Key :: term(), Value ::term()} |
			  undefined.
%%--------------------------------------------------------------------
first_in_map(Fun, MapIter) ->
    case maps:next(MapIter) of
	none ->
	    undefined;
	{K, V, NextIter} ->
	    case Fun(K, V) of
		true ->
		    {K, V};
		false ->
		    first_in_map(Fun, NextIter)
	    end
    end.

