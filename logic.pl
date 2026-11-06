/*  logic.pl - the savable knowledge base and the semantics of "if"

    Propositions
      is(Subject, Predicate)      "the moon is cheese", "tweety can fly"
      rel(Verb, Subject, Object)  "john likes mary"
      eq(Expr1, Expr2)            "2+2=4"
      and(A, B), or(A, B), not(A)

    Knowledge
      fact(World, P)      P holds in World (actual is the real world)
      nfact(World, P)     P is false in World
      rule(all(C, P))     every C is P          rule(none(C, P))  no C is P
      law(A, B)           "if A then B" as a rule that holds in every world
      world(W), distance(W, D), weight(W, Pr)

    Truth uses the closed-world assumption for conditionals: whatever
    cannot be proved in a world counts as false there.  Laws and
    arithmetic hold in every world.  Other worlds inherit the actual
    world's facts unless they say otherwise.

    Semantics for "if A then B" (see evaluate/4):
      material    true unless A is true and B false in the actual world
      strict      B holds in every world where A holds
      relevance   A and B share content, and B follows from A
      lewis       B holds in all the closest A-worlds (counterfactuals)
      stalnaker   B holds in the single closest A-world
      adams       the probability of B given A (Adams's thesis)
*/

:- module(logic,
          [ fact/2, nfact/2, rule/1, law/2, world/1,
            add_fact/3,
            add_rule/1,
            add_law/2,
            add_world/1,
            set_distance/2,
            set_weight/2,
            world_distance/2,
            world_weight/2,
            all_worlds/1,
            prove/5,
            refute/5,
            truth/4,
            holds_cwa/2,
            evaluate/4,
            semantics/1,
            semantics_name/2,
            set_semantics/1,
            content_words/2,
            forget_about/2,
            logic_terms/1,
            logic_load_term/1,
            logic_clear/0
          ]).

:- dynamic fact/2, nfact/2, rule/1, law/2, world/1, distance/2, weight/2, semantics_/1.

max_depth(8).

semantics_name(material,  "material conditional").
semantics_name(strict,    "strict conditional (modal logic)").
semantics_name(relevance, "relevance logic").
semantics_name(lewis,     "Lewis closest-worlds semantics").
semantics_name(stalnaker, "Stalnaker closest-world semantics").
semantics_name(adams,     "Adams's probabilistic account").

semantics(S) :- ( semantics_(S0) -> S = S0 ; S = material ).

set_semantics(S) :-
    semantics_name(S, _),
    retractall(semantics_(_)),
    assertz(semantics_(S)).

%   ---- adding knowledge ----------------------------------------------------

%!  add_fact(+World, +Prop, +Polarity) is det.
add_fact(W, and(A, B), Pol) :- !, add_fact(W, A, Pol), add_fact(W, B, Pol).
add_fact(W, not(P), Pol) :- !, flip(Pol, Pol1), add_fact(W, P, Pol1).
add_fact(W, P, true) :- !,
    add_world(W),
    retractall(nfact(W, P)),
    ( fact(W, P) -> true ; assertz(fact(W, P)) ).
add_fact(W, P, false) :-
    add_world(W),
    retractall(fact(W, P)),
    ( nfact(W, P) -> true ; assertz(nfact(W, P)) ).

flip(true, false).
flip(false, true).

add_rule(R) :- ( rule(R) -> true ; assertz(rule(R)) ).
add_law(A, B) :- ( law(A, B) -> true ; assertz(law(A, B)) ).

add_world(actual) :- !.
add_world(W) :- ( world(W) -> true ; assertz(world(W)) ).

set_distance(W, D) :- add_world(W), retractall(distance(W, _)), assertz(distance(W, D)).
set_weight(W, P)   :- ( W \== actual -> add_world(W) ; true ), retractall(weight(W, _)), assertz(weight(W, P)).

world_distance(actual, 0) :- !.
world_distance(W, D) :- ( distance(W, D0) -> D = D0 ; D = 1 ).

world_weight(W, P) :- ( weight(W, P0) -> P = P0 ; P = 1 ).

all_worlds([actual|Ws]) :- findall(W, world(W), Ws).

