/*  nl_engine.pl - understanding and generating natural language for newos

    chat(+Text, -Reply, -Info) is the whole conversation interface.

    It understands, among other things:
      statements      "Socrates is a man."  "All men are mortal."  "Tweety can fly."
                      "John likes Mary."  "The moon is not cheese."
      questions       "Is Socrates mortal?"  "Who is mortal?"  "What is 2+2?"
                      "What do you know about the moon?"  "Why?"
      conditionals    "If the moon is cheese, then 2+2=4."      (evaluated)
                      "Remember that if it rains then the grass is wet."  (a law)
                      "Compare if the moon is cheese then 2+2=4."
                      "Use strict semantics."  "Which semantics?"
      possible worlds "In world w1, the moon is cheese."  "World w1 is 2 away."
                      "World w1 has probability 0.3."
      the dictionary  "Flurb means a small blue bird."  "What does flurb mean?"
      learned replies "When I say hello, you say hi there!"  (and it asks you
                      how to reply to things it doesn't understand)
      files           open, save, write, diary, list, navigate, search, delete
      memory          save, forget X, reset everything
*/

:- module(nl_engine,
          [ chat/3,
            chat/2,
            tokenize/3,
            realize/2,
            kb_save/0,
            kb_load/0,
            kb_set_file/1,
            kb_file/1,
            kb_export/1,
            kb_import_string/2,
            kb_reset/0,
            nl_init/0,
            state_json/1
          ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yall)).
:- use_module(dictionary).
:- use_module(logic).
:- use_module(vfs).

:- dynamic pattern/2,           % pattern(KeyTokens, ReplyString)
           pending/1,           % what the last turn asked the user
           last_entity/1,
           last_answer/3,       % last_answer(Prop, Value, Proof)
           user_name/1,
           asked_about/1,
           turn/1,
           last_ask_turn/1,
           resolve_off/0,
           kb_file_/1.

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, 'data/knowledge.pl', F),
   retractall(kb_file_(F)),
   assertz(kb_file_(F)).

kb_file(F) :- kb_file_(F).
kb_set_file(F) :- retractall(kb_file_(_)), assertz(kb_file_(F)).

%   ---- set-up ----------------------------------------------------------------

nl_init :-
    seed_dictionary,
    vfs_init,
    (   kb_file(F), exists_file(F) -> kb_load ; seed_knowledge ),
    ( turn(_) -> true ; assertz(turn(0)) ).

seed_knowledge :-
    forall(seed_pattern(K, R), add_pattern(K, R)),
    add_fact(actual, is(newos, chatbot), true),
    note_article(chatbot),
    remember_shown_as(newos, newos),
    vfs_save(welcome, "Welcome to newos. Try: open welcome, save notes \"buy milk\", dear diary I learned Prolog today, search milk.", _).

seed_pattern([hello], "Hello{name}! What shall we talk about?").
seed_pattern([hi], "Hi{name}!").
seed_pattern([hey], "Hey{name}! What's on your mind?").
seed_pattern([good, morning], "Good morning{name}!").
seed_pattern([how, are, you], "I'm well, thank you. I'm learning all the time. How are you?").
seed_pattern([thanks], "You're welcome.").
seed_pattern([thank, you], "You're welcome.").
seed_pattern([bye], "Goodbye{name}! I'll remember what we talked about.").
seed_pattern([goodbye], "Goodbye{name}!").
seed_pattern([i, am, fine], "Glad to hear it.").
seed_pattern([i, am, good], "That's good to hear.").
seed_pattern([ok], "OK.").
seed_pattern([yes], "Good.").
seed_pattern([no], "All right.").

add_pattern(K, R) :-
    retractall(pattern(K, _)),
    assertz(pattern(K, R)).

%   ---- the conversation ------------------------------------------------------

chat(Text, Reply) :- chat(Text, Reply, _).

chat(Text, Reply, Info) :-
    with_mutex(newos_chat, chat_(Text, Reply)),
    pending_flag(P),
    semantics(S),
    split_string(Reply, "\n", "", Lines),
    atomic_list_concat(Lines, ' ', SpeakA),
    atom_string(SpeakA, Speak),
    Info = _{reply:Reply, speak:Speak, semantics:S, pending:P}.

pending_flag(P) :- ( pending(X) -> functor(X, P, _) ; P = none ).

chat_(Text, Reply) :-
    next_turn,
    tokenize(Text, L, O),
    (   L == []
    ->  Reply = "Say something and I'll do my best to understand."
    ;   catch(converse(L, O, Reply0), E,
              error_reply(E, Reply0))
    ->  Reply = Reply0
    ;   Reply = "Sorry, I got tangled up there. Could you put it another way?"
    ),
    catch(kb_save, _, true).

error_reply(E, Reply) :-
    format(string(Reply), "Something went wrong (~q). Could you put it another way?", [E]).

next_turn :-
    ( retract(turn(N)) -> true ; N = 0 ),
    N1 is N + 1,
    assertz(turn(N1)).

converse(L, O, Reply) :-
    pending(P), !,
    handle_pending(P, L, O, Reply).
converse(L, O, Reply) :-
    sentences(L, O, Ss),
    maplist(sentence_reply, Ss, Rs),
    exclude(==(""), Rs, Rs1),
    atomic_list_concat(Rs1, ' ', R),
    atom_string(R, Reply).

sentence_reply(s(L, O, M), R) :-
    (   respond(L, O, M, R0) -> R = R0 ; R = "" ).

%   handlers are tried in this order
respond(L, O, M, R) :-
    member(H, [ h_meta, h_teach, h_fs, h_define, h_identity, h_conditional,
                h_world, h_question, h_statement, h_smalltalk, h_fallback ]),
    call(H, L, O, M, R), !.

%   ---- pending questions -----------------------------------------------------

is_skip(L) :- memberchk(L, [[skip], [never, mind], [nothing], [cancel], [forget, it], [nevermind], [no]]).

escape_words([what, who, why, how, is, are, does, do, can, if, when, open, save, write,
              list, search, navigate, go, make, create, delete, define, use, switch,
              help, forget, compare, remember, imagine, dear, diary, where]).

clean_for_pending(L0, L) :- exclude([T]>>memberchk(T, ['.', '!', '?', ',']), L0, L).

handle_pending(teach(Key), L0, O, Reply) :-
    clean_for_pending(L0, L),
    (   is_skip(L)
    ->  retractall(pending(_)), Reply = "OK, never mind."
    ;   L = [say|_]
    ->  retractall(pending(_)),
        rest_text(L0, O, [say], Text),
        learn_reply(Key, Text, Reply)
    ;   L = [W|_], escape_words(Es), memberchk(W, Es)
    ->  retractall(pending(_)),
        converse(L0, O, Reply)
    ;   retractall(pending(_)),
        join_tokens(O, Text),
        learn_reply(Key, Text, Reply)
    ).
handle_pending(define(W), L0, O, Reply) :-
    clean_for_pending(L0, L),
    (   is_skip(L)
    ->  retractall(pending(_)), Reply = "No problem."
    ;   L = [Q|_], memberchk(Q, [what, who, why, how, does, do, can, if, open, save, list, search, help])
    ->  retractall(pending(_)),
        converse(L0, O, Reply)
    ;   retractall(pending(_)),
        definition_prefix(W, Pre),
        append(Pre, _, L), !,
        rest_text(L0, O, Pre, Def0),
        trim_def(Def0, Def),
        define_word(W, Def),
        format(string(Reply), "Thank you. Now I know that ~w means ~w.", [W, Def])
    ).
handle_pending(confirm_reset, L0, O, Reply) :-
    clean_for_pending(L0, L),
    retractall(pending(_)),
    (   L = [yes|_]
    ->  kb_reset, Reply = "Done. I've forgotten everything I learned and started fresh."
    ;   converse(L0, O, Reply0),
        string_concat("OK, I'll keep everything. ", Reply0, Reply)
    ).

definition_prefix(W, [W, means]).
definition_prefix(W, [W, is]).
definition_prefix(_, [it, means]).
definition_prefix(_, [it, is]).
definition_prefix(_, [that, means]).
definition_prefix(_, [that, is]).
definition_prefix(_, [it]).
definition_prefix(_, []).

trim_def(D0, D) :-
    split_string(D0, "", " .!", [D1]),
    (   D1 == "" -> D = "something" ; D = D1 ).

learn_reply(Key, Text0, Reply) :-
    split_string(Text0, "", " \"", [Text]),
    add_pattern(Key, Text),
    atomic_list_concat(Key, ' ', KA),
    format(string(Reply), "Got it. When you say \"~w\", I'll say \"~w\".", [KA, Text]).

%   ---- meta commands -----------------------------------------------------------

h_meta(L0, _, _, R) :-
    no_commas(L0, L),
    meta(L, R).

meta([help], R) :- !, help_text(R).
meta([what, can, you, do], R) :- !, help_text(R).
meta(L, R) :-
    memberchk(L, [[save], [save, everything], [save, memory], [save, knowledge], [save, your, memory],
                  [save, the, dictionary], [save, dictionary], [save, what, you, know], [remember, this]]), !,
    kb_save, kb_file(F),
    format(string(R), "Saved my dictionary, logic and files to ~w.", [F]).
meta([reset, everything], R) :- !,
    retractall(pending(_)), assertz(pending(confirm_reset)),
    R = "Are you sure you want me to forget everything I've learned? Say yes to confirm.".
meta([forget, everything], R) :- !, meta([reset, everything], R).
meta([forget|Rest], R) :-
    Rest \== [],
    strip_det(Rest, Ws),
    atomic_list_concat(Ws, ' ', E0),
    resolve_word(E0, E),
    forget_about(E, N),
    retractall(pattern(Ws, _)),
    plural_s(N, Sf),
    (   N > 0
    ->  format(string(R), "OK, I've forgotten ~d thing~a about ~w.", [N, Sf, E])
    ;   format(string(R), "I didn't know anything about ~w anyway.", [E])
    ), !.
meta(L, R) :-
    memberchk(L, [[which, semantics], [what, semantics], [what, semantics, are, you, using],
                  [which, semantics, are, you, using], [semantics]]), !,
    semantics(S), semantics_name(S, N),
    format(string(R), "I'm reading \"if\" with the ~w. You can say: use material, strict, relevance, lewis, stalnaker or adams semantics.", [N]).
meta(L, R) :-
    ( L = [use|T] ; L = [switch, to|T] ; L = [semantics|T] ; L = [set, semantics, to|T] ; L = [change, semantics, to|T] ),
    member(W, T), semantics_word(W, S), !,
    set_semantics(S), semantics_name(S, N),
    semantics_blurb(S, B),
    format(string(R), "Now reading \"if\" with the ~w. ~w", [N, B]).
meta(L, R) :-
    memberchk(L, [[list, worlds], [show, worlds], [what, worlds, are, there], [which, worlds],
                  [what, worlds], [worlds]]), !,
    worlds_text(R).
