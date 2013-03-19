%%%-------------------------------------------------------------------
%%% File    : genetica_client_sup.erl
%%% Author  : Jean Niklas L'orange <jeannikl@hypirion.com>
%%% Description : 
%%%
%%% Created : 18 Mar 2013 by Jean Niklas L'orange <jeannikl@hypirion.com>
%%%-------------------------------------------------------------------
-module(genetica_client_sup).

-behaviour(supervisor).
%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% External exports
%%--------------------------------------------------------------------
-export([
         start_link/0
        ]).

%%--------------------------------------------------------------------
%% Internal exports
%%--------------------------------------------------------------------
-export([
         init/1,
         start_client/0
        ]).

%%--------------------------------------------------------------------
%% Macros
%%--------------------------------------------------------------------
-define(SERVER, ?MODULE).

%%--------------------------------------------------------------------
%% Records
%%--------------------------------------------------------------------

%%====================================================================
%% External functions
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link/0
%% Description: Starts the supervisor
%%--------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Server functions
%%====================================================================
%%--------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok,  {SupFlags,  [ChildSpec]}} |
%%          ignore                          |
%%          {error, Reason}   
%%--------------------------------------------------------------------
init([]) ->
    SimpleSpec = {single_sup, {genetica_single_sup, start_link, []},
                  permanent, 2000, supervisor, [genetica_single_sup]},
    %%            ^ permanent to be changed to temporary later on,
    {ok, {{one_for_all, 0, 1}, %% Set higher later on. (4, 3600)?
         [SimpleSpec]}}.

%%====================================================================
%% Internal functions
%%====================================================================

%% A startup function for starting new client connection handling computation.
%% To be called by the TCP listener process.
start_client() ->
    supervisor:start_child(genetica_single_sup, []).
