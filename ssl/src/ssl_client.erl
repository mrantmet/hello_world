%%%-------------------------------------------------------------------
%%% @author ametr <ametr@ametr-VirtualBox>
%%% @copyright (C) 2017, ametr
%%% @doc
%%%
%%% @end
%%% Created : 15 Aug 2017 by ametr <ametr@ametr-VirtualBox>
%%%-------------------------------------------------------------------
-module(ssl_client).

%% API
-export([talk/0, talk/1]).

%%%===================================================================
%%% API
%%%===================================================================
talk() ->
    talk(9999).
talk(Port) ->
    SockOpts = mk_sock_opts(),
    SslOpts = mk_ssl_opts(),
    io:format("SllOptions = ~p~n",[SslOpts]),
    {ok, Socket} = gen_tcp:connect("localhost", Port, SockOpts),
    {ok, SslSocket} = ssl:connect(Socket, SslOpts, infinity),
    ssl:send(SslSocket, "foo"),
    Data = ssl:recv(SslSocket, 0),
    io:format("Client received data: ~p~n",[Data]),

    {ok, ServerCert} = ssl:peercert(SslSocket),
    ServerCertDecoded = public_key:pkix_decode_cert(ServerCert, otp),
    io:format("Server certificate chain:~n~p~n", [ServerCertDecoded]),
    ssl:close(SslSocket).
    
    

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

%%%===================================================================
%%% Internal functions
%%%===================================================================

mk_sock_opts() ->
    [{active, false}].

mk_ssl_opts() ->
    [{cacertfile, "/home/ametr/erl/ssl/ca_cert/certificate.pem"},
     %%{cacertfile, "/home/ametr/erl/ssl/ca_cert2/certificate2.pem"},
     {verify, verify_peer}].
