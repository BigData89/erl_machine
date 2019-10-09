-module(shaft_tracker).

-folder(<<"erlmachine/mechanics/shaft_tracker">>).

%% At that point we need a prototype registration layer;
%% So, instead of schema with gen_server:call which can be expanded by behaviours module we need to improve additional layer between them and provide registration abilities for that layer too;
%% I guess synchronous call can be achived by the next way - asynchronous message is sended on input and output is checked for the result at the same time (with specified timeout); 
%% API.
-export([]).
