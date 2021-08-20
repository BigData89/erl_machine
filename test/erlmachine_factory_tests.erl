-module(erlmachine_factory_tests).
%% NOTE: The factory test is responsible to inspect:
%% a) Release of predefined extensions: gear, shaft, axle, gearbox;
%% b) Release of an assembly via datasheet;
%% c) Release of a transmission via datasheet
-include_lib("eunit/include/eunit.hrl").

erlmachine_factory_test_() ->
    Nodes = [node()], Table = 'erlmachine_factory', Tags = ['eunit'],

    {
     foreach,
     fun() ->
             meck:expect(erlmachine, modules, 0, ['erlmachine_assembly']),

             erlmachine_database:create_schema(Nodes), ok = erlmachine_database:start(),

             erlmachine_database:create_table(Table),
             erlmachine_app:wait_for_tables([Table], 1000),

             application:start(yamerl), application:start(syn),
             {ok, _} = erlmachine_factory:start(),

             [ok = erlmachine_app:add_schema(File) || File <- ["assembly.json", "graph.json"]]
     end,
     fun(_) ->
             erlmachine_factory:stop(),
             application:stop(yamerl), application:start(syn),
             erlmachine_database:delete_table(Table), erlmachine_database:delete_schema(Nodes)
     end,
     [
      {
       "Inspect assembly: datasheets/extensions/ct.yaml",
       fun() ->
               FileName = filename("datasheets/extensions/ct.yaml"),
               {ok, Datasheet} = erlmachine_assembly:datasheet(FileName),

               Assembly = erlmachine_factory:assembly(Datasheet),

               SN = erlmachine:serial_no(Assembly), true = is_binary(SN)
       end
      },
      {
       "Inspect assembly: datasheets/extensions/sup_ct.yaml",
       fun() ->
               FileName = filename("datasheets/extensions/sup_ct.yaml"),
               {ok, Datasheet} = erlmachine_assembly:datasheet(FileName),

               Assembly = erlmachine_factory:assembly(Datasheet),

               SN = erlmachine:serial_no(Assembly), true = is_binary(SN)
       end
      },
      {
       "Inspect assembly: gear",
       fun() ->
               Gear = erlmachine:tags(erlmachine_factory:gear('erlmachine_model_ct', _Opt = #{}, _Env = #{}), Tags),

               SN = erlmachine:serial_no(Gear), V = erlmachine:vertex(Gear),
               true = is_binary(SN), SN = V
       end
      },
      {
       "Inspect assembly: shaft",
        fun() ->
                Shaft = erlmachine:tags(erlmachine_factory:shaft('erlmachine_model_ct', _Opt = #{}, _Env = #{}, []), Tags),

                SN = erlmachine:serial_no(Shaft), V = erlmachine:vertex(Shaft),
                true = is_binary(SN), SN = V
        end
      },
      {
       "Inspect assembly: axle",
       fun() ->
               Axle = erlmachine:tags(erlmachine_factory:axle('erlmachine_sup_model_ct', _Opt = #{}, _Env = #{}, []), Tags),

               SN = erlmachine:serial_no(Axle), V = erlmachine:vertex(Axle),
               true = is_binary(SN), SN = V
       end
      },
      {
       "Inspect assembly: gearbox",
       fun() ->
               GearBox = erlmachine:tags(erlmachine_factory:gearbox('erlmachine_sup_model_ct', _Opt = #{}, _Env = #{}, []), Tags),

               SN = erlmachine:serial_no(GearBox), V = erlmachine:vertex(GearBox),
               true = is_binary(SN), SN = V
       end
      },
      {
       "Inspect datasheet mapping: datasheets/extensions/ct.yaml",
       fun() ->
               FileName = filename("datasheets/extensions/ct.yaml"),
               {ok, Datasheet} = erlmachine_assembly:datasheet(FileName),

               Assembly = erlmachine_factory:assembly(Datasheet),
               Model = erlmachine_assembly:model(Assembly), Prot = erlmachine_assembly:prototype(Assembly),

               SN = erlmachine:serial_no(Assembly), true = is_binary(SN),

               true = erlmachine:is_worker(Assembly),

               Body = erlmachine_assembly:body(Assembly), true = is_map(Body),

               MN = erlmachine_assembly:model_no(Assembly), true = is_binary(MN),

               Port = erlmachine:port(Assembly), true = is_binary(Port),

               Module = erlmachine_model:module(Model), 'erlmachine_model_ct' = Module,

               Opt = erlmachine_model:options(Model), true = is_map(Opt),

               Module2 = erlmachine_prototype:module(Prot), 'erlmachine_prototype_def' = Module2,

               Opt2 = erlmachine_prototype:options(Prot), true = is_map(Opt2),

               UID = erlmachine:uid(Assembly), true = is_integer(UID),

               true = is_list(erlmachine:tags(Assembly)),

               Vertex = erlmachine:vertex(Assembly), true = is_binary(Vertex),

               PN = erlmachine:part_no(Assembly), true = is_binary(PN),

               Env = erlmachine_assembly:env(Assembly), true = is_map(Env),

               Desc = erlmachine:description(Assembly), true = is_binary(Desc)
       end
      },
      {
       "Inspect datasheet mapping: datasheets/ct.yaml",
       fun() ->
               FileName = filename("datasheets/ct.yaml"),
               {ok, Datasheet} = erlmachine_graph:datasheet(FileName),

               Graph = erlmachine_factory:graph(Datasheet),

               Exts = erlmachine_graph:vertices(Graph), [_A, _B, _C, _D, _E] = Exts,
               [true = is_binary(erlmachine:serial_no(Ext)) || Ext <- Exts]
       end
      },
      {
       "Inspect serial: rotation",
       fun() ->
               ok
       end
      }
     ]
    }.

-spec filename(Path::list()) -> list().
filename(Path) ->
    filename:join(erlmachine:priv_dir(), Path).
