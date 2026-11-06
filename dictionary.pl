/*  dictionary.pl - the savable, growing dictionary of newos

    word(Word, PartOfSpeech, Definition, Source)
      Source is seed (built in), learned (met in conversation, meaning
      not yet known) or taught (the user gave a meaning).

    Also: shown_as(Lower, Original) remembers how a name is written,
    uses_article(Noun) remembers that the user said "a/an Noun",
    uses_the(Noun) remembers that the user said "the Noun".
*/

:- module(dictionary,
          [ word/4,
            known_word/1,
            learn_word/2,
            define_word/2,
            word_meaning/2,
            function_word/1,
            number_word/2,
            plural/2,
            singular/2,
            base_verb/2,
            third_person/2,
            article/2,
            shown_as/2,
            remember_shown_as/2,
            uses_article/1,
            uses_the/1,
            note_article/1,
            note_the/1,
            dictionary_terms/1,
            dictionary_load_term/1,
            dictionary_clear/0,
            seed_dictionary/0
          ]).

:- dynamic word/4, shown_as/2, uses_article/1, uses_the/1.

%   ---- closed-class words -------------------------------------------------

function_word(W) :- memberchk(W,
    [ a, an, the, some, any, all, every, each, no, not, is, are, am, was, were,
      be, been, do, does, did, can, cannot, could, will, would, should, must,
      may, might, and, or, but, if, then, else, that, this, these, those, of,
      in, on, at, to, from, by, with, for, about, as, into, than, so, too,
      i, me, my, mine, you, your, yours, he, him, his, she, her, hers, it,
      its, we, us, our, they, them, their, what, who, whom, which, why, how,
      where, when, there, here, yes, true, false, very, also, just, please
    ]).

number_word(zero, 0).  number_word(one, 1).   number_word(two, 2).
number_word(three, 3). number_word(four, 4).  number_word(five, 5).
number_word(six, 6).   number_word(seven, 7). number_word(eight, 8).
number_word(nine, 9).  number_word(ten, 10).  number_word(eleven, 11).
number_word(twelve, 12). number_word(twenty, 20). number_word(hundred, 100).

%   ---- seed vocabulary ----------------------------------------------------

seed(sky, noun, "the space above the earth, seen from the ground").
seed(moon, noun, "the natural satellite that circles the earth").
seed(sun, noun, "the star the earth travels around").
seed(earth, noun, "the planet we live on").
seed(cheese, noun, "a food made from milk").
seed(milk, noun, "a white drink that mammals make for their young").
seed(water, noun, "a clear liquid that falls as rain").
seed(food, noun, "something people or animals eat").
seed(bird, noun, "an animal with feathers and wings").
seed(fish, noun, "an animal that lives and swims in water").
seed(cat, noun, "a small furry animal often kept as a pet").
seed(dog, noun, "an animal often kept as a pet or for work").
seed(animal, noun, "a living thing that can move and eat").
seed(man, noun, "an adult male person").
seed(woman, noun, "an adult female person").
seed(person, noun, "a human being").
seed(friend, noun, "someone you like and trust").
seed(file, noun, "a named piece of saved writing").
seed(folder, noun, "a named place that holds files").
seed(diary, noun, "a book or file of dated personal entries").
seed(world, noun, "a whole way things could be").
seed(chatbot, noun, "a program you talk with").
seed(blue, adjective, "the colour of a clear sky").
seed(red, adjective, "the colour of blood").
seed(green, adjective, "the colour of grass").
seed(wet, adjective, "covered in water").
seed(happy, adjective, "feeling good").
seed(sad, adjective, "feeling unhappy").
seed(big, adjective, "large in size").
seed(small, adjective, "little in size").
seed(mortal, adjective, "certain to die some day").
seed(edible, adjective, "safe to eat").
seed(healthy, adjective, "in good health").
seed(good, adjective, "of a high standard, or kind").
seed(like, verb, "to enjoy or be fond of").
seed(love, verb, "to like very much").
seed(have, verb, "to own or hold").
seed(eat, verb, "to take food into the mouth and swallow it").
seed(fly, verb, "to move through the air").
seed(swim, verb, "to move through water").
seed(rain, verb, "to fall as water from the clouds").
seed(know, verb, "to have information in the mind").
seed(see, verb, "to notice with the eyes").
seed(feel, verb, "to sense or experience").
seed(open, verb, "to show what is in a file").
seed(save, verb, "to keep something for later").
seed(search, verb, "to look for something").

seed_dictionary :-
    forall(seed(W, P, D), ( word(W, _, _, _) -> true ; assertz(word(W, P, D, seed)) )).

dictionary_clear :-
    retractall(word(_, _, _, _)),
    retractall(shown_as(_, _)),
    retractall(uses_article(_)),
    retractall(uses_the(_)).

known_word(W) :- function_word(W), !.
known_word(W) :- number(W), !.
known_word(W) :- number_word(W, _), !.
known_word(W) :- word(W, _, _, _), !.
known_word(W) :- singular(W, S), S \== W, word(S, _, _, _), !.
known_word(W) :- base_verb(W, B), B \== W, word(B, _, _, _).