meta(L, R) :-
    memberchk(L, [[what, do, you, know], [what, have, you, learned], [what, have, you, learnt],
                  [tell, me, what, you, know]]), !,
    summary_text(R).

semantics_word(material, material).
semantics_word(classical, material).
semantics_word(strict, strict).
semantics_word(modal, strict).
semantics_word(relevance, relevance).
semantics_word(relevant, relevance).
semantics_word(lewis, lewis).
semantics_word(counterfactual, lewis).
semantics_word(stalnaker, stalnaker).
semantics_word(adams, adams).
semantics_word(probabilistic, adams).
semantics_word(probability, adams).
semantics_word(indicative, adams).

semantics_blurb(material, "\"If A then B\" is false only when A is true and B is false.").
semantics_blurb(strict, "\"If A then B\" needs B in every possible world where A holds.").
semantics_blurb(relevance, "\"If A then B\" needs A and B to share content, and B to follow from A.").
semantics_blurb(lewis, "\"If A then B\" needs B in all the closest worlds where A holds.").
semantics_blurb(stalnaker, "\"If A then B\" needs B in the single closest world where A holds.").
semantics_blurb(adams, "\"If A then B\" is as assertable as the probability of B given A.").

plural_s(1, '') :- !.
plural_s(_, s).

help_text(R) :-
    R = "Here's what I can do.\n\c
\u2022 Learn facts: \"Socrates is a man.\" \"All men are mortal.\" \"Tweety can fly.\" \"John likes Mary.\"\n\c
\u2022 Answer: \"Is Socrates mortal?\" \"Who is mortal?\" \"Why?\" \"What do you know about Socrates?\" \"What is 6*7?\"\n\c
\u2022 Judge \"if\": \"If the moon is cheese, then 2+2=4.\" \"Compare if the moon is cheese then 2+2=4.\"\n\c
\u2022 Change semantics: \"use strict | relevance | lewis | stalnaker | adams | material semantics\".\n\c
\u2022 Possible worlds: \"In world w1, the moon is cheese.\" \"World w1 is 2 away.\" \"World w1 has probability 0.3.\"\n\c
\u2022 Words: \"Flurb means a small blue bird.\" \"What does flurb mean?\"\n\c
\u2022 Replies: \"When I say good night, you say sleep well!\"\n\c
\u2022 Files: open, save notes \"text\", write \"text\" to notes, dear diary ..., list, navigate to folder, make folder, search for text, delete.\n\c
\u2022 Memory: save, forget the moon, reset everything.".

%   ---- teaching replies ----------------------------------------------------------

h_teach(L, O, _, R) :-
    (   append([when, i, say], Rest, L)
    ;   append([if, i, say], Rest, L)
    ;   append([when, someone, says], Rest, L)
    ;   append([if, someone, says], Rest, L)
    ;   append([if, i, tell, you], Rest, L)
    ), !,
    length(L, NL), length(Rest, NR), Skip is NL - NR,
    reply_separator(Sep),
    append(Key0, AfterSep, Rest),
    append(Sep, _, AfterSep), !,
    no_commas(Key0, Key1),
    exclude([T]>>( T = q(_) ), Key1, Key2),
    quoted_key(Key0, Key2, Key),
    Key \== [],
    length(Key0, NK), length(Sep, NS),
    Drop is Skip + NK + NS,
    length(Prefix, Drop), append(Prefix, ReplyToks, O),
    join_tokens(ReplyToks, Text0),
    learn_reply(Key, Text0, R).

quoted_key(Key0, _, Key) :-
    member(q(S), Key0), !,
    tokenize(S, Key1, _),
    exclude([T]>>memberchk(T, ['.', '!', '?', ',']), Key1, Key).
quoted_key(_, Key, Key).

reply_separator([',', you, say]).
reply_separator([',', you, should, say]).
reply_separator([you, say]).
reply_separator([you, should, say]).
reply_separator([',', say]).
reply_separator([say]).
reply_separator([',', reply]).
reply_separator([reply]).
reply_separator([',', answer]).
reply_separator([answer]).
reply_separator([',', respond, with]).
reply_separator([respond, with]).
reply_separator([then, say]).

%   ---- files ---------------------------------------------------------------------

h_fs(L0, O, _, R) :-
    no_commas(L0, L),
    fs(L, L0, O, R).

fs([open, F], _, _, R) :- !, open_reply(F, R).
fs([open, file, F], _, _, R) :- !, open_reply(F, R).
fs([open, folder, F], _, _, R) :- !, open_reply(F, R).
fs([open, the, F], _, _, R) :- !, open_reply(F, R).
fs([open, my, F], _, _, R) :- !, open_reply(F, R).
fs([read, F], _, _, R) :- atom(F), \+ function_word(F), !, open_reply(F, R).
fs([read, my, F], _, _, R) :- !, open_reply(F, R).
fs([show, file, F], _, _, R) :- !, open_reply(F, R).
fs([show, me, F], _, _, R) :- vfs_file(_, F, _), !, open_reply(F, R).

fs([save, q(S), as, F], _, _, R) :- !, save_reply(F, S, R).
fs([save, q(S), to, F], _, _, R) :- !, save_reply(F, S, R).
fs([write, q(S), to, F], _, _, R) :- !, save_reply(F, S, R).
fs([write, q(S), in, F], _, _, R) :- !, append_reply(F, S, R).
fs([write, q(S), into, F], _, _, R) :- !, append_reply(F, S, R).
fs([add, q(S), to, F], _, _, R) :- !, append_reply(F, S, R).
fs([append, q(S), to, F], _, _, R) :- !, append_reply(F, S, R).
fs([save, Word, F|Rest], L0, O, R) :- memberchk(Word, [file, the]), atom(F), Rest \== [], !,
    content_after(L0, O, 3, Rest, S), save_reply(F, S, R).
fs([create, file, F|Rest], L0, O, R) :- atom(F), !,
    ( Rest == [] -> S = "" ; content_after(L0, O, 3, Rest, S) ), save_reply(F, S, R).
fs([save, F|Rest], L0, O, R) :- atom(F), F \== q(_), Rest \== [], \+ function_word(F), !,
    content_after(L0, O, 2, Rest, S), save_reply(F, S, R).
fs([save, F], _, _, R) :- atom(F), \+ function_word(F), !,
    format(string(R), "What should ~w say? For example: save ~w \"your text\"", [F, F]).

fs([dear, diary|_], L0, O, R) :- !,
    rest_text(L0, O, [dear, diary], S0), strip_lead(S0, S), diary_reply(S, R).
fs([diary|Rest], L0, O, R) :- Rest \== [], !,
    rest_text(L0, O, [diary], S0), strip_lead(S0, S), diary_reply(S, R).
fs([write, in, my, diary|_], L0, O, R) :- !,
    rest_text(L0, O, [write, in, my, diary], S0), strip_lead(S0, S), diary_reply(S, R).
fs([write, diary|_], L0, O, R) :- !,
    rest_text(L0, O, [write, diary], S0), strip_lead(S0, S), diary_reply(S, R).
fs([write, in, diary|_], L0, O, R) :- !,
    rest_text(L0, O, [write, in, diary], S0), strip_lead(S0, S), diary_reply(S, R).

fs([make, folder, F], _, _, R) :- !, mkdir_reply(F, R).
fs([make, a, folder, F], _, _, R) :- !, mkdir_reply(F, R).
fs([create, folder, F], _, _, R) :- !, mkdir_reply(F, R).
fs([create, a, folder, F], _, _, R) :- !, mkdir_reply(F, R).
fs([new, folder, F], _, _, R) :- !, mkdir_reply(F, R).
fs([mkdir, F], _, _, R) :- !, mkdir_reply(F, R).

fs([navigate, to, F], _, _, R) :- !, cd_reply(F, R).
fs([navigate, to, folder, F], _, _, R) :- !, cd_reply(F, R).
fs([navigate, F], _, _, R) :- !, cd_reply(F, R).
fs([go, to, F], _, _, R) :- vfs_folder(F), !, cd_reply(F, R).
fs([go, to, folder, F], _, _, R) :- !, cd_reply(F, R).
fs([cd, F], _, _, R) :- !, cd_reply(F, R).
fs([go, home], _, _, R) :- !, cd_reply(home, R).
fs([go, back], _, _, R) :- !, cd_reply(home, R).
fs(L, _, _, R) :-
    memberchk(L, [[list], [ls], [list, files], [show, files], [what, files, are, there],
                  [what, files, do, you, have], [list, folder], [dir], [files]]), !,
    vfs_cwd(F), list_reply(F, R).
fs([list, F], _, _, R) :- vfs_folder(F), !, list_reply(F, R).
fs([list, folder, F], _, _, R) :- !, list_reply(F, R).
fs([list, folders], _, _, R) :- !, folders_reply(R).
fs([show, folders], _, _, R) :- !, folders_reply(R).
fs([where, am, i], _, _, R) :- !, vfs_cwd(F), format(string(R), "You're in the folder ~w.", [F]).

fs([search, for|_], L0, O, R) :- !, rest_text(L0, O, [search, for], S), search_reply(S, R).
fs([search, files, for|_], L0, O, R) :- !, rest_text(L0, O, [search, files, for], S), search_reply(S, R).
fs([search|Rest], L0, O, R) :- Rest \== [], !, rest_text(L0, O, [search], S), search_reply(S, R).
fs([find, file|_], L0, O, R) :- !, rest_text(L0, O, [find, file], S), search_reply(S, R).
fs([find, q(S)], _, _, R) :- !, search_reply(S, R).

fs([delete, F], _, _, R) :- atom(F), \+ function_word(F), !, delete_reply(F, R).
fs([delete, file, F], _, _, R) :- !, delete_reply(F, R).
fs([remove, file, F], _, _, R) :- !, delete_reply(F, R).

content_after(L0, O, N, _Rest, S) :-
    no_commas_count(L0, N, N0),
    length(Pre, N0), append(Pre, Tail0, O),
    drop_content_words(Tail0, Tail),
    join_tokens(Tail, S).

%   number of tokens in L0 that correspond to the first N comma-free tokens
no_commas_count(L0, N, Count) :- nc_count(L0, N, 0, Count).
nc_count(_, 0, C, C) :- !.
nc_count([','|T], N, C0, C) :- !, C1 is C0 + 1, nc_count(T, N, C1, C).
nc_count([_|T], N, C0, C) :- N1 is N - 1, C1 is C0 + 1, nc_count(T, N1, C1, C).
nc_count([], _, C, C).

drop_content_words([T|Ts], Rest) :-
    atom(T), downcase_atom(T, L),
    memberchk(L, [with, saying, containing, as, ':', ',', that, says]), !,
    drop_content_words(Ts, Rest).
drop_content_words(Ts, Ts).

