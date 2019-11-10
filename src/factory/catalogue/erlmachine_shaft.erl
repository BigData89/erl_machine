-module(erlmachine_shaft).

-export([
         install/2,
         attach/3, detach/3,
         replace/3,
         transmit/3, rotate/4, rotate/3,
         accept/3,
         overload/3, block/4,
         uninstall/3
        ]).

-export([
         shaft/1,
         body/1, body/2
        ]).

-include("erlmachine_factory.hrl").
-include("erlmachine_system.hrl").

-callback install(SN::serial_no(), IDs::list(serial_no()), Body::term(), Options::term(), Env::list()) -> 
    success(term()) | failure(term(), term(), term()) | failure(term()).

-callback replace(SN::serial_no(), ID::serial_no(), Body::term()) -> 
    success(term()) | failure(term(), term(), term()) | failure(term()).

-callback uninstall(SN::serial_no(), Reason::term(), Body::term()) -> 
    success(term()) | failure(term(), term(), term()) | failure(term()).

-callback accept(SN::serial_no(), Criteria::term(), Body::term()) -> 
    success(term(), term()) | failure(term(), term(), term()) | failure(term()).

-callback attach(SN::serial_no(), ID::serial_no(), Body::term()) -> 
    success(term()) | failure(term(), term(), term()) | failure(term()).

-callback detach(SN::serial_no(), ID::serial_no(), Body::term()) -> 
    success(term()) | failure(term(), term(), term()) | failure(term()).

-callback rotate(SN::serial_no(), ID::serial_no(), Motion::term(), Body::term()) -> 
    success(term(), term()) | success(term()) | failure(term(), term(), term()) | failure(term()).

-callback transmit(SN::serial_no(), Motion::term(), Body::term()) -> 
    success(term(), term()) | failure(term(), term(), term()) | failure(term()).

-callback overload(SN::serial_no(), Load::term(), Body::term()) -> 
    success(term()) | failure(term(), term(), term()) | failure(term()).

-callback block(SN::serial_no(), ID::serial_no(), Failure::term(), Body::term()) -> 
    success(term()) | failure(term(), term(), term()) | failure(term()).

%% Instead of gear the main puropse of shaft is to transmit power between parts;

-record(shaft, {body::term()}).

-type shaft() :: #shaft{}.

-export_type([shaft/0]).

-spec shaft(Body::term()) -> shaft().
shaft(Body) ->
    #shaft{body=Body}.

-spec install(GearBox::assembly(), Shaft::assembly()) -> 
                     success(Release::assembly()) | failure(E::term(), R::term(), Rejected::assembly()).
install(GearBox, Shaft) ->
    ModelName = erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft),
    Env = erlmachine_gearbox:env(GearBox), 
    Options = erlmachine_assembly:model_options(Shaft),
    %% We can check exported functions accordingly to this kind of behaviour; 
    %% We are going to add error handling later; 
    IDs = [erlmachine_assembly:serial_no(Part)|| Part <- erlmachine_assembly:parts(Shaft)], 
    {ok, Body} = ModelName:install(SN, IDs, body(Shaft), Options, Env),
    %% We are going to add error handling later; 
    Release = body(Shaft, Body), 
    Mounted = erlmachine_assembly:mounted(Shaft),
    (Mounted /= undefined) andalso (erlmachine_assembly:prototype_name(Mounted)):installed(SN, Mounted, Release),
    (Mounted == GearBox) orelse (erlmachine_assembly:prototype_name(GearBox)):installed(SN, GearBox, Release),
    {ok, Release}.

-spec attach(GearBox::assembly(), Shaft::assembly(), Part::assembly()) ->
                    success(Release::assembly()) | failure(E::term(), R::term(), Rejected::assembly()).
attach(GearBox, Shaft, Part) ->
    ModelName= erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft), ID = erlmachine_assembly:serial_no(Part),
    {ok, Body} = ModelName:attach(SN, ID, body(Shaft)),
    Release = erlmachine_assembly:attach(body(Shaft, Body), Part),
    (erlmachine_assembly:prototype_name(GearBox)):attached(SN, GearBox, Release, Part),
    {ok, Release}.

-spec detach(GearBox::assembly(), Shaft::assembly(), ID::serial_no()) ->
                    success(Release::assembly()) | failure(E::term(), R::term(),  Rejected::assembly()).
detach(GearBox, Shaft, ID) ->
    ModelName= erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft),
    %% At that place we need to find Part inside assembly by SN and transmit;
    {ok, Body} = ModelName:detach(SN, ID, body(Shaft)),
    Release = erlmachine_assembly:detach(body(Shaft, Body), ID),
    (erlmachine_assembly:prototype_name(GearBox)):detached(SN, GearBox, Release, ID),
    {ok, Release}.

-spec replace(GearBox::assembly(), Shaft::assembly(), Part::assembly()) ->
                     success(Release::assembly()) | failure(E::term(), R::term(), Rejected::assembly()).
replace(GearBox, Shaft, Part) ->
    ModelName = erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft), ID = erlmachine_assembly:serial_no(Part),
    {ok, Body} = ModelName:replace(SN, ID, body(Shaft)),
    Release = body(Shaft, Body),
    (erlmachine_assembly:prototype_name(GearBox)):replaced(SN, GearBox, Release, Part),
    {ok, Release}.

