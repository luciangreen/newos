/*  tests/test_newos.pl

    Run from the repository folder:
        swipl -g run_tests -t halt tests/test_newos.pl

    The spec tests reproduce the examples in specs/newos_spec.pl.  The
    conversation tests use a temporary knowledge file, so your own
    data/knowledge.pl is not touched.
*/

:- use_module(library(plunit)).
:- use_module('../vfs').
:- use_module('../logic').
:- use_module('../dictionary').
:- use_module('../nl_engine').

%   says(+Input, +Fragment): newos's reply to Input contains Fragment
says(In, Frag) :-
    chat(In, R),
    (   sub_string(R, _, _, _, Frag)
    ->  true
    ;   format(user_error, "~n  said:     ~w~n  replied:  ~w~n  expected: ...~w...~n", [In, R, Frag]),
        fail
    ).

fresh :-
    tmp_file(newos_kb, F),
    kb_set_file(F),
    kb_reset.

%   ---- the spec's examples ------------------------------------------------------

:- begin_tests(spec).

files([["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]).

test(open_file1) :- files(Fs), spec_open(["file1", Fs], B), B == ["ABC 123"].
test(open_file2) :- files(Fs), spec_open(["file2", Fs], B), B == ["hedgehogs"].
test(open_file3) :- files(Fs), spec_open(["file3", Fs], B), B == ["I like you."].
test(open_missing) :- files(Fs), spec_open(["file4", Fs], B), B == ["Error."].
test(open_folder) :-
    spec_open(["folder1", ["folder1", ["file1","file2","file3"]], ["folder2", ["file4","file5","file6"]]], B),
    B == ["file1","file2","file3"].

test(write_diary1) :-
    spec_write(["Diary", [[step,a,["I enjoyed writing today."]],[[step,a,["I like you."]],[[step,a,["I see it."]]]]]], B),
    B == ["true"].
test(write_diary2) :-
    spec_write(["Diary", [[step,a,["Each bite is healthy."]],[[step,a,["I tested the water."]]]]], B),
    B == ["true"].
test(write_empty) :- spec_write(["Diary", []], B), B == ["false"].

test(save1) :- spec_save(["file1", "I see it."], B), B == ["I see it."].
test(save2) :- spec_save(["file2", "I can feel it."], B), B == ["I can feel it."].   % spec drops the "."
test(save_noname) :- spec_save(["", "A"], B), B == ["Error."].

test(navigate1) :-
    spec_navigate(["folder1", ["folder1", ["file1","file2","file3"]], ["folder2", ["file4","file5","file6"]]], B),
    B == ["file1","file2","file3"].
test(navigate2) :-
    spec_navigate(["folder2", ["folder2", ["file1","file2","file3"]]], B),
    B == ["file1","file2","file3"].
test(navigate_missing) :-
    spec_navigate(["folder3", ["folder4", ["file1","file2","file3"]], ["folder2", ["file4","file5","file6"]]], B),
    B == ["Error"].

test(search1) :- spec_search([a, [b,b,b,a,c]], B), B == [a, c].
test(search2) :- spec_search([d, [e,e,d]], B), B == [d].
test(search_missing) :- spec_search([a, [f]], B), B == ["Error."].

:- end_tests(spec).

%   ---- language ------------------------------------------------------------------

:- begin_tests(tokenizer).

test(contractions) :-
    tokenize("Don't you know it's 2.5?", L, _),
    L == [do, not, you, know, it, is, 2.5, '?'].
test(quotes) :-
    tokenize("save notes \"Buy Milk\"", L, _),
    L == [save, notes, q("Buy Milk")].
test(arith) :-
    tokenize("2+2=4", L, _),
    L == [2, +, 2, =, 4].

:- end_tests(tokenizer).

:- begin_tests(conversation, [setup(fresh)]).

test(fact)          :- says("Socrates is a man.", "Socrates is a man").
test(rule)          :- says("All men are mortal.", "So Socrates is mortal").
test(yes)           :- says("Is Socrates mortal?", "Yes").
test(why)           :- says("Why?", "all men are mortal").
test(who)           :- says("Who is mortal?", "Socrates").
test(unknown)       :- says("Is Socrates happy?", "I don't know").
test(negative)      :- says("The moon is not cheese.", "not cheese").
test(no)            :- says("Is the moon cheese?", "No").
test(relation)      :- says("John likes Mary.", "John likes Mary").
test(who_likes)     :- says("Who likes Mary?", "John").
test(what_does)     :- says("What does John like?", "Mary").
test(can)           :- says("Birds can fly.", "All birds can fly").
test(can_q)         :- says("Tweety is a bird.", "Tweety can fly").
test(arith)         :- says("What is 6*7?", "42").
test(arith_wrong)   :- says("2+2=5", "Actually").
test(name)          :- says("My name is Lucian.", "Lucian"), says("hello", "Lucian").

:- end_tests(conversation).

:- begin_tests(conditionals, [setup(fresh)]).

test(material_paradox) :-
    says("If the moon is cheese, then 2+2=4.", "is true"),
    says("If the moon is cheese, then 2+2=4.", "paradox of material implication").
test(strict) :-
    says("use strict semantics", "strict"),
    says("If the moon is cheese then 2+2=4", "vacuously true").
test(relevance) :-
    says("use relevance logic", "relevance"),
    says("If the moon is cheese then 2+2=4", "is false"),
    says("If the moon is cheese then 2+2=4", "share no content").
test(relevance_follows) :-
    says("All cheese is edible.", "edible"),
    says("If the moon is cheese then the moon is edible", "is true").
test(lewis) :-
    says("In world w1, the moon is cheese.", "world w1"),
    says("use lewis semantics", "Lewis"),
    says("If the moon is cheese then the moon is green", "is false"),
    says("In world w1, the moon is green.", "world w1"),
    says("If the moon is cheese then the moon is green", "is true").
test(stalnaker_tie) :-
    says("In world w2, the moon is cheese.", "w2"),
    says("use stalnaker semantics", "Stalnaker"),
    says("If the moon is cheese then the moon is green", "indeterminate").
test(stalnaker_closer) :-
    says("World w2 is 2 away.", "distance 2"),
    says("If the moon is cheese then the moon is green", "is true").
test(adams) :-
    says("use adams semantics", "Adams"),
    says("If the moon is cheese then the moon is green", "P(B | A) = 0.50").
test(compare) :-
    chat("compare if the moon is cheese then 2+2=4", R),
    sub_string(R, _, _, _, "material conditional"),
    sub_string(R, _, _, _, "relevance logic"),
    sub_string(R, _, _, _, "Adams").
test(law) :-
    says("Remember that if it rains then the grass is wet.", "rule"),
    says("It rains.", "the grass is wet").

:- end_tests(conditionals).

:- begin_tests(learning, [setup(fresh)]).

test(define)     :- says("Flurb means a small blue bird.", "flurb"),
                    says("What does flurb mean?", "a small blue bird").
test(teach)      :- says("When I say good night, you say sleep well!", "sleep well"),
                    says("good night", "sleep well").
test(fallback)   :- says("zorp zorp", "What would you like me to say"),
                    says("say beep boop", "beep boop"),
                    says("zorp zorp", "beep boop").
test(ask_word)   :- says("The sky is azure.", "what does \"azure\" mean"),
                    says("It is a deep blue.", "azure means a deep blue").
test(save_load) :-
    says("Plato is a philosopher.", "Plato"),
    kb_save,
    logic_clear, dictionary_clear,
    kb_load,
    says("Is Plato a philosopher?", "Yes"),
    says("What does flurb mean?", "small blue bird").

:- end_tests(learning).

:- begin_tests(files, [setup(fresh)]).

test(save_open)  :- says("save notes \"buy milk\"", "Saved"),
                    says("open notes", "buy milk").
test(append)     :- says("add \"and eggs\" to notes", "Added"),
                    says("open notes", "and eggs").
test(search)     :- says("search for milk", "notes").
test(search_no)  :- says("search for hedgehogs", "Error").
test(diary)      :- says("Dear diary, I like you.", "true"),
                    says("open diary", "I like you").
test(missing)    :- says("open file4", "Error").
test(folders)    :- says("make folder folder1", "folder1"),
                    says("navigate to folder1", "folder1"),
                    says("save file1 \"ABC 123\"", "folder1"),
                    says("list", "file1"),
                    says("navigate to folder9", "Error").

:- end_tests(files).
