-module(test).
-compile({parse_transform, parse_test}).

-export([foo/2]).

foo(A,B) ->
    X = [1,2,3],
    Y = {1,2,3},
    [2*I||I<-X,I=1],
    A+B.