strip_lead(S0, S) :- split_string(S0, "", " ,:-", [S]).

open_reply(F, R) :-
    vfs_open(F, Res),
    (   Res = file(_, C)
    ->  (   C == "" -> format(string(R), "~w is empty.", [F])
        ;   format(string(R), "~w:\n~w", [F, C])
        )
    ;   Res = folder(Files)
    ->  files_text(F, Files, R)
    ;   format(string(R), "Error. I can't find a file or folder called ~w.", [F])
    ).

save_reply(F, S, R) :-
    vfs_save(F, S, Res),
    (   Res = created(Folder) -> format(string(R), "Saved a new file ~w in ~w.", [F, Folder])
    ;   Res = replaced(Folder) -> format(string(R), "Saved ~w in ~w (replacing what was there).", [F, Folder])
    ;   R = "Error. A file needs a name."
    ).

append_reply(F, S, R) :-
    vfs_append(F, S, appended(Folder)),
    format(string(R), "Added that to ~w in ~w.", [F, Folder]).

diary_reply(S, R) :-
    vfs_diary(S, Res),
    (   Res == error
    ->  R = "Your diary entry was empty, so I didn't write anything (false)."
    ;   R = "Written in your diary (true)."
    ).

mkdir_reply(F, R) :- vfs_mkdir(F), format(string(R), "Made a folder called ~w.", [F]).

cd_reply(F, R) :-
    (   vfs_cd(F) -> vfs_list(F, Files), files_text(F, Files, R0), string_concat("Now in ", R0, R)
    ;   format(string(R), "Error. There's no folder called ~w.", [F])
    ).

list_reply(F, R) :-
    (   vfs_list(F, Files) -> files_text(F, Files, R)
    ;   format(string(R), "Error. There's no folder called ~w.", [F])
    ).

files_text(F, [], R) :- !, format(string(R), "~w, which is empty.", [F]).
files_text(F, Files, R) :-
    atomic_list_concat(Files, ', ', FA),
    format(string(R), "~w: ~w.", [F, FA]).

folders_reply(R) :-
    findall(F, vfs_folder(F), Fs0), sort(Fs0, Fs),
    atomic_list_concat(Fs, ', ', A),
    format(string(R), "Folders: ~w.", [A]).

search_reply(S0, R) :-
    split_string(S0, "", " \".?", [S]),
    (   S == ""
    ->  R = "What should I search for?"
    ;   vfs_search(S, Hits),
        (   Hits == []
        ->  format(string(R), "Error. Nothing contains \"~w\".", [S])
        ;   maplist([F-N, T]>>format(string(T), "~w/~w", [F, N]), Hits, Ts),
            atomic_list_concat(Ts, ', ', A),
            format(string(R), "\"~w\" is in: ~w.", [S, A])
        )
    ).

delete_reply(F, R) :-
    vfs_delete(F, Res),
    (   Res = deleted(Folder) -> format(string(R), "Deleted ~w from ~w.", [F, Folder])
    ;   format(string(R), "Error. There's no file called ~w.", [F])
    ).

%   ---- dictionary --------------------------------------------------------------

h_define(L0, O, M, R) :-
    no_commas(L0, L),
    define(L, L0, O, M, R).

define([what, does, W, mean], _, _, _, R) :- !, meaning_reply(W, R).
define([what, do, W, mean], _, _, _, R) :- !, meaning_reply(W, R).
define([what, is, the, meaning, of, W], _, _, _, R) :- !, meaning_reply(W, R).
define([what, is, a, W], _, _, _, R) :- \+ has_knowledge(W), word_meaning(W, _), !, meaning_reply(W, R).
define([what, is, an, W], _, _, _, R) :- \+ has_knowledge(W), word_meaning(W, _), !, meaning_reply(W, R).
define([what, is, W], _, _, _, R) :- atom(W), \+ function_word(W), \+ known_entity(W), word_meaning(W, _), !, meaning_reply(W, R).
define([what, are, W], _, _, _, R) :- atom(W), singular(W, S), \+ known_entity(S), word_meaning(S, _), !, meaning_reply(S, R).
define([define, W], _, _, _, R) :- !, meaning_reply(W, R).
define([define, W, as|_], L0, O, _, R) :- !, rest_text(L0, O, [define, W, as], D), teach_meaning(W, D, R).
define([define, W, to, mean|_], L0, O, _, R) :- !, rest_text(L0, O, [define, W, to, mean], D), teach_meaning(W, D, R).
define([W, means|_], L0, O, _, R) :- atom(W), \+ function_word(W), !,
    rest_text(L0, O, [W, means], D), teach_meaning(W, D, R).
define([the, word, W, means|_], L0, O, _, R) :- !,
    rest_text(L0, O, [the, word, W, means], D), teach_meaning(W, D, R).
define([the, meaning, of, W, is|_], L0, O, _, R) :- !,
    rest_text(L0, O, [the, meaning, of, W, is], D), teach_meaning(W, D, R).

teach_meaning(W, D0, R) :-
    trim_def(D0, D),
    define_word(W, D),
    format(string(R), "Thanks. I've added \"~w\" to my dictionary: ~w.", [W, D]).

meaning_reply(W, R) :-
    (   word_meaning(W, D)
    ->  format(string(R), "\"~w\" means ~w.", [W, D])
    ;   function_word(W)
    ->  format(string(R), "\"~w\" is one of the small words that hold sentences together.", [W])
    ;   retractall(pending(_)), assertz(pending(define(W))),
        format(string(R), "I don't know what \"~w\" means yet. What does it mean?", [W])
    ).

%   ---- who's who ---------------------------------------------------------------

h_identity(L0, O, _, R) :-
    no_commas(L0, L),
    identity(L, L0, O, R).

identity([my, name, is, N|_], L0, O, R) :- !, set_name(L0, O, [my, name, is], N, R).
identity([call, me, N|_], L0, O, R) :- !, set_name(L0, O, [call, me], N, R).
identity([i, am, called, N|_], L0, O, R) :- !, set_name(L0, O, [i, am, called], N, R).
identity([what, is, my, name], _, _, R) :- !,
    (   user_name(N) -> name_display(N, D), format(string(R), "Your name is ~w.", [D])
    ;   R = "You haven't told me your name yet. What is it?",
        retractall(pending(_))
    ).
identity([who, am, i], _, _, R) :- !, describe(user, R).
identity(L, _, _, R) :-
    memberchk(L, [[who, are, you], [what, are, you], [what, is, your, name], [whats, your, name]]), !,
    findall(P, holds_is(newos, P), Ps),
    preds_text(Ps, T),
    format(string(R), "I'm newos, a chatbot that learns what you teach me. I am ~w. I read \"if\" with whichever semantics you choose.", [T]).

set_name(L0, O, _Prefix, N, R) :-
    (   nth0(I, L0, N), nth0(I, O, N0), atom(N0) -> remember_shown_as(N, N0) ; true ),
    retractall(user_name(_)), assertz(user_name(N)),
    name_display(N, D),
    format(string(R), "Nice to meet you, ~w.", [D]).

name_display(E, D) :- ( shown_as(E, D0) -> D = D0 ; D = E ).

%   ---- conditionals ----------------------------------------------------------------

h_conditional(L0, _, _, R) :-
    exclude(==(':'), L0, L1),
    (   strip_any(L1, [[remember, that], [remember], [rule], [law], [suppose, that], [it, is, a, rule, that]], L2)
    ->  Mode = law
    ;   strip_any(L1, [[compare]], L2)
    ->  Mode = compare
    ;   L2 = L1, Mode = evaluate
    ),
    conditional_parts(L2, A, B), !,
    conditional_reply(Mode, A, B, R).

strip_any(L, Prefixes, Rest) :-
    member(P, Prefixes), append(P, Rest, L), Rest \== [], !.

conditional_parts(L, A, B) :-
    (   L = [if|Rest]
    ;   L = [is, it, true, that, if|Rest]
    ;   L = [would, it, be, true, that, if|Rest]
    ), !,
    (   append(AT, [then|BT], Rest) -> true
    ;   append(AT, [','|BT], Rest) -> true
    ),
    AT \== [], BT \== [],
    parse_prop_quiet(AT, A),
    parse_prop_quiet(BT, B).
conditional_parts(L, A, B) :-
    (   L = [does|Rest] -> true ; Rest = L ),
    member(Imp, [imply, implies, entail, entails]),
    append(AT, [Imp|BT], Rest), !,
    AT \== [], BT \== [],
    parse_prop_quiet(AT, A),
    parse_prop_quiet(BT, B).

parse_prop_quiet(T0, P) :-
    no_commas(T0, T),
    setup_call_cleanup(assertz(resolve_off),
                       once(phrase(prop(P), T)),
                       retractall(resolve_off)).

conditional_reply(law, A, B, R) :- !,
    add_law(A, B),
    realize(law(A, B), S),
    format(string(R), "OK, I'll treat that as a rule: ~w.", [S]).
conditional_reply(compare, A, B, R) :- !,
    realize(law(A, B), S0), capitalize(S0, S),
    findall(Line,
            ( member(Sem, [material, strict, relevance, lewis, stalnaker, adams]),
              evaluate(Sem, A, B, result(V, Notes)),
              semantics_name(Sem, N),
              value_text(V, VT),
              short_reason(Notes, A, B, Why),
              format(string(Line), "\u2022 ~w: ~w~w", [N, VT, Why])
            ),
            Lines),
    atomic_list_concat(Lines, '\n', LA),
    format(string(R), "\"~w\"\n~w", [S, LA]).
conditional_reply(evaluate, A, B, R) :-
    semantics(Sem),
    evaluate(Sem, A, B, result(V, Notes)),
    semantics_name(Sem, N),
    realize(law(A, B), S0), capitalize(S0, S),
    value_text(V, VT),
    maplist([Note, T]>>say_note(Note, A, B, T), Notes, Ts0),
    exclude(==(""), Ts0, Ts),
    atomic_list_concat(Ts, ' ', Expl),
    format(string(R), "Under the ~w, \"~w\" is ~w. ~w\n(Say \"compare\" before it to see every semantics, or \"remember that\" to make it a rule.)",
           [N, S, VT, Expl]).

value_text(true, "true") :- !.
value_text(false, "false") :- !.
value_text(indeterminate, "indeterminate") :- !.
value_text(undefined, "undefined") :- !.
value_text(prob(P), T) :- !,
    (   P >= 0.9 -> A = "highly assertable"
    ;   P >= 0.5 -> A = "somewhat assertable"
    ;   A = "not assertable"
    ),
    format(string(T), "~w (P(B | A) = ~2f)", [A, P]).

