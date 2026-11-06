%:-dynamic test_n/1.

test_s2a(newos) :-

	retractall(num_s2a(_)),
	assertz(num_s2a(1)),

	retractall(vars_s2a(_)),
	assertz(vars_s2a([])),

	retractall(vars_base_s2a(_)),
	assertz(vars_base_s2a('A')),

	retractall(character_breakdown_mode(_)),
	assertz(character_breakdown_mode(off)),

 test_spec_to_algorithm(newos).
 
/*
open
write file
save
navigate to file
search for file contents
*/

s2a_tests([

[1,open,
[
[[input,[['A',["file1",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]]]]],[output,[['B',["ABC 123"]]]]],
[[input,[['A',["file2",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]]]],[output,[['B',["hedgehogs"]]]]],
[[input,[['A',["file3",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]]]],[output,[['B',["I like you."]]]]]
[[input,[['A',["file4",[["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]]]]],[output,[['B',["Error."]]]]]
[[input,[['A',["folder1",["folder1",["file1","file2","file3"]],["folder2",["file4","file5","file6"]]]]]],[output,[['B',["file1","file2","file3"]]]]]
,character_breakdown_mode=off,
"algorithm(In_vars,Out_var) :-\nalgorithm([[['C1','C2'],[output,[['C2','C1']]]]],[[[[1,1],[[1,2]]],[[1,2],[[1,1]]]]],In_vars,Out_var)."
],

[2,write,
[
[[input,[['A',["Diary",[[step,a,["I enjoyed writing today."]],[[step,a,["I like you."]],[[step,a,["I see it."]]]]]]]]]],[output,[['B',["true"]]]]],
[[input,[['A',["Diary",[[step,a,["Each bite is healthy."]],[[step,a,["I tested the water."]]]]]]]]],[output,[['B',["true"]]]]],
[[input,[['A',["Diary",[[step,a,["I enjoyed it."]],[[step,a,["Good."]]]]]]]]],[output,[['B',["true"]]]]],
[[input,[['A',["Diary",[[step,a,["I like food."]],[[step,a,["I like sleep."]],[[step,a,["I am good."]]]]]]]]]],[output,[['B',["true"]]]]],
[[input,[['A',["Diary",[]]]]]],[output,[['B',["false"]]]]],
,character_breakdown_mode=off,
"algorithm(In_vars,Out_var) :-\nalgorithm([[['C1','C2'],[output,[['C2','C1']]]]],[[[[1,1],[[1,2]]],[[1,2],[[1,1]]]]],In_vars,Out_var)."
],

[3,save,
[
[[input,[['A',["file1","I see it."]]]]],[output,[['B',["I see it."]]]]],
[[input,[['A',["file2","I can feel it."]]]]],[output,[['B',["I can feel it"]]]]],
[[input,[['A',["file3","I know it."]]]]],[output,[['B',["I know it."]]]]]
[[input,[['A',["","A"]]]]],[output,[['B',["Error."]]]]],
,character_breakdown_mode=off,
"algorithm(In_vars,Out_var) :-\nalgorithm([[['C1','C2'],[output,[['C2','C1']]]]],[[[[1,1],[[1,2]]],[[1,2],[[1,1]]]]],In_vars,Out_var)."
],

[4,navigate,
[
[[input,[['A',["folder1",["folder1",["file1","file2","file3"]],["folder2",["file4","file5","file6"]]]]]],[output,[['B',["file1","file2","file3"]]]]],
[[input,[['A',["folder2",["folder2",["file1","file2","file3"]]]]]],[output,[['B',["file1","file2","file3"]]]]],
[[input,[['A',["folder3",["folder4",["file1","file2","file3"]],["folder2",["file4","file5","file6"]]]]]],[output,[['B',["Error"]]]]]
,character_breakdown_mode=off,
"algorithm(In_vars,Out_var) :-\nalgorithm([[['C1','C2'],[output,[['C2','C1']]]]],[[[[1,1],[[1,2]]],[[1,2],[[1,1]]]]],In_vars,Out_var)."
],

[5,search,
[
[[input,[['A',[a,[b,b,b,a,c]]]]]],[output,[['B',[a,c]]]]],
[[input,[['A',[d,[e,e,d]]]]]],[output,[['B',[d]]]]],
[[input,[['A',[a,[f]]]]]],[output,[['B',["Error."]]]]],
,character_breakdown_mode=off,
"algorithm(In_vars,Out_var) :-\nalgorithm([[['C1','C2'],[output,[['C2','C1']]]]],[[[[1,1],[[1,2]]],[[1,2],[[1,1]]]]],In_vars,Out_var)."
]

]).

test_spec_to_algorithm1(N) :-

	(catch(algs(Algs),_,false)->
	findall(_,(member(Alg,Algs),
	retractall(algs(Alg))),_);
	true),
	retractall(algs(_)),
	assertz(algs([])),

s2a_tests(Tests),
member([N,Predicate_name,S,
character_breakdown_mode=CBM,Alg2],
Tests),

	
	
((	%retractall(test_n(_)),
	%assertz(test_n(N)),

	string_concat(Predicate_name,N,Predicate_name1),
	%catch(call_with_time_limit(10,
	(spec_to_algorithm(Predicate_name1,S,CBM,Alg1))
	%)%,
    %time_limit_exceeded,
    %fail)

,writeln1(S)
,writeln1(Alg1)
%,trace

,string_concat(Predicate_name,Rest,Alg2),
string_concat(Predicate_name1,Rest,Alg21)
,Alg21=Alg1
)->R=success;R=fail),
 writeln([R,N,spec_to_algorithm,test]),
 
 writeln([Predicate_name1,not,Predicate_name,above]),!.

/*

Necessary to load before running s2a each time:

retractall(vars_table_s2a(_)),                                               assertz(vars_table_s2a([])),                                                    ['spec_to_algorithm'].
*/

test_spec_to_algorithm(newos) :-
/*
	retractall(num_s2a(_)),
	assertz(num_s2a(1)),

	retractall(vars_s2a(_)),
	assertz(vars_s2a([])),

	retractall(vars_base_s2a(_)),
	assertz(vars_base_s2a('A')),
*/
	(catch(algs(Algs),_,false)->
	findall(_,(member(Alg,Algs),
	retractall(algs(Alg))),_);
	true),
	retractall(algs(_)),
	assertz(algs([])),

s2a_tests(Tests),

findall([N,R],(member([N,Predicate_name,S,
character_breakdown_mode=CBM,Alg2],
Tests),

	
	
((	%retractall(test_n(_)),
	%assertz(test_n(N)),

	string_concat(Predicate_name,N,Predicate_name1),
	%catch(call_with_time_limit(10,
	(spec_to_algorithm(Predicate_name1,S,CBM,Alg1))
	%)%,
    %time_limit_exceeded,
    %fail)

%,writeln1(S)
%,writeln1(Alg1)
%,trace

,string_concat(Predicate_name,Rest,Alg2),
string_concat(Predicate_name1,Rest,Alg21)
,Alg21=Alg1
)->R=success;R=fail),
 writeln([R,N,spec_to_algorithm,test]),
 nl),R1),
 findall(N,member([N,success],R1),R_success),
 writeln("Successful Tests:"),
 writeln(R_success),
 findall(N,member([N,fail],R1),R_fail),
 writeln("Failed Tests:"),
 writeln(R_fail),!.


