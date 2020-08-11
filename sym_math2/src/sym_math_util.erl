-module(sym_math_util).

-include("types.hrl").

-export([is_just_simple_arith/1, eval/1, contain_symbol/2]).

-spec is_just_simple_arith(exp()) -> boolean().
is_just_simple_arith({number, _}) -> true;
is_just_simple_arith({symbol, _}) -> false;
is_just_simple_arith({binop_exp, _, E1, E2}) ->
    is_just_simple_arith(E1) andalso is_just_simple_arith(E2);
is_just_simple_arith({negative_exp, E}) ->
    is_just_simple_arith(E);
is_just_simple_arith({diff_exp, _, _}) -> false;
is_just_simple_arith({int_exp, _, _}) -> false;
is_just_simple_arith({ExpTag, E}) when ExpTag =:= log_exp;
				       ExpTag =:= exp_exp;
				       ExpTag =:= sin_exp;
				       ExpTag =:= cos_exp ->
    is_just_simple_arith(E).

-spec eval(exp()) -> {number, number()}.
eval(Exp) ->
    case is_just_simple_arith(Exp) of
	true ->
	    eval_internal(Exp);
	false ->
	    erlang:error({"cannot eval exp containing symbol", Exp})
    end.

eval_internal(N={number, _}) -> N;
eval_internal({binop_exp, Op, E1, E2}) -> 
    Func = fetch_func(Op),
    {number, N1} = eval(E1),
    {number, N2} = eval(E2),
    {number, Func(N1, N2)};
eval_internal({negative_exp, E}) ->
    {number, N} = eval(E),
    {number, -N};
eval_internal({ExpTag, E}) when ExpTag =:= log_exp;
				ExpTag =:= exp_exp;
				ExpTag =:= sin_exp;
				ExpTag =:= cos_exp ->
    Func = fetch_func(ExpTag),
    {number, N} = eval(E),
    {number, Func(N)}.

fetch_func(Tag) ->
    FuncLib = [
	       {'+', fun (A, B) -> A + B end},
	       {'-', fun (A, B) -> A - B end},
	       {'*', fun (A, B) -> A * B end},
	       {'/', fun (A, B) -> A / B end},
	       {'^', fun (A, B) -> math:pow(A, B) end},
	       {log_exp, fun (X) -> math:log(X) end},
	       {exp_exp, fun (X) -> math:exp(X) end},
	       {sin_exp, fun (X) -> math:sin(X) end},
	       {cos_exp, fun (X) -> math:cos(X) end}
	      ],
    {Tag, Func} = lists:keyfind(Tag, 1, FuncLib),
    Func.

contain_symbol({number, _}, {symbol, _S}) -> false;
contain_symbol({symbol, S}, {symbol, S}) -> true;
contain_symbol({binop_exp, _Op, A1, A2}, {symbol, S}) -> 
    contain_symbol(A1, {symbol, S}) orelse contain_symbol(A2, {symbol, S});
contain_symbol({Tag, E}, {symbol, S}) when Tag =:= negative_exp;
					   Tag =:= log_exp;
					   Tag =:= exp_exp;
					   Tag =:= sin_exp;
					   Tag =:= cos_exp ->
    contain_symbol(E, {symbol, S});
contain_symbol(_, _) -> false.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

eval_test() ->
    ExpAns = [
	      {"3*2+2*3", {number, 12}},
	      {"3*(2+2)*3", {number, 36}},
	      {"3+5^2", {number,28.0}},
	      {"log{2.718}", {number,0.999896315728952}},
	      {"log{exp{1}}", {number,1.0}}
	     ],
    ok = lists:foreach(fun ({E, A}) ->
			       ?assert(
				  sym_math_util:eval(sym_math_parse:scan_and_parse(E)) =:= A
				 )
		       end,
		       ExpAns).

contain_symbol_test() ->
    ?assertNot(contain_symbol({symbol, a}, {symbol, b})).

-endif.