%!  forget_about(+Entity, -Count) is det.
forget_about(E, N) :-
    findall(x, ( fact(W, P), mentions(P, E), retract(fact(W, P)) ), L1),
    findall(x, ( nfact(W, P), mentions(P, E), retract(nfact(W, P)) ), L2),
    findall(x, ( rule(R), R =.. [_, A, B], ( A == E ; B == E ), retract(rule(R)) ), L3),
    length(L1, N1), length(L2, N2), length(L3, N3),
    N is N1 + N2 + N3.

mentions(P, E) :- sub_term(X, P), X == E, !.

%   ---- proof ---------------------------------------------------------------

%!  prove(+World, +Assumed, +Prop, +Depth, -Proof) is semidet.
prove(_, Ass, P, _, assumed(P)) :- memberchk(P, Ass), !.
prove(_, _, eq(A, B), _, math(eq(A, B))) :- !,
    catch(( X is A, Y is B, X =:= Y ), _, fail).
prove(W, Ass, and(A, B), D, both(PA, PB)) :- !,
    prove(W, Ass, A, D, PA),
    prove(W, Ass, B, D, PB).
prove(W, Ass, or(A, B), D, P) :- !,
    (   prove(W, Ass, A, D, P) -> true ; prove(W, Ass, B, D, P) ).
prove(W, Ass, not(A), D, P) :- !,
    refute(W, Ass, A, D, P).
prove(W, _, P, _, fact(W, P)) :- fact(W, P), !.
prove(W, _, P, _, inherited(W, P)) :-
    W \== actual, fact(actual, P), \+ nfact(W, P), !.
prove(W, Ass, is(X, C2), D, by_rule(all(C1, C2), X, Sub)) :-
    D > 0, rule(all(C1, C2)), C1 \== C2,
    D1 is D - 1,
    prove(W, Ass, is(X, C1), D1, Sub), !.
prove(W, Ass, B, D, by_law(A, B, Sub)) :-
    D > 0, law(A, B),
    D1 is D - 1,
    prove(W, Ass, A, D1, Sub), !.

%!  refute(+World, +Assumed, +Prop, +Depth, -Proof) is semidet.
refute(_, _, eq(A, B), _, math(neq(A, B))) :- !,
    catch(( X is A, Y is B, X =\= Y ), _, fail).
refute(W, Ass, and(A, B), D, P) :- !,
    (   refute(W, Ass, A, D, P) -> true ; refute(W, Ass, B, D, P) ).
refute(W, Ass, or(A, B), D, both(PA, PB)) :- !,
    refute(W, Ass, A, D, PA),
    refute(W, Ass, B, D, PB).
refute(W, Ass, not(A), D, P) :- !,
    prove(W, Ass, A, D, P).
refute(_, Ass, P, _, assumed(not(P))) :- memberchk(not(P), Ass), !.
refute(W, _, P, _, nfact(W, P)) :- nfact(W, P), !.
refute(W, _, P, _, inherited_not(W, P)) :-
    W \== actual, nfact(actual, P), \+ fact(W, P), !.
refute(W, Ass, is(X, C2), D, by_rule(none(C1, C2), X, Sub)) :-
    D > 0, rule(none(C1, C2)),
    D1 is D - 1,
    prove(W, Ass, is(X, C1), D1, Sub), !.

%!  truth(+World, +Prop, -Value, -Proof) is det.
%   Value is true, false or unknown.
truth(W, P, V, Proof) :-
    max_depth(D),
    (   prove(W, [], P, D, Proof) -> V = true
    ;   refute(W, [], P, D, Proof) -> V = false
    ;   V = unknown, Proof = none
    ).

%!  holds_cwa(+World, +Prop) is semidet.
%   Closed world: true only if it can be proved.
holds_cwa(W, P) :-
    max_depth(D),
    prove(W, [], P, D, _).

%   ---- the semantics of "if" -----------------------------------------------

%!  evaluate(+Semantics, +A, +B, -Result) is det.
%   Result = result(Value, Notes).  Value is true, false, indeterminate,
%   undefined or prob(P).  Notes are terms the language layer turns into
%   English (see nl_engine:say_note/2).

