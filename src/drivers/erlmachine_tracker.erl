-module(erlmachine_tracker).

-folder(<<"erlmachine/erlmachine_tracker">>).

-input([?MODULE]).

-behaviour(gen_server).

%% API.
-export([start_link/0]).

%% gen_server.
-export([
         init/1, 
         handle_call/3, handle_cast/2, handle_info/2,
         handle_continue/2,
         terminate/2,
         code_change/3,
         format_status/2
        ]).

-export([tracking_no/1, tracking_no/2, trace/2]).

-include("erlmachine_factory.hrl").
-include("erlmachine_system.hrl").

-callback tag(Packakge::term()) -> Tag::binary().

-type serial() :: erlmachine_serial:serial().

-type tracking_no()::binary().

-export_type([tracking_no/0]).

%% API.

id() -> 
    ?MODULE.

-spec start_link() ->
                        success(pid()) | ignore | failure(term()).
start_link() ->
    Id = id(),
    gen_server:start_link({local, Id}, ?MODULE, [], []).

-spec tracking_no(Tracker::atom(), Package::term()) -> 
                         success(tracking_no()) | failure(term(), term()).
tracking_no(Tracker, Package) ->
    Tag = Tracker:tag(Package),
    tracking_no(Tag).

-spec tracking_no(Tag::binary()) -> 
                         success(tracking_no()) | failure(term(), term()).
tracking_no(Tag) when is_binary(Tag) ->
    try 
        TN = tracking_no(),
        erlmachine:success(<<Tag/binary, ".", TN/binary>>)
    catch E:R ->
            erlmachine:failure(E, R)
    end.

-record (tracking_no, {}).

-spec tracking_no() -> tracking_no().
tracking_no() ->
    Id = id(),
    TN = gen_server:call(Id, #tracking_no{}),
    erlmachine_serial_no:base64url(TN).

-record(trace, {tracking_no::binary(), package::map()}).

-spec trace(TrackingNo::binary(), Package::map()) -> 
                   success() | failure(term(), term()).
trace(TrackingNo, Package) ->
    erlang:send(?MODULE, #trace{ tracking_no=TrackingNo, package=Package }).


%% gen_server.

-record(accept, { }).
-record(state, { gearbox::assembly(), serial::serial(), tracking_no::serial_no() }).

init([]) ->
   
    GearBoxModel = gearbox_tracker, 
    GearBoxProt = gearbox_tracker_prototype,
    Env = [],
    GearBox = erlmachine_factory:gearbox(GearBoxModel, GearBoxProt, [], [], [], Env),

    GearMnesiaModel = gear_mnesia,
    Name = trace, Attributes = record_info(fields, trace), Nodes = [node()],
    GearMnesiaOpt = [
                     {name, Name}, 
                     {tabdef, [{attributes, Attributes}, {disc_copies, Nodes}, {record_name, Name}]}
                    ],
    GearMnesia = erlmachine_factory:gear(GearBox, GearMnesiaModel, GearMnesiaOpt),

    AxleModel = axle_tracker,
    AxleProt = axle_tracker_prototype,
    Axle = erlmachine_factory:axle(GearBox, AxleModel, AxleProt, [], [], []),

    BuildAxle = erlmachine_axle:parts(Axle, [GearMnesia]),

    Parts = [
             BuildAxle
            ],

    BuildGearBox = erlmachine_gearbox:parts(GearBox, Parts),

    {ok, _PID} = erlmachine_assembly:install(BuildGearBox),

    {ok, Serial} = erlmachine_serial:tracking_no(),
    TN = erlmachine_serial_no:serial_no(Serial),

    {ok,  #state{ serial=Serial, gearbox=GearBox, tracking_no=TN }, {continue, #accept{}}}.

handle_call(#tracking_no{}, _From, #state{ serial=Serial, tracking_no=TN }=State) ->

    Inc = erlmachine_serial:inc(Serial),

    Rotate = erlmachine_serial_no:serial_no(Inc, TN),
    {reply, TN, State#state{ serial=Inc, tracking_no=Rotate }};

handle_call(_Request, _From, State) ->
    %% We need to provide REST API for management inside transmission
    %% We need to incapsulate transmission management inside callbacks
    %% We need to provide  measurements of transmission loading, etc..
	{reply, ignored, State}.

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(#trace{} = Command, #state{gearbox = _GearBox} = State) ->
    #trace{tracking_no = TrackingNumber, package = Package} = Command,
    %% TODO trace needs to be implemented;
    io:format("~ntrace: ~p~n",[#{TrackingNumber => Package}]),
    %%erlmachine_transmission:rotate(GearBox, #{TrackingNumber => Package}),
    {noreply, State};
handle_info(_Message, State) ->
    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%% We consider Module as implementation point (like class) and serial number as instance - (like object); 
%% We can support polymorphism by different ways - by overriding prototype or by changing topology itself;
handle_continue(#accept{}, #state{gearbox=_GearBox}=State) ->
    try
        %% true = erlmachine_factory:accept(GearBox),
        {noreply, State}
    catch E:R ->
            {stop, {E, R}, State}
    end;
handle_continue(_, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

format_status(_Opt, [_PDict, _State]) ->
    [].


