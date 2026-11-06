/*  vfs.pl - the newos virtual file system

    Two layers:

    1. spec_open/2, spec_write/2, spec_save/2, spec_navigate/2 and
       spec_search/2 follow the examples in specs/newos_spec.pl exactly
       (input A, output B as lists).

    2. A persistent folder/file store the chatbot uses:
         vfs_folder(Folder)
         vfs_file(Folder, Name, Content)
       with a current folder, starting at home.
*/

:- module(vfs,
          [ spec_open/2,
            spec_write/2,
            spec_save/2,
            spec_navigate/2,
            spec_search/2,
            vfs_folder/1,
            vfs_file/3,
            vfs_cwd/1,
            vfs_open/2,
            vfs_save/3,
            vfs_append/3,
            vfs_delete/2,
            vfs_mkdir/1,
            vfs_cd/1,
            vfs_list/2,
            vfs_search/2,
            vfs_diary/2,
            vfs_terms/1,
            vfs_load_term/1,
            vfs_clear/0,
            vfs_init/0
          ]).

:- dynamic vfs_folder/1, vfs_file/3, cwd_/1.

%   ---- the spec's predicates ------------------------------------------------

%!  spec_open(+A, -B) is det.
%   A = [Name, [[File, Content], ...]]   -> B = [Content]
%   A = [Name, [Folder, Files], ...]     -> B = Files
%   Missing name                          -> B = ["Error."]
spec_open([Name|Items], B) :-
    entries(Items, Entries),
    (   member([Name, X], Entries)
    ->  ( string(X) -> B = [X] ; B = X )
    ;   B = ["Error."]
    ).

entries([L], L) :- is_list(L), L = [[_, _]|_], !.
entries(Items, Items).

%!  spec_write(+A, -B) is det.
%   Writing a diary with at least one step succeeds.
spec_write([_Name, Steps], B) :-
    (   Steps == [] -> B = ["false"] ; B = ["true"] ).

%!  spec_save(+A, -B) is det.
spec_save([Name, Content], B) :-
    (   Name == "" -> B = ["Error."] ; B = [Content] ).

%!  spec_navigate(+A, -B) is det.
spec_navigate([Name|Folders], B) :-
    (   member([Name, Files], Folders) -> B = Files ; B = ["Error"] ).

%!  spec_search(+A, -B) is det.
%   B is the rest of the list from the first match.
spec_search([X, List], B) :-
    (   append(_, [X|Rest], List) -> B = [X|Rest] ; B = ["Error."] ).

%   ---- the chatbot's file store ------------------------------------------------

vfs_init :-
    (   vfs_folder(home) -> true ; assertz(vfs_folder(home)) ),
    (   cwd_(_) -> true ; assertz(cwd_(home)) ).

vfs_clear :-
    retractall(vfs_folder(_)),
    retractall(vfs_file(_, _, _)),
    retractall(cwd_(_)),
    vfs_init.

vfs_cwd(F) :- ( cwd_(F0) -> F = F0 ; F = home ).

%!  vfs_open(+Name, -Result) is det.
%   Result = file(Folder, Content), folder(Files) or error.
vfs_open(Name, R) :-
    vfs_cwd(Cwd),
    (   vfs_file(Cwd, Name, C) -> R = file(Cwd, C)
    ;   vfs_file(F, Name, C) -> R = file(F, C)
    ;   vfs_folder(Name) -> vfs_list(Name, Files), R = folder(Files)
    ;   R = error
    ).

%!  vfs_save(+Name, +Content, -Result) is det.
vfs_save(Name, Content, R) :-
    (   Name == '' -> R = error
    ;   vfs_cwd(F),
        (   retract(vfs_file(F, Name, _)) -> R = replaced(F) ; R = created(F) ),
        assertz(vfs_file(F, Name, Content))
    ).

vfs_append(Name, Text, R) :-
    vfs_cwd(Cwd),
    (   vfs_file(Cwd, Name, Old) -> F = Cwd
    ;   vfs_file(F, Name, Old) -> true
    ;   F = Cwd, Old = ""
    ),
    (   Old == "" -> New = Text ; atomics_to_string([Old, "\n", Text], New) ),
    retractall(vfs_file(F, Name, _)),
    assertz(vfs_file(F, Name, New)),
    R = appended(F).

vfs_delete(Name, R) :-
    vfs_cwd(Cwd),
    (   retract(vfs_file(Cwd, Name, _)) -> R = deleted(Cwd)
    ;   retract(vfs_file(F, Name, _)) -> R = deleted(F)
    ;   R = error
    ).

vfs_mkdir(F) :- ( vfs_folder(F) -> true ; assertz(vfs_folder(F)) ).

vfs_cd(F) :-
    vfs_folder(F),
    retractall(cwd_(_)),
    assertz(cwd_(F)).

vfs_list(F, Files) :-
    vfs_folder(F),
    findall(N, vfs_file(F, N, _), Ns),
    sort(Ns, Files).

%!  vfs_search(+Text, -Hits) is det.
%   Hits = [Folder-Name, ...] of files whose name or content contains Text
%   (case-insensitive).
vfs_search(Text, Hits) :-
    string_lower(Text, T),
    findall(F-N,
            ( vfs_file(F, N, C),
              string_lower(C, LC),
              atom_string(N, NS),
              ( sub_string(LC, _, _, _, T) ; sub_string(NS, _, _, _, T) )
            ),
            Hits0),
    sort(Hits0, Hits).

%!  vfs_diary(+Entry, -Result) is det.
%   Add a dated entry to the file diary.  An empty entry fails, as in
%   the spec's write tests.
vfs_diary(Entry, R) :-
    (   Entry == ""
    ->  R = error
    ;   get_time(T),
        format_time(string(Day), "%Y-%m-%d", T),
        atomics_to_string([Day, ": ", Entry], Line),
        vfs_append(diary, Line, R)
    ).

%   ---- saving ---------------------------------------------------------------

vfs_terms(Terms) :-
    findall(vfs_folder(F), vfs_folder(F), Fs),
    findall(vfs_file(F, N, C), vfs_file(F, N, C), Ns),
    vfs_cwd(Cwd),
    append(Fs, [vfs_cwd(Cwd)|Ns], Terms).

vfs_load_term(vfs_folder(F)) :- !, atom(F), vfs_mkdir(F).
vfs_load_term(vfs_file(F, N, C)) :- !,
    atom(F), atom(N), ( string(C) -> C1 = C ; atom_string(C, C1) ),
    vfs_mkdir(F),
    retractall(vfs_file(F, N, _)),
    assertz(vfs_file(F, N, C1)).
vfs_load_term(vfs_cwd(F)) :- !, atom(F), vfs_mkdir(F), vfs_cd(F).