evaluate(material, A, B, result(V, Notes)) :-
    tv(actual, A, TA),
    tv(actual, B, TB),
    (   TA == true, TB == false -> V = false ; V = true ),
    Notes0 = [value_in(actual, A, TA), value_in(actual, B, TB), material_rule],
    (   V == true, TA == false
    ->  Notes1 = [paradox(false_antecedent)]
    ;   V == true, TB == true, \+ shares_content(A, B)
    ->  Notes1 = [paradox(true_consequent)]
    ;   Notes1 = []
    ),
    append(Notes0, Notes1, Notes).

evaluate(strict, A, B, result(V, Notes)) :-
    all_worlds(Ws),
    include(A/[W]>>holds_cwa(W, A), Ws, AWs),
    (   AWs == []
    ->  V = true,
        Notes0 = [no_a_world(A), vacuous(strict)]
    ;   exclude(B/[W]>>holds_cwa(W, B), AWs, Bad),
        (   Bad == []
        ->  V = true, Notes0 = [a_worlds(AWs), b_in_all(B)]
        ;   V = false, Notes0 = [a_worlds(AWs), counter_worlds(Bad, B)]
        )
    ),
    (   V == true, forall(member(W, Ws), holds_cwa(W, B)), \+ shares_content(A, B)
    ->  append(Notes0, [necessary(B), paradox(strict)], Notes)
    ;   Notes = Notes0
    ),
    !.

evaluate(relevance, A, B, result(V, Notes)) :-
    content_words(A, CA),
    content_words(B, CB),
    intersection(CA, CB, Shared),
    max_depth(D),
    (   Shared == []
    ->  V = false, Notes = [no_shared_content(CA, CB)]
    ;   prove(actual, [A], B, D, Proof)
    ->  V = true, Notes = [shared(Shared), follows(Proof)]
    ;   V = false, Notes = [shared(Shared), does_not_follow(A, B)]
    ).

evaluate(lewis, A, B, result(V, Notes)) :-
    closest_a_worlds(A, Closest, Dist),
    (   Closest == []
    ->  V = true, Notes = [no_a_world(A), vacuous(lewis)]
    ;   exclude(B/[W]>>holds_cwa(W, B), Closest, Bad),
        (   Bad == []
        ->  V = true, Notes = [closest(Closest, Dist), b_in_all(B)]
        ;   V = false, Notes = [closest(Closest, Dist), counter_worlds(Bad, B)]
        )
    ).

evaluate(stalnaker, A, B, result(V, Notes)) :-
    closest_a_worlds(A, Closest, Dist),
    (   Closest == []
    ->  V = true, Notes = [no_a_world(A), vacuous(stalnaker)]
    ;   Closest = [W]
    ->  ( holds_cwa(W, B) -> V = true ; V = false ),
        Notes = [closest([W], Dist), value_in(W, B, V)]
    ;   partition(B/[W]>>holds_cwa(W, B), Closest, Yes, No),
        (   No == [] -> V = true
        ;   Yes == [] -> V = false
        ;   V = indeterminate
        ),
        Notes = [closest(Closest, Dist), tie(Yes, No)]
    ).

evaluate(adams, A, B, result(V, Notes)) :-
    all_worlds(Ws),
    include(A/[W]>>holds_cwa(W, A), Ws, AWs),
    sum_weights(Ws, Total),
    sum_weights(AWs, PA0),
    (   PA0 =:= 0
    ->  V = undefined, Notes = [no_a_world(A), zero_probability]
    ;   include(B/[W]>>holds_cwa(W, B), AWs, ABWs),
        sum_weights(ABWs, PAB0),
        P is PAB0 / PA0,
        PA is PA0 / Total,
        V = prob(P),
        Notes = [probabilities(PA, P, AWs, ABWs)]
    ).

tv(W, P, V) :- ( holds_cwa(W, P) -> V = true ; V = false ).

closest_a_worlds(A, Closest, Min) :-
    all_worlds(Ws),
    findall(D-W, ( member(W, Ws), holds_cwa(W, A), world_distance(W, D) ), Pairs),
    (   Pairs == []
    ->  Closest = [], Min = none
    ;   pairs_keys(Pairs, Ds),
        min_list(Ds, Min),
        findall(W, member(Min-W, Pairs), Closest)
    ).