-spec accept(GearBox::assembly(), Shaft::assembly(), Criteria::term()) ->
                    success(Report::term(), Release::assembly())| failure(E::term(), R::term(), Rejected::assembly()).
accept(GearBox, Shaft, Criteria) ->
    ModelName = erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft),
    {Tag, Result, Body} = ModelName:accept(SN, Criteria, body(Shaft)),
    Release = body(Shaft, Body),
    case Tag of 
        ok ->
            Report = Result,
            (erlmachine_assembly:prototype_name(GearBox)):accepted(SN, GearBox, Release, Criteria, Report),
            {ok, Result, Release};
        error ->
            {_, Report} = Result,
            (erlmachine_assembly:prototype_name(GearBox)):rejected(SN, GearBox, Release, Criteria, Report),
            {error, Result, Release} 
    end.

-spec rotate(GearBox::assembly(), Shaft::assembly(), ID::serial_no(), Motion::term()) ->
                    success(Release::assembly()) | failure(E::term(), R::term(), Rejected::assembly()).
rotate(_GearBox, Shaft, ID, Motion) ->
    ModelName = erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft),
    Part = erlmachine_assembly:part(Shaft, ID),
    ReleaseBody = 
        case ModelName:rotate(SN, ID, Motion, body(Shaft)) of 
            {ok, Result, Body} -> 
                erlmachine_transmission:rotate(Part, Result),
                Body;
            {ok, Body} -> 
                Body 
        end,
    Release = body(Shaft, ReleaseBody),
    {ok, Release}.

-spec rotate(GearBox::assembly(), Shaft::assembly(), Motion::term()) ->
                    success(Release::assembly()) | failure(E::term(), R::term(), Rejected::assembly()).
rotate(GearBox, Shaft, Motion) ->
    Parts = erlmachine_assembly:parts(Shaft),
    io:format("~nShaft Parts rotate: ~p~n",[Parts]),
    {ok, Release} = lists:foldl(
      fun (Part, {ok, ShaftState}) ->
              ID = erlmachine_assembly:serial_no(Part),
              rotate(GearBox, ShaftState, ID, Motion)
      end,
      {ok, Shaft},
      Parts),
    {ok, Release}.

-spec transmit(GearBox::assembly(), Shaft::assembly(), Motion::term()) ->
                    success(Result::term(), Release::assembly()) | failure(E::term(), R::term(), Rejected::assembly()).
transmit(_GearBox, Shaft, Motion) ->
    ModelName = erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft),
    {ok, Result, Body} = ModelName:tranmsit(SN, Motion, body(Shaft)),
    Release = body(Shaft, Body),
    {ok, Result, Release}.

-spec overload(GearBox::assembly(), Shaft::assembly(), Load::term()) ->
                      success(Release::assembly()) | failure(E::term(), R::term(), Reject::assembly()).
overload(GearBox, Shaft, Load) ->
    ModelName = erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft),
    {ok, Body} = ModelName:overload(SN, Load, body(Shaft)),
    Release = body(Shaft, Body),
    (erlmachine_assembly:prototype_name(GearBox)):overloaded(SN, GearBox, Release, Load),
    {ok, Release}.

-spec block(GearBox::assembly(), Shaft::assembly(), Part::assembly(), Failure::term()) ->
                      success(Release::assembly()) | failure(E::term(), R::term(), Reject::assembly()).
block(GearBox, Shaft, Part, Failure) ->
    ModelName = erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft), ID = erlmachine_assembly:serial_no(Part),
    {ok, Body} = ModelName:block(SN, ID, Failure, body(Shaft)),
    Release = body(Shaft, Body),
    (erlmachine_assembly:prototype_name(GearBox)):blocked(SN, GearBox, Release, Part, Failure),
    {ok, Release}.

-spec uninstall(GearBox::assembly(), Shaft::assembly(), Reason::term()) -> 
    ok.
uninstall(GearBox, Shaft, Reason) ->
    ModelName = erlmachine_assembly:model_name(Shaft),
    SN = erlmachine_assembly:serial_no(Shaft),
    {ok, Body} = ModelName:uninstall(SN, Reason, body(Shaft)),
    Release = body(Shaft, Body),
    Mounted = erlmachine_assembly:mounted(Shaft),
    (Mounted /= undefined) andalso (erlmachine_assembly:prototype_name(Mounted)):uninstalled(SN, Mounted, Release, Reason),
    (Mounted == GearBox) orelse (erlmachine_assembly:prototype_name(GearBox)):uninstalled(SN, GearBox, Release, Reason),
    ok.

-spec body(Shaft::assembly()) -> Body::term().
body(Shaft) ->
    Product = erlmachine_assembly:product(Shaft),
    Product#shaft.body.

-spec body(Shaft::assembly(), Body::term()) -> Release::assembly().
body(Shaft, Body) ->
    Product = erlmachine_assembly:product(Shaft),
    erlmachine_assembly:product(Shaft, Product#shaft{body=Body}).