short_reason(Notes, _A, _B, T) :-
    (   memberchk(paradox(false_antecedent), Notes) -> T0 = "the antecedent is false"
    ;   memberchk(paradox(true_consequent), Notes) -> T0 = "the consequent is true"
    ;   memberchk(paradox(strict), Notes) -> T0 = "the consequent is necessary"
    ;   memberchk(vacuous(_), Notes) -> T0 = "no possible world makes the antecedent true (vacuous)"
    ;   memberchk(no_shared_content(_, _), Notes) -> T0 = "the two parts share no content"
    ;   memberchk(does_not_follow(_, _), Notes) -> T0 = "the consequent doesn't follow"
    ;   memberchk(follows(_), Notes) -> T0 = "the consequent follows from the antecedent"
    ;   memberchk(counter_worlds(Ws, _), Notes) -> worlds_list(Ws, WT), format(string(T0), "it fails in ~w", [WT])
    ;   memberchk(tie(_, _), Notes) -> T0 = "the closest worlds disagree"
    ;   memberchk(zero_probability, Notes) -> T0 = "the antecedent has probability 0"
    ;   memberchk(closest(Ws, _), Notes) -> worlds_list(Ws, WT), format(string(T0), "checked the closest world(s): ~w", [WT])
    ;   memberchk(probabilities(PA, _, _, _), Notes) -> format(string(T0), "P(A) = ~2f", [PA])
    ;   memberchk(b_in_all(_), Notes) -> T0 = "the consequent holds wherever the antecedent does"
    ;   T0 = ""
    ),
    (   T0 == "" -> T = "" ; format(string(T), " \u2014 ~w", [T0]) ).

say_note(value_in(W, P, V), _, _, T) :- !,
    realize(P, S),
    world_name(W, WN),
    (   V == true -> VT = "true"
    ;   truth(W, P, false, _) -> VT = "false"
    ;   VT = "false (I can't prove it, so it counts as false)"
    ),
    format(string(T0), "In ~w, \"~w\" is ~w.", [WN, S, VT]), capitalize(T0, T).
say_note(material_rule, _, _, "A material conditional is false only when its antecedent is true and its consequent false.") :- !.
say_note(paradox(false_antecedent), _, _, "It comes out true only because the antecedent is false \u2014 a paradox of material implication, which is why people reach for other semantics of \"if\".") :- !.
say_note(paradox(true_consequent), _, _, "It comes out true just because the consequent is true, though the two parts are unrelated \u2014 another paradox of material implication.") :- !.
say_note(no_a_world(A), _, _, T) :- !,
    realize(A, S), all_worlds(Ws), length(Ws, N), plural_s(N, Sf),
    format(string(T), "None of the ~d world~a I know of makes \"~w\" true.", [N, Sf, S]).
say_note(vacuous(strict), _, _, "So there is no world where the antecedent holds and the consequent fails: the strict conditional is vacuously true.") :- !.
say_note(vacuous(lewis), _, _, "Lewis counts a counterfactual with an impossible antecedent as vacuously true.") :- !.
say_note(vacuous(stalnaker), _, _, "With no antecedent-world to select, Stalnaker's semantics makes it vacuously true.") :- !.
say_note(a_worlds(Ws), A, _, T) :- !,
    realize(A, S), worlds_list(Ws, WT),
    format(string(T), "\"~w\" holds in ~w.", [S, WT]).
say_note(b_in_all(B), _, _, T) :- !,
    realize(B, S), format(string(T), "\"~w\" holds in all of them.", [S]).
say_note(counter_worlds(Ws, B), _, _, T) :- !,
    realize(B, S), worlds_list(Ws, WT),
    format(string(T), "But \"~w\" fails in ~w.", [S, WT]).
say_note(necessary(B), _, _, T) :- !,
    realize(B, S), format(string(T), "\"~w\" holds in every world, so it's necessary,", [S]).
say_note(paradox(strict), _, _, "and a necessary consequent makes any strict conditional true \u2014 a paradox of strict implication.") :- !.
say_note(no_shared_content(CA, CB), _, _, T) :- !,
    atomic_list_concat(CA, ', ', A), atomic_list_concat(CB, ', ', B),
    format(string(T), "The antecedent is about ~w and the consequent about ~w. They share no content, so relevance logic rejects the conditional.", [A, B]).
say_note(shared(Ws), _, _, T) :- !,
    atomic_list_concat(Ws, ', ', A),
    format(string(T), "The two parts share content (~w),", [A]).
say_note(follows(Proof), _, _, T) :- !,
    explain(Proof, E),
    format(string(T), "and the consequent follows from the antecedent: ~w.", [E]).
say_note(does_not_follow(_, _), _, _, "but I can't derive the consequent from the antecedent plus what I know.") :- !.
say_note(closest(Ws, D), A, _, T) :- !,
    realize(A, S), worlds_list(Ws, WT),
    (   Ws = [_] -> Is = "is", Sf = '' ; Is = "are", Sf = s ),
    format(string(T), "The closest world~a where \"~w\" holds ~w ~w (distance ~w).", [Sf, S, Is, WT, D]).
say_note(tie(Yes, No), _, _, T) :- !,
    worlds_list(Yes, YT), worlds_list(No, NT),
    (   Yes == [] -> format(string(T), "The consequent fails in all of them (~w).", [NT])
    ;   No == [] -> format(string(T), "The consequent holds in all of them (~w).", [YT])
    ;   format(string(T), "Several worlds are equally close: the consequent holds in ~w but not in ~w. Stalnaker assumes a unique closest world, so there's no single answer.", [YT, NT])
    ).
say_note(zero_probability, _, _, "The antecedent has probability 0, so P(B | A) is undefined.") :- !.
say_note(probabilities(PA, P, _, _), _, _, T) :- !,
    format(string(T), "Weighing the worlds I know, P(A) = ~2f and P(B | A) = ~2f. On Adams's account a conditional is assertable to the degree that P(B | A) is high.", [PA, P]).
say_note(_, _, _, "").

world_name(actual, "the actual world") :- !.
world_name(W, T) :- format(string(T), "world ~w", [W]).

worlds_list(Ws, T) :-
    maplist([W, N]>>( W == actual -> N = "the actual world" ; format(string(N), "~w", [W]) ), Ws, Ns),
    atomic_list_concat(Ns, ', ', A),
    atom_string(A, T).

%   ---- possible worlds ---------------------------------------------------------------

h_world(L0, _, _, R) :-
    world_cmd(L0, R).

world_cmd([in, world, W|Rest0], R) :- !,
    exclude(==(','), Rest0, Rest),
    parse_prop_quiet(Rest, P),
    add_fact(W, P, true),
    realize(P, S),
    format(string(R), "OK: in world ~w, ~w.", [W, S]).
world_cmd(L0, R) :-
    no_commas(L0, L),
    (   append([imagine, a, world, W], [Wh|Rest], L)
    ;   append([imagine, world, W], [Wh|Rest], L)
    ;   append([suppose, there, is, a, world, W], [Wh|Rest], L)
    ),
    memberchk(Wh, [where, in, with]), !,
    (   Rest = [which|Rest1] -> true ; Rest1 = Rest ),
    parse_prop_quiet(Rest1, P),
    add_fact(W, P, true),
    realize(P, S),
    format(string(R), "Imagined world ~w, where ~w.", [W, S]).
world_cmd(L0, R) :-
    no_commas(L0, L),
    (   L = [world, W, is, N, away]
    ;   L = [world, W, is, N, steps, away]
    ;   L = [world, W, is, at, distance, N]
    ;   L = [world, W, has, distance, N]
    ;   L = [the, distance, of, world, W, is, N]
    ;   L = [the, distance, to, world, W, is, N]
    ), number_tok(N, D), !,
    set_distance(W, D),
    format(string(R), "World ~w is now at distance ~w from the actual world (smaller is closer).", [W, D]).
world_cmd(L0, R) :-
    no_commas(L0, L),
    (   L = [world, W, has, probability, N]
    ;   L = [world, W, has, weight, N]
    ;   L = [the, probability, of, world, W, is, N]
    ;   L = [the, actual, world, has, probability, N], W = actual
    ;   L = [the, actual, world, has, weight, N], W = actual
    ), number_tok(N, Pr), !,
    set_weight(W, Pr),
    world_name(W, WN),
    format(string(R), "Gave ~w a probability weight of ~w.", [WN, Pr]).
world_cmd(L0, R) :-
    no_commas(L0, L),
    (   L = [what, is, true, in, world, W] ; L = [describe, world, W] ; L = [show, world, W] ), !,
    world_text(W, R).

number_tok(N, N) :- number(N), !.
number_tok(W, N) :- number_word(W, N).

%   ---- questions --------------------------------------------------------------------

question_word(W) :- memberchk(W, [what, who, whom, why, how, is, are, am, does, do, can, which, where, when]).

h_question(L0, _, M, R) :-
    no_commas(L0, L),
    L = [W|_],
    (   M == '?' -> true ; question_word(W) ),
    question(L, R), !.

question([why|_], R) :- !, why_reply(R).
question([how, do, you, know|_], R) :- !, why_reply(R).

question([what, is|T], R) :- phrase(expr(E), T), !, arith_reply(E, R).
question([what, are|T], R) :- phrase(expr(E), T), !, arith_reply(E, R).
question([how, much, is|T], R) :- phrase(expr(E), T), !, arith_reply(E, R).
question([calculate|T], R) :- phrase(expr(E), T), !, arith_reply(E, R).
question(T, R) :- phrase(expr(E), T), !, arith_reply(E, R).

question([what, do, you, know, about|T], R) :- !, about_reply(T, R).
question([tell, me, about|T], R) :- !, about_reply(T, R).
question([what, else, do, you, know, about|T], R) :- !, about_reply(T, R).

question([is, it, true, that|T], R) :- parse_prop(T, P), !, truth_reply(P, R).
question([is, it, the, case, that|T], R) :- parse_prop(T, P), !, truth_reply(P, R).

question([Are, Q, W|T], R) :-
    memberchk(Are, [are, is]), memberchk(Q, [all, every]), !,
    class_word(W, C),
    phrase(pred(P0, Art), T),
    class_pred(P0, Art, Are, P),
    rule_reply(C, P, R).
question([can, all, W|T], R) :- !,
    class_word(W, C),
    phrase(pred(V, _), T),
    atom_concat('can ', V, P),
    rule_reply(C, P, R).

question([Cop|T], R) :-
    memberchk(Cop, [is, are, am]),
    phrase((subj(S), opt_not(N), pred(P0, Art)), T), !,
    note_art(Art, P0),
    mk(N, is(S, P0), P),
    remember_entity(S),
    truth_reply(P, R).
question([can|T], R) :-
    phrase((subj(S), opt_not(N), pred(V, _)), T), !,
    atom_concat('can ', V, P0),
    mk(N, is(S, P0), P),
    remember_entity(S),
    truth_reply(P, R).
question([D|T], R) :-
    memberchk(D, [does, do]),
    phrase((subj(S), opt_not(N), verb_any(V), obj(O)), T), !,
    mk(N, rel(V, S, O), P),
    remember_entity(S),
    truth_reply(P, R).

