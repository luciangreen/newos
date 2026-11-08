% The predicates whose inputs and outputs are recorded in io/ios.txt (see io/ios_engine.pl).
:- ios_engine:load_repo(vfs).
:- ios_engine:load_repo(logic).
:- ios_engine:load_repo(dictionary).
:- ios_engine:load_repo(nl_engine).

io_title('newos').

io_cases([conversation, spec_open, spec_save, spec_navigate, spec_search]).

% things to say, a few at a time, to a fresh knowledge base
lines(["Socrates is a man.", "All men are mortal.", "Is Socrates mortal?", "Why?", "Who is mortal?",
       "Is Socrates happy?", "The moon is not cheese.", "Is the moon cheese?", "John likes Mary.",
       "Who likes Mary?", "What does John like?", "Birds can fly.", "Tweety is a bird.", "Can Tweety fly?",
       "What is 6*7?", "2+2=5", "My name is Lucian.", "hello", "If the moon is cheese, then 2+2=4.",
       "use relevance logic", "All cheese is edible.", "What is 12/4?", "Plato is a man.", "Is Plato mortal?"]).
files([["file1","ABC 123"],["file2","hedgehogs"],["file3","I like you."]]).

io_input(conversation, K, [Said]) :-
    lines(Ls), length(Ls, L), num(K, 1, 1, 4, N),
    Start is (K * 3) mod L,
    findall(S, (between(1, N, I), J is (Start + I - 1) mod L, nth0(J, Ls, S)), Said).
io_input(spec_open, K, [[Name, Fs]]) :- files(Fs), pick(K, 2, ["file1", "file2", "file3", "file4", ""], Name).
io_input(spec_save, K, [[Name, Text]]) :- pick(K, 3, ["file1", "notes", "", "a b"], Name), pick(K, 4, ["I see it.", "I can feel it.", "A", "", "Two. Sentences."], Text).
io_input(spec_navigate, K, [[Go | Tree]]) :- pick(K, 5, ["folder1", "folder2", "folder3"], Go), pick(K, 6, [[["folder1", ["file1","file2"]], ["folder2", ["file4"]]], [["folder2", ["file1","file2","file3"]]], [["folder4", ["x"]]]], Tree).
io_input(spec_search, K, [[X, L]]) :- pick(K, 7, [a, b, c, d], X), pick_n(K, 8, 6, [a, b, c, d, e], L).

% the replies, in order, from a fresh knowledge base (Prolog's internal variable numbers in
% a reply, such as _123, are shown as _G, since they change from run to run)
io_run(conversation, [Said], Replies) :-
    kb_set_file('/tmp/newos_ios_kb.pl'), kb_reset,
    maplist([S, R]>>(chat(S, R0), plain_vars(R0, R)), Said, Replies).

plain_vars(S, T) :- string_codes(S, Cs), pv(Cs, Ds), string_codes(T, Ds).
pv([], []).
pv([0'_, D | Cs], [0'_, 0'G | Ds]) :- code_type(D, digit), !, skip_digits(Cs, Rest), pv(Rest, Ds).
pv([C | Cs], [C | Ds]) :- pv(Cs, Ds).
skip_digits([D | Cs], Rest) :- code_type(D, digit), !, skip_digits(Cs, Rest).
skip_digits(Cs, Cs).
io_run(spec_open, [In], B) :- spec_open(In, B).
io_run(spec_save, [In], B) :- spec_save(In, B).
io_run(spec_navigate, [In], B) :- spec_navigate(In, B).
io_run(spec_search, [In], B) :- spec_search(In, B).