%!  learn_word(+Word, +PartOfSpeech) is det.
%   Note a word met in conversation.  Returns silently if already known.
learn_word(W, _) :- known_word(W), !.
learn_word(W, _) :- \+ atom(W), !.
learn_word(W, P) :- assertz(word(W, P, "", learned)).

%!  define_word(+Word, +Definition) is det.
define_word(W, D) :-
    (   retract(word(W, P, _, _)) -> true ; P = unknown ),
    assertz(word(W, P, D, taught)).

%!  word_meaning(+Word, -Definition) is semidet.
word_meaning(W, D) :-
    (   word(W, _, D, _), D \== ""
    ->  true
    ;   singular(W, S), S \== W, word(S, _, D, _), D \== ""
    ).

%   ---- names and articles --------------------------------------------------

remember_shown_as(Lower, Orig) :-
    (   shown_as(Lower, Orig) -> true
    ;   retractall(shown_as(Lower, _)),
        assertz(shown_as(Lower, Orig))
    ).

note_article(N) :- ( uses_article(N) -> true ; assertz(uses_article(N)) ).
note_the(N)     :- ( uses_the(N) -> true ; assertz(uses_the(N)) ).

article(W, A) :-
    atom_chars(W, [C|_]),
    (   memberchk(C, [a, e, i, o, u]) -> A = an ; A = a ).

%   ---- inflection -----------------------------------------------------------

irregular(man, men).        irregular(woman, women).   irregular(child, children).
irregular(person, people).  irregular(mouse, mice).    irregular(foot, feet).
irregular(tooth, teeth).    irregular(goose, geese).   irregular(fish, fish).
irregular(sheep, sheep).    irregular(deer, deer).     irregular(ox, oxen).

plural(S, P) :- irregular(S, P), !.
plural(S, P) :- atom_concat(B, y, S), B \== '', \+ ends_in_vowel(B), !, atom_concat(B, ies, P).
plural(S, P) :-
    member(E, [s, x, z, ch, sh]), atom_concat(_, E, S), !,
    atom_concat(S, es, P).
plural(S, P) :- atom_concat(S, s, P).

ends_in_vowel(A) :- sub_atom(A, _, 1, 0, C), memberchk(C, [a, e, i, o, u]).

%   singular/2 never strips the s of words such as "glass", "bus", "famous".
singular(P, S) :- irregular(S, P), !.
singular(P, S) :- atom_concat(B, ies, P), atom_length(B, L), L > 1, !, atom_concat(B, y, S).
singular(P, S) :-
    member(E, [ches, shes, xes, sses, zes]), atom_concat(_, E, P), !,
    atom_concat(S, es, P).
singular(P, P) :-
    member(E, [ss, us, is, ous]), atom_concat(_, E, P), !.
singular(P, S) :- atom_concat(S, s, P), atom_length(S, L), L > 1, !.
singular(P, P).

base_verb(has, have) :- !.
base_verb(does, do) :- !.
base_verb(is, be) :- !.
base_verb(V, B) :- atom_concat(X, ies, V), atom_length(X, L), L > 1, !, atom_concat(X, y, B).
base_verb(V, B) :-
    member(E, [ches, shes, xes, sses, oes, zes]), atom_concat(_, E, V), !,
    atom_concat(B, es, V).
base_verb(V, V) :- member(E, [ss, us, is]), atom_concat(_, E, V), !.
base_verb(V, B) :- atom_concat(B, s, V), atom_length(B, L), L > 1, !.
base_verb(V, V).

third_person(have, has) :- !.
third_person(do, does) :- !.
third_person(be, is) :- !.
third_person(go, goes) :- !.
third_person(V, T) :- atom_concat(B, y, V), B \== '', \+ ends_in_vowel(B), !, atom_concat(B, ies, T).
third_person(V, T) :-
    member(E, [s, x, z, ch, sh, o]), atom_concat(_, E, V), !,
    atom_concat(V, es, T).
third_person(V, T) :- atom_concat(V, s, T).

%   ---- saving ---------------------------------------------------------------

dictionary_terms(Terms) :-
    findall(word(W, P, D, S), ( word(W, P, D, S), S \== seed ), Ws),
    findall(shown_as(L, O), shown_as(L, O), Ss),
    findall(uses_article(N), uses_article(N), As),
    findall(uses_the(N), uses_the(N), Ts),
    append([Ws, Ss, As, Ts], Terms).

dictionary_load_term(word(W, P, D, S)) :- !,
    atom(W), atom(P), ( string(D) -> D1 = D ; atom_string(D, D1) ),
    retractall(word(W, _, _, _)),
    assertz(word(W, P, D1, S)).
dictionary_load_term(shown_as(L, O)) :- !, atom(L), atom(O), remember_shown_as(L, O).
dictionary_load_term(uses_article(N)) :- !, atom(N), note_article(N).
dictionary_load_term(uses_the(N)) :- !, atom(N), note_the(N).