question([Wh, Cop|T], R) :-
    memberchk(Wh, [who, what, which]), memberchk(Cop, [is, are]),
    phrase(subj(S), T), known_entity(S), !,
    remember_entity(S),
    describe(S, R).
question([Wh, Cop|T], R) :-
    memberchk(Wh, [who, what, which]), memberchk(Cop, [is, are]),
    phrase(pred(P0, Art), T), !,
    note_art(Art, P0),
    who_is_reply(P0, R).
question([Wh, can|T], R) :-
    memberchk(Wh, [who, what, which]),
    phrase(pred(V, _), T), !,
    atom_concat('can ', V, P),
    who_is_reply(P, R).
question([Wh, D|T], R) :-
    memberchk(Wh, [what, who, whom]), memberchk(D, [does, do]),
    phrase((subj(S), verb_any(V)), T), !,
    findall(O, holds_rel(V, S, O), Os),
    remember_entity(S),
    objects_reply(V, S, Os, R).
question([Wh, VW|T], R) :-
    memberchk(Wh, [who, what]),
    known_verb_form(VW, V),
    phrase(obj(O), T), !,
    findall(S, holds_rel(V, S, O), Ss),
    subjects_reply(V, O, Ss, R).

arith_reply(E, R) :-
    (   catch(X is E, _, fail)
    ->  ( float(X), X =:= truncate(X) -> Y is truncate(X) ; Y = X ),
        format(string(R), "~w = ~w.", [E, Y]),
        retractall(last_answer(_, _, _)),
        assertz(last_answer(eq(E, Y), true, math(eq(E, Y))))
    ;   R = "That can't be worked out (dividing by zero, perhaps?)."
    ).

truth_reply(P, R) :-
    truth(actual, P, V, Proof),
    retractall(last_answer(_, _, _)),
    assertz(last_answer(P, V, Proof)),
    (   V == true
    ->  realize(P, S0), capitalize(S0, S), format(string(R), "Yes. ~w.", [S])
    ;   V == false
    ->  negate(P, NP), realize(NP, S0), capitalize(S0, S), format(string(R), "No. ~w.", [S])
    ;   realize(P, S),
        format(string(R), "I don't know whether ~w. Tell me and I'll remember.", [S])
    ).

negate(not(P), P) :- !.
negate(P, not(P)).

why_reply(R) :-
    (   last_answer(P, V, Proof)
    ->  (   V == unknown
        ->  realize(P, S), format(string(R), "I couldn't find any reason to think ~w, or that it's false.", [S])
        ;   explain(Proof, E), format(string(R), "Because ~w.", [E])
        )
    ;   R = "Why what? Ask me a question first, and then ask why."
    ).

rule_reply(C, P, R) :-
    max_depth_q(D),
    Sk = '$someone',
    plural_phrase(C, Cs),
    (   prove(actual, [is(Sk, C)], is(Sk, P), D, _)
    ->  realize(all(C, P), S0), capitalize(S0, S), format(string(R), "Yes. ~w.", [S])
    ;   refute(actual, [is(Sk, C)], is(Sk, P), D, _)
    ->  realize(none(C, P), S0), capitalize(S0, S), format(string(R), "No. ~w.", [S])
    ;   format(string(R), "I don't know that all ~w are ~w.", [Cs, P])
    ).

max_depth_q(8).

who_is_reply(P, R) :-
    findall(E, ( known_subject(E), holds_cwa(actual, is(E, P)) ), Es0),
    sort(Es0, Es),
    pred_text(P, PT),
    (   Es == []
    ->  (   word_meaning(P, D)
        ->  format(string(R), "I don't know anyone or anything that is ~w. (\"~w\" means ~w.)", [PT, P, D])
        ;   format(string(R), "I don't know anyone or anything that is ~w.", [PT])
        )
    ;   maplist([E, T]>>np_display(E, T), Es, Ts),
        and_list(Ts, AT),
        length(Es, N),
        ( N =:= 1, Es = [E1] -> subject_text(E1, _, Per) ; Per = 3 ),
        (   atom_concat('can ', V, P)
        ->  format(string(R0), "~w can ~w.", [AT, V])
        ;   ( N > 1 -> Cop = "are" ; copula(Per, Cop) ),
            format(string(R0), "~w ~w ~w.", [AT, Cop, PT])
        ),
        capitalize(R0, R)
    ).

objects_reply(V, S, [], R) :- !,
    subject_text(S, ST, Per), ( Per == 3 -> Aux = "does" ; Aux = "do" ),
    format(string(R0), "I don't know what ~w ~w ~w.", [ST, Aux, V]), capitalize(R0, R).
objects_reply(V, S, Os, R) :-
    maplist([O, T]>>object_text(O, T), Os, Ts), and_list(Ts, AT),
    subject_text(S, ST, Per), verb_form(Per, V, VT),
    format(string(R0), "~w ~w ~w.", [ST, VT, AT]), capitalize(R0, R).

subjects_reply(V, O, [], R) :- !,
    object_text(O, OT), third_person(V, VT),
    format(string(R), "I don't know who ~w ~w.", [VT, OT]).
subjects_reply(V, O, Ss, R) :-
    maplist([S, T]>>np_display(S, T), Ss, Ts), and_list(Ts, AT),
    object_text(O, OT),
    (   Ss = [S1] -> subject_text(S1, _, Per), verb_form(Per, V, VT) ; VT = V ),
    format(string(R0), "~w ~w ~w.", [AT, VT, OT]), capitalize(R0, R).

holds_rel(V, S, O) :- fact(actual, rel(V, S, O)).

about_reply(T, R) :-
    (   phrase(subj(S), T) -> true
    ;   strip_det(T, Ws), atomic_list_concat(Ws, ' ', S)
    ),
    remember_entity(S),
    describe(S, R).

%!  describe(+Entity, -Reply)
describe(E, R) :-
    findall(P, holds_is(E, P), Ps),
    findall(not(is(E, P)), nfact(actual, is(E, P)), Ns),
    findall(rel(V, E, O), fact(actual, rel(V, E, O)), Rs),
    findall(rel(V, S, E), ( fact(actual, rel(V, S, E)), S \== E ), Rs2),
    append([Ns, Rs, Rs2], Others),
    (   Ps == [] -> Parts0 = []
    ;   subject_text(E, ST, Per), copula(Per, Cop), preds_text(Ps, PT),
        format(string(P1), "~w ~w ~w", [ST, Cop, PT]), Parts0 = [P1]
    ),
    maplist(realize, Others, OTs),
    append(Parts0, OTs, Parts),
    (   E \== user, E \== newos, word_meaning(E, D)
    ->  format(string(DT), "\"~w\" means ~w", [E, D]), append(Parts, [DT], All)
    ;   All = Parts
    ),
    (   All == []
    ->  np_display(E, ET),
        format(string(R), "I don't know anything about ~w yet. Tell me something!", [ET])
    ;   maplist([S0, S1]>>capitalize(S0, S1), All, Caps),
        atomic_list_concat(Caps, '. ', A),
        format(string(R), "~w.", [A])
    ).

%   all predicates provable of E: stated, or derived through rules and laws
holds_is(E, P) :-
    findall(P0, candidate_pred(P0), Cs0),
    sort(Cs0, Cs),
    member(P, Cs),
    holds_cwa(actual, is(E, P)).

candidate_pred(P) :- fact(_, is(_, P)).
candidate_pred(P) :- rule(all(_, P)).
candidate_pred(P) :- rule(all(P, _)).
candidate_pred(P) :- law(_, is(_, P)).

preds_text(Ps, T) :-
    maplist(pred_text, Ps, Ts0),
    exclude([X]>>sub_string(X, 0, _, _, "can "), Ts0, Ts1),
    include([X]>>sub_string(X, 0, _, _, "can "), Ts0, Cans),
    and_list(Ts1, A),
    (   Cans == [] -> T = A
    ;   and_list(Cans, CA),
        (   Ts1 == [] -> format(string(T), "someone who ~w", [CA])  % rare
        ;   format(string(T), "~w, and ~w", [A, CA])
        )
    ).

known_entity(E) :-
    (   fact(_, is(E, _)) ; nfact(_, is(E, _)) ; fact(_, rel(_, E, _)) ; fact(_, rel(_, _, E))
    ;   E == user ; E == newos
    ), !.

known_subject(E) :-
    findall(S, ( fact(_, is(S, _)) ; fact(_, rel(_, S, _)) ), Ss0),
    sort(Ss0, Ss),
    member(E, Ss),
    E \== '$someone'.

has_knowledge(W) :- known_entity(W), !.
has_knowledge(W) :- rule(all(W, _)), !.

%   ---- statements -----------------------------------------------------------------

h_statement(L0, O, M, R) :-
    M \== '?',
    no_commas(L0, L),
    \+ ( L = [W|_], memberchk(W, [what, who, why, how, which]) ),
    statement(L, O, R).

statement([Q, W|T], _, R) :-
    memberchk(Q, [all, every, each, any]), !,
    class_word(W, C),
    rule_from(T, C, Rule),
    learn_rule(Rule, R).
statement([no, W|T], _, R) :- !,
    class_word(W, C),
    rule_from(T, C, all(C, P)),
    learn_rule(none(C, P), R).
statement([W, are|T], _, R) :-
    generic_plural(W, C), !,
    rule_from([are|T], C, Rule),
    learn_rule(Rule, R).
statement([W, can|T], _, R) :-
    generic_plural(W, C), known_class(C), !,
    rule_from([can|T], C, Rule),
    learn_rule(Rule, R).
statement(L, O, R) :-
    phrase(prop(P), L), !,
    note_names(L, O),
    learn_fact(P, R).

rule_from([Cop, not|T], C, none(C, P)) :-
    memberchk(Cop, [is, are]), !,
    phrase(pred(P0, Art), T),
    class_pred(P0, Art, Cop, P).
rule_from([Cop|T], C, all(C, P)) :-
    memberchk(Cop, [is, are]), !,
    phrase(pred(P0, Art), T),
    class_pred(P0, Art, Cop, P).
rule_from([can, not|T], C, none(C, P)) :- !,
    phrase(pred(V, _), T), atom_concat('can ', V, P).
rule_from([cannot|T], C, none(C, P)) :- !,
    phrase(pred(V, _), T), atom_concat('can ', V, P).
rule_from([can|T], C, all(C, P)) :-
    phrase(pred(V, _), T), atom_concat('can ', V, P).

%   "are animals" -> animal (and remember it takes an article)
class_pred(P0, yes, _, P) :- !, singular_phrase(P0, P), note_article(P).
class_pred(P0, no, are, P) :-
    \+ sub_atom(P0, _, _, _, ' '),
    singular(P0, P), P \== P0, !,
    note_article(P).
class_pred(P, _, _, P).

class_word(W, C) :- singular(W, C).

