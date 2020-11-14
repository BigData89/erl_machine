-module(erlmachine_supervisor_prototype).
%% NOTE: The main puprouse of the supervisor is the ability to change monitor layer without affecting business layer of service;
%% NOTE: There are few examples:
%% 1. erlang:monitor/2;
%% 2. supervisor2;
%% 3. mirrored_supervisor;

%% NOTE: Supervisor prototype concerns: health check, recovery management;

%% TODO:
%% a) To simplify context for network transmission;
%% b) To gather statistics into graph;

-export([install/1, install/2, uninstall/1, uninstall/2]).
-export([init/1, start_child/1, terminate_child/1, terminate/1]).

-include("erlmachine_factory.hrl").
-include("erlmachine_assembly.hrl").
-include("erlmachine_system.hrl").

-callback prototype_init(SN::serial_no(), Context::assembly(), Specs::list(map()), Opts::list()) ->
    success(pid()) | failure(term(), term()).

-callback prototype_start_child(SN::serial_no(), Context::assembly(), Spec::map()) ->
    success(pid()) | failure(term(), term()).

-callback prototype_terminate_child(SN::serial_no(), Context::assembly(), Id::term()) ->
    success().

%% Assembly::assembly(), Reason::term()
-callback prototype_terminate(SN::serial_no(), Context::assembly()) ->
    success().

%%%===================================================================
%%%  Assembly API layer
%%%===================================================================

-spec install(Assembly::assembly()) ->
                     success(pid()) | failure(term(), term()).
install(Assembly) ->
    SN = erlmachine_assembly:serial_no(Assembly),
    Prot = erlmachine_assembly:prototype(Assembly),
    Exts = [Ext|| Ext <- erlmachine_assembly:parts(Assembly)],
    Specs = [spec(Assembly, Ext)|| Ext <- Exts],
    Opts = erlmachine_prototype:options(Prot),
    Name = erlmachine_prototype:name(Prot),
    Name:prototype_init(SN, [Assembly, Exts], Specs, Opts).

-spec install(Assembly::assembly(), Ext::assembly()) ->
                     success(pid()) | failure(term(), term()).
install(Assembly, Ext) ->
    SN = erlmachine_assembly:serial_no(Assembly),
    Prot = erlmachine_assembly:prototype(Assembly),
    Spec = spec(Assembly, Ext),
    Name = erlmachine_prototype:name(Prot),
    Name:prototype_start_child(SN, [Assembly, Ext], Spec).

-spec uninstall(Assembly::assembly(), Id::term()) ->
                       failure(term(), term()).
uninstall(Assembly, Id) ->
    SN = erlmachine_assembly:serial_no(Assembly),
    Prot = erlmachine_assembly:prototype(Assembly),
    Name = erlmachine_prototype:name(Prot),
    Name:prototype_terminate_child(SN, [Assembly, Id], Id).

-spec uninstall(Assembly::assembly()) ->
                       success().
uninstall(Assembly) ->
    SN = erlmachine_assembly:serial_no(Assembly),
    Prot = erlmachine_assembly:prototype(Assembly),
    Name = erlmachine_prototype:name(Prot),
    Name:prototype_terminate(SN, Assembly).

%% TODO erlmachine_supervisor:install() will be called from prototype;
-spec spec(Assembly::assembly(), Ext::assembly()) -> Spec::map().
spec(Assembly, Ext) ->
    SN = erlmachine_assembly:serial_no(Assembly),
    Schema = erlmachine_assembly:schema(Assembly),
    Env = erlmachine_assembly:env(Assembly),
    Rel = erlmachine_assembly:schema(erlmachine_assembly:env(Ext, Env), Schema),
    Module = erlmachine_assembly:name(Rel),
    %% TODO Start arguments need to be formed outside;
    Start = {Module, install, [Rel]},

    Type = Module:type(), true = (Type == supervisor orelse Type == worker),
    SN = erlmachine_assembly:serial_no(Rel),
    #{
      id => SN,
      start => Start,
      type => Type
     }.

%%%===================================================================
%%% Prototype API layer
%%%===================================================================

-spec init(Context::term()) -> 
                  success() | failure(term(), term()).
init(Context) ->
    [_Assembly, _Exts] = Context,
    ok.

-spec start_child(Context::term()) -> 
                         success() | failure(term(), term()).
start_child(Context) ->
    [_Assembly, _Ext] = Context,
    ok.

-spec terminate_child(Context::term()) -> 
                             success().
terminate_child(Context) ->
    [_Assembly, _Id] = Context,
    ok.

-spec terminate(Context::term()) ->
                       success().
terminate(Context) ->
    _Assembly = Context,
    ok.

%% TODO https://github.com/rabbitmq/rabbitmq-common/blob/master/src/supervisor2.erl