sum_weights(Ws, Sum) :-
    foldl([W, S0, S]>>( world_weight(W, X), S is S0 + X ), Ws, 0, Sum).

%!  content_words(+Prop, -Words) is det.
%   The non-logical vocabulary of a proposition: the words used for
%   relevance logic's variable-sharing test.
content_words(P, Words) :-
    findall(W, content_word(P, W), Ws0),
    sort(Ws0, Words).

content_word(is(S, P), W) :- ( atom_words_(S, W) ; atom_words_(P, W) ).
content_word(rel(V, S, O), W) :- ( W = V ; atom_words_(S, W) ; atom_words_(O, W) ).
content_word(eq(A, B), W) :- ( expr_number(A, W) ; expr_number(B, W) ).
content_word(and(A, B), W) :- ( content_word(A, W) ; content_word(B, W) ).
content_word(or(A, B), W) :- ( content_word(A, W) ; content_word(B, W) ).
content_word(not(A), W) :- content_word(A, W).

atom_words_(A, W) :-
    atom(A),
    atomic_list_concat(Parts, ' ', A),
    member(W, Parts),
    W \== can, W \== '',
    \+ dictionary:function_word(W).

expr_number(N, N) :- number(N), !.
expr_number(E, N) :- compound(E), E =.. [_|Args], member(A, Args), expr_number(A, N).

shares_content(A, B) :-
    content_words(A, CA), content_words(B, CB),
    member(X, CA), memberchk(X, CB), !.

%   ---- saving ---------------------------------------------------------------

logic_terms(Terms) :-
    findall(fact(W, P), fact(W, P), Fs),
    findall(nfact(W, P), nfact(W, P), Ns),
    findall(rule(R), rule(R), Rs),
    findall(law(A, B), law(A, B), Ls),
    findall(world(W), world(W), Ws),
    findall(distance(W, D), distance(W, D), Ds),
    findall(weight(W, P), weight(W, P), Ps),
    (   semantics_(S) -> Ss = [semantics(S)] ; Ss = [] ),
    append([Fs, Ns, Rs, Ls, Ws, Ds, Ps, Ss], Terms).

logic_load_term(fact(W, P))     :- !, safe_prop(P), atom(W), add_fact(W, P, true).
logic_load_term(nfact(W, P))    :- !, safe_prop(P), atom(W), add_fact(W, P, false).
logic_load_term(rule(R))        :- !, R =.. [Q, A, B], memberchk(Q, [all, none]), atom(A), atom(B), add_rule(R).
logic_load_term(law(A, B))      :- !, safe_prop(A), safe_prop(B), add_law(A, B).
logic_load_term(world(W))       :- !, atom(W), add_world(W).
logic_load_term(distance(W, D)) :- !, atom(W), number(D), set_distance(W, D).
logic_load_term(weight(W, P))   :- !, atom(W), number(P), set_weight(W, P).
logic_load_term(semantics(S))   :- !, atom(S), set_semantics(S).

%   Only plain propositions are accepted from a saved file.
safe_prop(is(S, P))     :- atom(S), atom(P).
safe_prop(rel(V, S, O)) :- atom(V), atom(S), atom(O).
safe_prop(eq(A, B))     :- safe_expr(A), safe_expr(B).
safe_prop(and(A, B))    :- safe_prop(A), safe_prop(B).
safe_prop(or(A, B))     :- safe_prop(A), safe_prop(B).
safe_prop(not(A))       :- safe_prop(A).

safe_expr(N) :- number(N), !.
safe_expr(E) :- compound(E), E =.. [Op, A, B], memberchk(Op, [+, -, *, /]), safe_expr(A), safe_expr(B).

logic_clear :-
    retractall(fact(_, _)), retractall(nfact(_, _)), retractall(rule(_)),
    retractall(law(_, _)), retractall(world(_)), retractall(distance(_, _)),
    retractall(weight(_, _)), retractall(semantics_(_)).