generic_plural(W, C) :-
    atom(W), \+ function_word(W), \+ pronoun(W), \+ entity_word(W, _),
    singular(W, C), C \== W,
    \+ known_entity(W).

known_class(C) :-
    (   fact(_, is(_, C)) ; rule(all(C, _)) ; rule(all(_, C)) ; uses_article(C) ; word(C, noun, _, _) ), !.

learn_rule(Rule, R) :-
    Rule =.. [_, C, P],
    learn_word(C, noun), note_article(C),
    pred_head(P, H), learn_word(H, adjective),
    add_rule(Rule),
    realize(Rule, S0), capitalize(S0, S),
    findall(E, ( known_subject(E), holds_cwa(actual, is(E, C)) ), Es0), sort(Es0, Es),
    (   Rule = all(_, _), Es \== []
    ->  maplist([E, T]>>( realize(is(E, P), T0), capitalize(T0, T) ), Es, Ts), and_list(Ts, AT),
        format(string(Extra1), " So ~w, too.", [AT])
    ;   Extra1 = ""
    ),
    ack(Ack),
    format(string(R0), "~w ~w.~w", [Ack, S, Extra1]),
    maybe_ask(P, R0, R).

learn_fact(eq(A, B), R) :- !,
    (   catch(( X is A, Y is B ), _, fail)
    ->  (   X =:= Y -> format(string(R), "That's right: ~w = ~w.", [A, B])
        ;   format(string(R), "Actually, ~w = ~w, not ~w.", [A, X, Y])
        )
    ;   R = "I can't work that out."
    ).
learn_fact(P, R) :-
    (   truth(actual, P, false, _) -> Changed = true ; Changed = false ),
    (   truth(actual, P, true, _), \+ stored(P) -> Already = true ; Already = false ),
    add_fact(actual, P, true),
    note_vocab(P),
    prop_subject(P, S), remember_entity(S),
    realize(P, Said0), capitalize(Said0, Said),
    (   Changed == true -> format(string(R0), "Oh, I thought otherwise \u2014 I've updated that: ~w.", [Said])
    ;   Already == true -> format(string(R0), "I already worked that out: ~w.", [Said])
    ;   ack(Ack), format(string(R0), "~w ~w.", [Ack, Said])
    ),
    consequences(P, Cons),
    (   Cons == [] -> R1 = R0
    ;   maplist(realize, Cons, CTs), and_list(CTs, CA),
        format(string(R1), "~w That means ~w.", [R0, CA])
    ),
    (   P = is(_, Pr) -> maybe_ask(Pr, R1, R) ; R = R1 ).

stored(P) :- fact(actual, P).

%   new things that follow from a fact about E
consequences(is(E, C), Cons) :- !,
    findall(is(E, D),
            ( rule(all(C, D)), holds_cwa(actual, is(E, D)), \+ fact(actual, is(E, D)) ),
            Cons0),
    findall(B, ( law(is(E, C), B), holds_cwa(actual, B), \+ fact(actual, B) ), Cons1),
    append(Cons0, Cons1, Cons2),
    sort(Cons2, Cons).
consequences(P, Cons) :-
    findall(B, ( law(P, B), holds_cwa(actual, B), \+ fact(actual, B) ), Cons0),
    sort(Cons0, Cons).

prop_subject(is(S, _), S) :- !.
prop_subject(rel(_, S, _), S) :- !.
prop_subject(not(P), S) :- !, prop_subject(P, S).
prop_subject(and(A, _), S) :- !, prop_subject(A, S).
prop_subject(_, none).

note_vocab(is(S, P)) :- !, learn_word_safe(S, noun), pred_head(P, H), learn_word_safe(H, adjective).
note_vocab(rel(V, S, O)) :- !, learn_word_safe(V, verb), learn_word_safe(S, noun), learn_word_safe(O, noun).
note_vocab(not(P)) :- !, note_vocab(P).
note_vocab(and(A, B)) :- !, note_vocab(A), note_vocab(B).
note_vocab(_).

learn_word_safe(W, P) :-
    (   atom(W), W \== user, W \== newos, W \== none, \+ sub_atom(W, _, _, _, ' ')
    ->  learn_word(W, P)
    ;   true
    ).

pred_head(P, H) :-
    atomic_list_concat(Parts, ' ', P),
    (   Parts = [can, H|_] -> true ; last(Parts, H) ).

%   Ask what a new descriptive word means, now and then.
maybe_ask(P, R0, R) :-
    pred_head(P, W),
    turn(T),
    (   atom(W), W \== '', \+ number(W), atom_length(W, Len), Len > 2,
        word(W, _, "", learned), \+ asked_about(W),
        ( last_ask_turn(LT) -> T - LT >= 3 ; true ),
        \+ pending(_)
    ->  assertz(asked_about(W)),
        retractall(last_ask_turn(_)), assertz(last_ask_turn(T)),
        retractall(pending(_)), assertz(pending(define(W))),
        format(string(R), "~w By the way, what does \"~w\" mean?", [R0, W])
    ;   R = R0
    ).

ack(A) :-
    turn(T), I is T mod 4,
    nth0(I, ["OK, I'll remember that:", "Got it:", "Noted:", "I've learned that"], A).

note_names(L, O) :-
    forall(( nth0(I, O, Orig), atom(Orig), Orig \== '',
             nth0(I, L, Low), atom(Low), Low \== Orig,
             \+ function_word(Low),
             atom_chars(Orig, [C|_]), char_type(C, upper)
           ),
           remember_shown_as(Low, Orig)).

%   ---- small talk and learned replies ------------------------------------------------

h_smalltalk(L0, _, _, R) :-
    exclude([T]>>memberchk(T, [',', '.', '!', '?']), L0, L),
    L \== [],
    (   pattern(L, R0) -> true
    ;   best_pattern(L, R0)
    ),
    fill_name(R0, R).

best_pattern(L, R) :-
    sort(L, LS),
    findall(Score-Rep,
            ( pattern(K, Rep), sort(K, KS),
              intersection(LS, KS, I), I \== [],
              union(LS, KS, U),
              length(I, NI), length(U, NU),
              Score is NI / NU, Score >= 0.5 ),
            Scored),
    Scored \== [],
    max_member(_-R, Scored).

fill_name(R0, R) :-
    (   user_name(N) -> name_display(N, D), format(string(Fill), ", ~w", [D]) ; Fill = "" ),
    (   sub_string(R0, B, _, A, "{name}")
    ->  sub_string(R0, 0, B, _, Pre), sub_string(R0, _, A, 0, Post),
        atomics_to_string([Pre, Fill, Post], R)
    ;   R = R0
    ).

h_fallback(L0, _, _, R) :-
    exclude([T]>>memberchk(T, [',', '.', '!', '?']), L0, L),
    L \== [],
    retractall(pending(_)),
    assertz(pending(teach(L))),
    R = "I'm not sure how to answer that yet. What would you like me to say when you say that? (Or say \"skip\".)".

%   ---- grammar ------------------------------------------------------------------------

entity_word(i, user).
entity_word(me, user).
entity_word(myself, user).
entity_word(you, newos).
entity_word(yourself, newos).

pronoun(W) :- memberchk(W, [it, he, she, they, him, her, them, this, that]).

resolve_pronoun(W, E) :-
    (   resolve_off -> E = W
    ;   last_entity(E0) -> E = E0
    ;   E = W
    ).

resolve_word(W, E) :-
    (   entity_word(W, E0) -> E = E0
    ;   pronoun(W) -> resolve_pronoun(W, E)
    ;   E = W
    ).

remember_entity(E) :-
    (   atom(E), E \== user, E \== newos, E \== none, \+ pronoun(E), E \== '$someone'
    ->  retractall(last_entity(_)), assertz(last_entity(E))
    ;   true
    ).

content_tok(W) :- atom(W), \+ function_word(W), \+ boundary(W), \+ punct(W).

punct(W) :- memberchk(W, ['.', ',', '!', '?', ':', ';', '+', '-', '*', '/', '=', '(', ')', '\'', '"']).

boundary(W) :- memberchk(W, [and, or, then, ',', '?', '.', '!']).

prop(P) --> simple(A), prop_rest(A, P).
prop_rest(A, and(A, B)) --> [and], !, prop(B).
prop_rest(A, or(A, B)) --> [or], !, prop(B).
prop_rest(A, A) --> [].

simple(eq(A, B)) --> expr(A), eqop, expr(B), !.
simple(P) --> subj(S), cop, opt_not(N), pred(Pr, Art), { note_art(Art, Pr), mk(N, is(S, Pr), P) }.
simple(P) --> subj(S), [can], opt_not(N), pred(V, _), { atom_concat('can ', V, Pr), mk(N, is(S, Pr), P) }.
simple(not(is(S, Pr))) --> subj(S), [cannot], pred(V, _), { atom_concat('can ', V, Pr) }.
simple(not(rel(V, S, O))) --> subj(S), [D], { memberchk(D, [does, do]) }, [not], verb_any(V), obj(O).
simple(rel(V, S, O)) --> subj(S), verb(V), obj(O).

cop --> [is].
cop --> [are].
cop --> [am].

eqop --> [=].
eqop --> [=, =].
eqop --> [is].
eqop --> [equals].
eqop --> [equal, to].
eqop --> [is, equal, to].

opt_not(yes) --> [not], !.
opt_not(no) --> [].

mk(no, P, P).
mk(yes, P, not(P)).

note_art(yes, P) :- !, note_article(P).
note_art(_, _).

subj(E) --> [D], { memberchk(D, [the, a, an]) }, [W], { content_tok(W) },
    { ( D == the -> note_the(W) ; true ), E = W }.
subj(E) --> [my, W], { content_tok(W), atom_concat('my ', W, E) }.
subj(E) --> [your, W], { content_tok(W), atom_concat('your ', W, E) }.
subj(E) --> [W], { entity_word(W, E) }.
subj(E) --> [W], { pronoun(W), resolve_pronoun(W, E) }.
subj(W) --> [W], { content_tok(W) }.

%   In statements a verb must be a known verb or visibly inflected ("eats"),
%   so that "good night" is not read as a sentence about goods.
verb(V) --> [W], { known_verb_form(W, V) }.

%   After "does"/"do" any word in verb position is a verb.
verb_any(V) --> [W], { atom(W), \+ function_word(W), \+ boundary(W), \+ punct(W), base_verb(W, V) }.

known_verb_form(W, V) :-
    atom(W), \+ function_word(W), \+ boundary(W), \+ punct(W),
    base_verb(W, V),
    (   W \== V -> true
    ;   word(V, verb, _, _)
    ).

obj(O) --> [D], { memberchk(D, [the, a, an]) }, words1(Ws),
    { atomic_list_concat(Ws, ' ', O), ( D == the -> note_the(O) ; note_article(O) ) }.
