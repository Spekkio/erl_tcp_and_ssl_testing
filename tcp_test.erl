-module(tcp_test).
-author('Daniel').

%-export([start/0, loop0/1]).
-compile(export_all).



start() ->
	%% Open porta, PID is stored in LSock
	{ok, LSock} = gen_tcp:listen(6000, [binary, {reuseaddr, true}, {packet, 0}, {active, false}]),
	
    	%io:format("Socket: ~w~n",[LSock]),
	
	%% Can be used to kill process that has the port open.
	%exit(LSock, kill),

        Handler = spawn(?MODULE, handler, [LSock]),
        %Handler = self(),
	_PIDWaiter = spawn(?MODULE, waitForConnection, [Handler, LSock]),  %% Server

    	%io:format("self: ~w~n",[Handler]),
	%io:format("waiter: ~w~n",[PIDWaiter]),
        %handler([]),
        %exit(PIDWaiter, kill),
	[Handler, LSock].

list_clients(Clients) ->
	    io:format("------------- Connected clients ---------------~n"),
	    [io:format("~w~n",[inet:peername(Socket)]) || {client, [{listener, _}, {pid, Socket}]} <- Clients],
	    io:format("-----------------------------------------------~n").   

handler(LSock) ->
    handler([], LSock).
	
handler(Clients, LSock) ->
    receive
	kick_all ->
	    [gen_tcp:close(Socket) || {client, [{listener, _}, {pid, Socket}]} <- Clients],
	    handler([], LSock);

	list ->
	    list_clients(Clients),
	    handler(Clients,LSock);

	{new_client, NewClient} ->
	    %% Printa ut listan med alla klienter.

	    ClientPID = spawn(?MODULE, clientListener, [NewClient, self()]),
	    AllClients = [ {client, [{listener, ClientPID}, {pid, NewClient}]} | Clients ],

	    %list_clients(AllClients),

	    handler(AllClients, LSock);

	next_worker ->
	    handler(Clients, LSock);

	{delete_me, PID, Client} ->
	    %exit(Client, kill),
	    exit(PID, kill),

	    NewList = lists:delete({client, [{listener,PID},{pid,Client}]},Clients),

	    %list_clients(NewList),

	    handler(NewList, LSock);

	{send_packet, PID, Client, Packet} ->
	    NewList = lists:delete({client, [{listener,PID},{pid,Client}]},Clients),
	    [gen_tcp:send(Socket, Packet) || {client, [{listener, _}, {pid, Socket}]} <- NewList],
	    handler(Clients, LSock);
	quit ->
	    [gen_tcp:close(Socket) || {client, [{listener, _}, {pid, Socket}]} <- Clients],
	    gen_tcp:close(LSock);
	_ ->
	    handler(Clients,LSock)
    end.
	
waitForConnection(Server, LSock) ->
    case gen_tcp:accept(LSock) of
	{ok, Client} ->                 %% Client är klientens process PID.
	    io:format("Ny klient: ~w~n",[Client]),

	    case gen_tcp:send(Client,["Hello!\n"]) of
		ok ->
		    Server ! {new_client, Client};
		{error, Reason} ->
		    io:format("Client connection error: ~w~n", [Reason])
	    end,
	    waitForConnection(Server, LSock);

	{error, Reason} ->
	    io:format("Server: ~w~n", [Reason])
	    %waitForConnection(Server, LSock)
    end,
    Server ! quit.


clientListener(Client, Server) ->

    case gen_tcp:recv(Client,1) of
	{ok, Packet} ->
	    Server ! {send_packet, self(), Client, Packet},
	    clientListener(Client, Server);
	{error, Reason} ->
	    io:format("Client ~w: ~s~n",[Client, Reason]),
	    Server ! {delete_me, self(), Client};
    	    %clientListener(Client, Server);
	_ ->
	    Server ! {delete_me, self(), Client}
    	    %clientListener(Client, Server)
    end.
%    receive
%	{what} ->
%	    []
%   end,

