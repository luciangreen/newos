/*  newos.pl - web server for the newos chatbot

    Start:   swipl newos.pl
    Chat:    http://localhost:8081
    Port:    PORT=9000 swipl newos.pl   or   ?- server(9000).

    API (JSON):
      POST /api/chat       {text}          -> {reply, speak, semantics, pending}
      GET  /api/state                      -> what newos knows, for the side panel
      POST /api/semantics  {name}          -> switch the semantics of "if"
      POST /api/save                       -> save data/knowledge.pl now
      GET  /api/export                     -> the knowledge file as text
      POST /api/import     (Prolog text)   -> merge a knowledge file
      POST /api/reset                      -> forget everything learned
    /api/chat allows cross-origin calls, so retromr (or anything else)
    can talk through newos.  /static/tts.js is the shared speech module.
*/

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_client)).
:- use_module(library(settings)).

:- use_module(nl_engine).
:- use_module(logic).

:- set_setting(http:cors, [*]).

:- dynamic app_dir/1.
:- prolog_load_context(directory, Dir),
   retractall(app_dir(_)),
   asserta(app_dir(Dir)).

:- multifile user:file_search_path/2.
user:file_search_path(newos_web, Dir) :-
    app_dir(App),
    directory_file_path(App, web, Dir).

:- http_handler(root(.),             http_reply_file(newos_web('index.html'), []), []).
:- http_handler(root(static),        serve_files_in_directory(newos_web), [prefix]).
:- http_handler(root(api/chat),      api_chat, [methods([post, options])]).
:- http_handler(root(api/state),     api_state, [method(get)]).
:- http_handler(root(api/semantics), api_semantics, [method(post)]).
:- http_handler(root(api/save),      api_save, [method(post)]).
:- http_handler(root(api/export),    api_export, [method(get)]).
:- http_handler(root(api/import),    api_import, [method(post)]).
:- http_handler(root(api/reset),     api_reset, [method(post)]).

server :-
    (   getenv('PORT', P), atom_number(P, Port) -> true ; Port = 8081 ),
    server(Port).

server(Port) :-
    nl_init,
    http_server(http_dispatch, [port(Port)]),
    format("~nnewos is running at http://localhost:~w~n~n", [Port]).

api_chat(Request) :-
    memberchk(method(options), Request), !,
    cors_enable(Request, [methods([post, options])]),
    format("~n").
api_chat(Request) :-
    cors_enable,
    http_read_json_dict(Request, In),
    (   get_dict(text, In, T0), ( string(T0) ; atom(T0) )
    ->  atom_string(T0, Text)
    ;   Text = ""
    ),
    chat(Text, _, Info),
    reply_json_dict(Info).

api_state(_) :-
    state_json(J),
    reply_json_dict(J).

api_semantics(Request) :-
    http_read_json_dict(Request, In),
    (   get_dict(name, In, N0), atom_string(N, N0), semantics_name(N, Name)
    ->  set_semantics(N), kb_save,
        reply_json_dict(_{ok:true, semantics:N, name:Name})
    ;   reply_json_dict(_{ok:false, error:"Unknown semantics."}, [status(400)])
    ).

api_save(_) :-
    kb_save, kb_file(F),
    reply_json_dict(_{ok:true, file:F}).

api_export(_) :-
    kb_export(Text),
    format("Content-type: text/plain; charset=UTF-8~n"),
    format("Content-disposition: attachment; filename=\"newos_knowledge.pl\"~n~n"),
    format("~s", [Text]).

api_import(Request) :-
    http_read_data(Request, Data, [to(string)]),
    kb_import_string(Data, N),
    reply_json_dict(_{ok:true, loaded:N}).

api_reset(_) :-
    kb_reset,
    reply_json_dict(_{ok:true}).

:- initialization(server).