obj(E) --> [W], { entity_word(W, E) }.
obj(E) --> [W], { pronoun(W), resolve_pronoun(W, E) }.
obj(O) --> words1(Ws), { atomic_list_concat(Ws, ' ', O) }.
obj(none) --> [].

pred(P, Art) --> opt_art(Art), words1(Ws), { atomic_list_concat(Ws, ' ', P) }.

opt_art(yes) --> [A], { memberchk(A, [a, an]) }, !.
opt_art(no) --> [].

words1([W|Ws]) --> word_tok(W), words0(Ws).
words0([W|Ws]) --> word_tok(W), words0(Ws).
words0([]) --> [].

word_tok(W) --> [W], { atomic(W), \+ boundary(W), \+ memberchk(W, ['?', '=', '+', '*', '/']) }.

expr(E) --> term(T), expr_rest(T, E).
expr_rest(Acc, E) --> addop(Op), !, term(T), { Acc1 =.. [Op, Acc, T] }, expr_rest(Acc1, E).
expr_rest(E, E) --> [].
term(T) --> factor(F), term_rest(F, T).
term_rest(Acc, T) --> mulop(Op), !, factor(F), { Acc1 =.. [Op, Acc, F] }, term_rest(Acc1, T).
term_rest(T, T) --> [].
factor(N) --> [N], { number(N) }, !.
factor(N) --> [W], { atom(W), number_word(W, N) }, !.
factor(E) --> ['('], expr(E), [')'].
factor(N) --> [-], [N0], { number(N0), N is -N0 }.

addop(+) --> [+].
addop(+) --> [plus].
addop(-) --> [-].
addop(-) --> [minus].
mulop(*) --> [*].
mulop(*) --> [times].
mulop(*) --> [multiplied, by].
mulop(/) --> [/].
mulop(/) --> [divided, by].
mulop(/) --> [over].

parse_prop(T0, P) :- no_commas(T0, T), once(phrase(prop(P), T)).

%   ---- generation -----------------------------------------------------------------------

realize(is(E, P), S) :- !,
    subject_text(E, ST, Per),
    (   atom_concat('can ', V, P) -> format(string(S), "~w can ~w", [ST, V])
    ;   pred_text(P, PT), copula(Per, C), format(string(S), "~w ~w ~w", [ST, C, PT])
    ).
realize(not(is(E, P)), S) :- !,
    subject_text(E, ST, Per),
    (   atom_concat('can ', V, P) -> format(string(S), "~w cannot ~w", [ST, V])
    ;   pred_text(P, PT), copula(Per, C), format(string(S), "~w ~w not ~w", [ST, C, PT])
    ).
realize(rel(V, E, O), S) :- !,
    subject_text(E, ST, Per), verb_form(Per, V, VT), object_text(O, OT),
    (   OT == "" -> format(string(S), "~w ~w", [ST, VT]) ; format(string(S), "~w ~w ~w", [ST, VT, OT]) ).
realize(not(rel(V, E, O)), S) :- !,
    subject_text(E, ST, Per), ( Per == 3 -> Aux = "does not" ; Aux = "do not" ),
    object_text(O, OT),
    (   OT == "" -> format(string(S), "~w ~w ~w", [ST, Aux, V]) ; format(string(S), "~w ~w ~w ~w", [ST, Aux, V, OT]) ).
realize(eq(A, B), S) :- !, format(string(S), "~w = ~w", [A, B]).
realize(and(A, B), S) :- !, realize(A, SA), realize(B, SB), format(string(S), "~w and ~w", [SA, SB]).
realize(or(A, B), S) :- !, realize(A, SA), realize(B, SB), format(string(S), "~w or ~w", [SA, SB]).
realize(not(P), S) :- !, realize(P, SP), format(string(S), "it is not the case that ~w", [SP]).
realize(all(C, P), S) :- !,
    plural_phrase(C, Cs),
    (   atom_concat('can ', V, P) -> format(string(S), "all ~w can ~w", [Cs, V])
    ;   class_pred_text(P, PT), format(string(S), "all ~w are ~w", [Cs, PT])
    ).
realize(none(C, P), S) :- !,
    plural_phrase(C, Cs),
    (   atom_concat('can ', V, P) -> format(string(S), "no ~w can ~w", [Cs, V])
    ;   class_pred_text(P, PT), format(string(S), "no ~w are ~w", [Cs, PT])
    ).
realize(law(A, B), S) :- !, realize(A, SA), realize(B, SB), format(string(S), "if ~w then ~w", [SA, SB]).
realize(X, S) :- format(string(S), "~w", [X]).

subject_text(user, "you", 2) :- !.
subject_text(newos, "I", 1) :- !.
subject_text(E, T, 3) :- np_display(E, T).

np_display(E, T) :- atom(E), atom_concat('my ', X, E), !, format(string(T), "your ~w", [X]).
np_display(E, T) :- atom(E), atom_concat('your ', X, E), !, format(string(T), "my ~w", [X]).
np_display(user, "you") :- !.
np_display(newos, "me") :- !.
np_display(E, T) :- shown_as(E, O), !, atom_string(O, T).
np_display(E, T) :- uses_the(E), !, format(string(T), "the ~w", [E]).
np_display(E, T) :- format(string(T), "~w", [E]).

object_text(none, "") :- !.
object_text(E, T) :- uses_article(E), \+ uses_the(E), !, article(E, A), format(string(T), "~w ~w", [A, E]).
object_text(E, T) :- np_display(E, T).

pred_text(P, T) :-
    (   atom_concat('can ', _, P) -> format(string(T), "~w", [P])
    ;   uses_article(P) -> article(P, A), word_display(P, D), format(string(T), "~w ~w", [A, D])
    ;   word_display(P, T)
    ).

word_display(P, T) :- ( shown_as(P, O) -> atom_string(O, T) ; format(string(T), "~w", [P]) ).

class_pred_text(P, T) :-
    (   uses_article(P) -> plural_phrase(P, Ps), format(string(T), "~w", [Ps])
    ;   format(string(T), "~w", [P])
    ).

copula(1, "am").
copula(2, "are").
copula(3, "is").

verb_form(3, V, T) :- !, third_person(V, T).
verb_form(_, V, V).

plural_phrase(A, P) :-
    atomic_list_concat(Parts, ' ', A),
    append(Front, [Last], Parts), !,
    plural(Last, PL),
    append(Front, [PL], Parts1),
    atomic_list_concat(Parts1, ' ', P).
plural_phrase(A, A).

singular_phrase(A, S) :-
    atomic_list_concat(Parts, ' ', A),
    append(Front, [Last], Parts), !,
    singular(Last, SL),
    append(Front, [SL], Parts1),
    atomic_list_concat(Parts1, ' ', S).

and_list([], "nothing") :- !.
and_list([X], S) :- !, format(string(S), "~w", [X]).
and_list(Xs, S) :-
    append(Front, [Last], Xs),
    atomic_list_concat(Front, ', ', F),
    format(string(S), "~w and ~w", [F, Last]).

capitalize(S0, S) :-
    (   string_concat(F, Rest, S0), string_length(F, 1)
    ->  string_upper(F, FU), string_concat(FU, Rest, S)
    ;   S = S0
    ).

%   ---- explanations --------------------------------------------------------------------

explain(fact(actual, P), T) :- !, realize(P, S), format(string(T), "you told me that ~w", [S]).
explain(fact(W, P), T) :- !, realize(P, S), format(string(T), "in world ~w, ~w", [W, S]).
explain(inherited(W, P), T) :- !, realize(P, S), format(string(T), "~w in the actual world, and world ~w doesn't say otherwise", [S, W]).
explain(inherited_not(W, P), T) :- !, realize(not(P), S), format(string(T), "~w in the actual world, and world ~w doesn't say otherwise", [S, W]).
explain(nfact(actual, P), T) :- !, realize(not(P), S), format(string(T), "you told me that ~w", [S]).
explain(nfact(W, P), T) :- !, realize(not(P), S), format(string(T), "in world ~w, ~w", [W, S]).
explain(by_rule(all(C1, C2), X, Sub), T) :- !,
    explain(Sub, ST), realize(all(C1, C2), RT), realize(is(X, C2), Concl),
    format(string(T), "~w, and ~w, so ~w", [ST, RT, Concl]).
explain(by_rule(none(C1, C2), X, Sub), T) :- !,
    explain(Sub, ST), realize(none(C1, C2), RT), realize(not(is(X, C2)), Concl),
    format(string(T), "~w, and ~w, so ~w", [ST, RT, Concl]).
explain(by_law(A, B, Sub), T) :- !,
    explain(Sub, ST), realize(law(A, B), LT),
    format(string(T), "~w, and ~w", [ST, LT]).
explain(math(eq(A, B)), T) :- !, V is A, format(string(T), "~w and ~w both come to ~w", [A, B, V]).
explain(math(neq(A, B)), T) :- !, X is A, Y is B, format(string(T), "~w comes to ~w but ~w is ~w", [A, X, B, Y]).
explain(both(P1, P2), T) :- !, explain(P1, T1), explain(P2, T2), format(string(T), "~w; and ~w", [T1, T2]).
explain(assumed(not(P)), T) :- !, realize(not(P), S), format(string(T), "we're supposing that ~w", [S]).
explain(assumed(P), T) :- !, realize(P, S), format(string(T), "we're supposing that ~w", [S]).
explain(X, T) :- format(string(T), "~w", [X]).

%   ---- summaries for the side panel and "what do you know" -------------------------------

summary_text(R) :-
    aggregate_all(count, fact(actual, _), NF),
    aggregate_all(count, rule(_), NR),
    aggregate_all(count, law(_, _), NL),
    aggregate_all(count, world(_), NW),
    aggregate_all(count, word(_, _, _, taught), NT),
    aggregate_all(count, word(_, _, _, learned), NLe),
    aggregate_all(count, pattern(_, _), NP),
    aggregate_all(count, vfs_file(_, _, _), NFi),
    findall(S, ( fact(actual, P), P \= is(newos, _), realize(P, S0), capitalize(S0, S) ), Ss0),
    take(6, Ss0, Ss),
    (   Ss == [] -> Ex = "" ; atomic_list_concat(Ss, '. ', E), format(string(Ex), " For example: ~w.", [E]) ),
    maplist(plural_s, [NF, NR, NL, NW, NT, NFi], [S1, S2, S3, S4, S5, S6]),
    is_are(NFi, IA),
    format(string(R), "I know ~d fact~a, ~d general rule~a and ~d \"if\" law~a, across the actual world and ~d imagined world~a. My dictionary has ~d word~a you taught me and ~d I picked up from our chats, and I've learned ~d replies. There ~a ~d file~a.~w",
           [NF, S1, NR, S2, NL, S3, NW, S4, NT, S5, NLe, NP, IA, NFi, S6, Ex]).

is_are(1, is) :- !.
is_are(_, are).

