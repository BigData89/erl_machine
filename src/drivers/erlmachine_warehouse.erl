-module(erlmachine_warehouse).

-folder(<<"erlmachine/warehouse">>).

-steps([]).

-behaviour(gen_server).

%% API.
-export([start_link/0]).

-export([]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-export([assembly/2, assembly/1]).

-include("erlmachine_factory.hrl").
-include("erlmachine_system.hrl").
-include("erlmachine_filesystem.hrl").

%% I guess warehouse is only responsible for storing and retrieving assembly accordingly to predefined capactiy;
%% The responsibility of assembly process needs to be passed to factory;

%% We need to provide broken part issue callback for reason which is oposite to normal;
%% Correct processing of issue will be provided by factory;
%% It's need to be sent to warehouse;
%% It's a not the same like standard unmount;
%% The specialized "crash" callback from factory will be provided;
%% From warehouse perspective are two key's message exist - produced and broken;
%% I am going to store rejected parts on warehouse;
%% We need to provide the specialized callback for this;

 
-record(state, { gearbox::assembly() }).
%% We are going to replace this functionality with load, unload inside assembly module.
%% API.

table() ->
    assembly.

id() -> 
    ?MODULE.

-spec start_link() -> success(pid()) | ingnore | failure(E::term()).
start_link() ->
    ID = id(),
    gen_server:start_link({local, ID}, ?MODULE, [], []).

-spec assembly(SN::serial_no()) -> 
                      success(assembly()) | failure(E::term(), R::term()).
assembly(SN) ->
    read(table(), SN).

-spec store(Assembly::assembly()) -> 
                      success().
store(Assembly) ->
    update(Assembly).

-spec read(Table::atom(), ID::serial_no()) -> 
                  assembly().
read(ID) ->
    Result = mnesia:dirty_read(table(), ID),
    {ok, Result}.

-spec update(Object::assembly()) -> 
                    success().
update(Object) ->
    ok = mnesia:dirty_write(Object).
 
%% gen_server.

init([]) ->
    {ok, #state{ }}.

handle_call(_Request, _From, State) ->
	{reply, ignored, State}.

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.