take(N, L, F) :- length(L, Len), ( Len =< N -> F = L ; length(F, N), append(F, _, L) ).

worlds_text(R) :-
    all_worlds(Ws),
    maplist([W, T]>>( world_distance(W, D), world_weight(W, Pr),
                      aggregate_all(count, fact(W, _), N1), aggregate_all(count, nfact(W, _), N2), N is N1 + N2,
                      world_name(W, WN), plural_s(N, Sf),
                      format(string(T), "\u2022 ~w: distance ~w, weight ~w, ~d own fact~a", [WN, D, Pr, N, Sf]) ),
            Ws, Ts),
    atomic_list_concat(Ts, '\n', A),
    format(string(R), "Worlds I know:\n~w", [A]).

world_text(W, R) :-
    findall(S, ( fact(W, P), realize(P, S) ), S1),
    findall(S, ( nfact(W, P), realize(not(P), S) ), S2),
    append(S1, S2, Ss),
    (   Ss == [] -> format(string(R), "World ~w only has what's true in the actual world.", [W])
    ;   atomic_list_concat(Ss, '; ', A), format(string(R), "In world ~w: ~w.", [W, A])
    ).

state_json(J) :-
    semantics(S),
    findall(T, ( fact(actual, P), realize(P, T0), capitalize(T0, T) ), Facts1),
    findall(T, ( nfact(actual, P), realize(not(P), T0), capitalize(T0, T) ), Facts2),
    append(Facts1, Facts2, Facts),
    findall(T, ( rule(R), realize(R, T0), capitalize(T0, T) ), Rules),
    findall(T, ( law(A, B), realize(law(A, B), T0), capitalize(T0, T) ), Laws),
    all_worlds(Ws),
    findall(_{name:W, distance:D, weight:Pr, facts:WF},
            ( member(W, Ws), W \== actual, world_distance(W, D), world_weight(W, Pr),
              findall(T, ( ( fact(W, P), realize(P, T) ) ; ( nfact(W, P), realize(not(P), T) ) ), WF) ),
            Worlds),
    findall(_{word:W, pos:P, meaning:D, source:Src}, ( word(W, P, D, Src), Src \== seed ), Words),
    findall(_{folder:F, name:N}, vfs_file(F, N, _), Files),
    findall(_{when:K, say:Rep}, ( pattern(K0, Rep), atomic_list_concat(K0, ' ', K) ), Patterns),
    vfs_cwd(Cwd),
    pending_flag(Pend),
    J = _{ semantics:S, facts:Facts, rules:Rules, laws:Laws, worlds:Worlds,
           words:Words, files:Files, replies:Patterns, cwd:Cwd, pending:Pend }.

%   ---- tokenizer ---------------------------------------------------------------------------

%!  tokenize(+Text, -Lower, -Original) is det.
%   Lower and Original are parallel lists.  Words are atoms, numbers are
%   numbers, "quoted text" is q(String), punctuation is a one-char atom.
tokenize(Text, Lower, Orig) :-
    (   string(Text) -> T = Text ; atom_string(Text, T) ),
    string_codes(T, Cs0),
    maplist(normalize_code, Cs0, Cs),
    (   phrase(toks(O0), Cs) -> true ; O0 = [] ),
    contractions(O0, O1),
    exclude([X]>>memberchk(X, [':', ';', '"', '\'', '`']), O1, Orig),
    maplist(lower_tok, Orig, Lower).

normalize_code(0x2019, 0'\') :- !.
normalize_code(0x2018, 0'\') :- !.
normalize_code(0x2014, 0'-) :- !.
normalize_code(C, C).

lower_tok(T, L) :- atom(T), !, downcase_atom(T, L).
lower_tok(T, T).

toks(Ts) --> ws, toks1(Ts).
toks1([T|Ts]) --> tok(T), !, ws, toks1(Ts).
toks1([]) --> [].

ws --> [C], { code_type(C, space) }, !, ws.
ws --> [].

tok(q(S)) --> [Open], { quote_pair(Open, Close) }, qchars(Cs, Close), { string_codes(S, Cs) }.
tok(N) --> digits1(I), [0'.], digits1(F), !, { append(I, [0'.|F], All), number_codes(N, All) }.
tok(N) --> digits1(D), !, { number_codes(N, D) }.
tok(W) --> [C], { code_type(C, csymf) }, wchars(Cs), !, { atom_codes(W, [C|Cs]) }.
tok(P) --> [C], { \+ code_type(C, space), atom_codes(P, [C]) }.

quote_pair(0'", 0'").
quote_pair(0x201C, 0x201D).

qchars([], Close) --> [Close], !.
qchars([C|Cs], Close) --> [C], qchars(Cs, Close).

digits1([D|Ds]) --> [D], { code_type(D, digit) }, digits0(Ds).
digits0([D|Ds]) --> [D], { code_type(D, digit) }, !, digits0(Ds).
digits0([]) --> [].

wchars([C|Cs]) --> [C], { code_type(C, csym) }, !, wchars(Cs).
wchars([]) --> [].

%   it's -> it is, don't -> do not, I'm -> I am, ...
contractions([], []).
contractions([X, '\'', S|T], Out) :-
    atom(X), atom(S), downcase_atom(S, SL), downcase_atom(X, XL),
    contraction(XL, X, SL, Repl), !,
    append(Repl, T1, Out),
    contractions(T, T1).
contractions([H|T], [H|T1]) :- contractions(T, T1).

contraction(XL, X, s, [X, is]) :- memberchk(XL, [what, who, it, that, there, he, she, where, how, here, this]), !.
contraction(_, X, s, [X]) :- !.                       % possessive: John's -> John
contraction(_, X, m, [X, am]) :- !.
contraction(_, X, re, [X, are]) :- !.
contraction(_, X, ll, [X, will]) :- !.
contraction(_, X, ve, [X, have]) :- !.
contraction(_, X, d, [X, would]) :- !.
contraction(can, X, t, [X, not]) :- !.
contraction(won, _, t, [will, not]) :- !.
contraction(XL, X, t, [B, not]) :-
    atom_concat(BL, n, XL), BL \== '', !,
    sub_atom(X, 0, _, 1, B0), ( B0 == '' -> B = BL ; B = B0 ).

no_commas(L0, L) :- exclude(==(','), L0, L).

strip_det([D|T], T) :- memberchk(D, [the, a, an]), !.
strip_det(T, T).

%   rest_text(+Lower, +Orig, +Prefix, -Text): the original words after Prefix
rest_text(L, O, Prefix, Text) :-
    no_commas(L, LC),
    append(Prefix, _, LC),
    length(Prefix, N),
    no_commas_count(L, N, K),
    length(Pre, K), append(Pre, Tail, O),
    join_tokens(Tail, Text).

join_tokens(Ts, S) :- foldl(join_tok, Ts, "", S).

join_tok(T, Acc, Out) :-
    tok_text(T, X),
    (   Acc == "" -> Out = X
    ;   no_space_before(T) -> string_concat(Acc, X, Out)
    ;   atomics_to_string([Acc, " ", X], Out)
    ).

tok_text(q(S), S) :- !.
tok_text(T, S) :- format(string(S), "~w", [T]).

no_space_before(T) :- memberchk(T, ['.', ',', '!', '?', ')']).

sentences(L, O, Ss) :- sentences_(L, O, [], [], Ss).

sentences_([], [], AccL, AccO, Ss) :- !,
    (   AccL == [] -> Ss = []
    ;   reverse(AccL, L), reverse(AccO, O), Ss = [s(L, O, '.')]
    ).
sentences_([T|Ts], [OT|OTs], AccL, AccO, Ss) :-
    (   memberchk(T, ['.', '!', '?'])
    ->  (   AccL == [] -> Ss = Ss1
        ;   reverse(AccL, L), reverse(AccO, O), Ss = [s(L, O, T)|Ss1]
        ),
        sentences_(Ts, OTs, [], [], Ss1)
    ;   sentences_(Ts, OTs, [T|AccL], [OT|AccO], Ss)
    ).

%   ---- saving and loading --------------------------------------------------------------------

kb_save :-
    kb_file(F),
    file_directory_name(F, Dir),
    make_directory_path(Dir),
    kb_terms(Terms),
    setup_call_cleanup(
        open(F, write, Out, [encoding(utf8)]),
        ( format(Out, "% newos knowledge base: dictionary, logic, worlds, replies and files.~n", []),
          format(Out, "% You can edit this file; newos reads it back with read_term/2 (nothing is executed).~n~n", []),
          forall(member(T, Terms), portray_clause(Out, T))
        ),
        close(Out)).

kb_terms(Terms) :-
    dictionary_terms(D),
    logic_terms(L),
    vfs_terms(V),
    findall(pattern(K, R), pattern(K, R), P),
    findall(user_name(N), user_name(N), U),
    findall(asked_about(W), asked_about(W), A),
    append([D, L, V, P, U, A], Terms).

kb_load :-
    kb_file(F),
    (   exists_file(F)
    ->  setup_call_cleanup(open(F, read, In, [encoding(utf8)]),
                           read_all(In, Terms),
                           close(In)),
        load_terms(Terms, _)
    ;   true
    ).

kb_export(Text) :-
    kb_save,
    kb_file(F),
    read_file_to_string(F, Text, [encoding(utf8)]).

%!  kb_import_string(+Text, -Count) is det.
kb_import_string(Text, N) :-
    setup_call_cleanup(open_string(Text, In),
                       read_all(In, Terms),
                       close(In)),
    load_terms(Terms, N),
    kb_save.

read_all(In, Terms) :-
    catch(read_term(In, T, []), _, T = '$skip'),
    (   T == end_of_file -> Terms = []
    ;   Terms = [T|Rest], read_all(In, Rest)
    ).

load_terms(Terms, N) :-
    foldl(load_one, Terms, 0, N).

load_one(T, N0, N) :-
    (   catch(load_term(T), _, fail) -> N is N0 + 1 ; N = N0 ).

load_term(pattern(K, R)) :- !, is_list(K), ( string(R) -> R1 = R ; atom_string(R, R1) ), add_pattern(K, R1).
load_term(user_name(N)) :- !, atom(N), retractall(user_name(_)), assertz(user_name(N)).
load_term(asked_about(W)) :- !, atom(W), ( asked_about(W) -> true ; assertz(asked_about(W)) ).
load_term(T) :- dictionary_load_term(T), !.
load_term(T) :- logic_load_term(T), !.
load_term(T) :- vfs_load_term(T), !.

kb_reset :-
    dictionary_clear,
    logic_clear,
    vfs_clear,
    retractall(pattern(_, _)),
    retractall(pending(_)),
    retractall(last_entity(_)),
    retractall(last_answer(_, _, _)),
    retractall(user_name(_)),
    retractall(asked_about(_)),
    retractall(last_ask_turn(_)),
    seed_dictionary,
    seed_knowledge,
    kb_save.
