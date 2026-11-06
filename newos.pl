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
    Every endpoint allows cross-origin calls, so retromr, or newos's page
    opened from GitHub Pages, can talk to this server.  /static/tts.js is the shared speech module.
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
:- http_handler(root(static), serve_static, [prefix]).
:- http_handler(root(api/chat),      cors(api_chat),      [methods([post, options])]).
:- http_handler(root(api/state),     cors(api_state),     [methods([get, options])]).
:- http_handler(root(api/semantics), cors(api_semantics), [methods([post, options])]).
:- http_handler(root(api/save),      cors(api_save),      [methods([post, options])]).
:- http_handler(root(api/export),    cors(api_export),    [methods([get, options])]).
:- http_handler(root(api/import),    cors(api_import),    [methods([post, options])]).
:- http_handler(root(api/reset),     cors(api_reset),     [methods([post, options])]).

%   Every API call allows other origins (and the browser's preflight), so
%   the page can also be opened from GitHub Pages and talk to a newos
%   server on the same computer at http://localhost:8081.
cors(_, Request) :-
    memberchk(method(options), Request), !,
    cors_enable(Request, [methods([get, post, options])]),
    format("Access-Control-Allow-Private-Network: true~n"),
    format("~n").
cors(Goal, Request) :-
    cors_enable,
    format("Access-Control-Allow-Private-Network: true~n"),
    call(Goal, Request).

server :-
    (   getenv('PORT', P), atom_number(P, Port) -> true ; Port = 8081 ),
    server(Port).

server(Port) :-
    nl_init,
    http_server(http_dispatch, [port(Port)]),
    format("~nnewos is running at http://localhost:~w~n~n", [Port]).

api_chat(Request) :-
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

serve_static(Request) :-
    (   memberchk(path_info(P0), Request) -> true ; P0 = '' ),
    (   atom_concat('/', P, P0) -> true ; P = P0 ),
    \+ sub_atom(P, _, _, _, '..'),
    app_dir(A),
    atomic_list_concat([A, '/web/', P], F),
    exists_file(F), !,
    http_reply_file(F, [unsafe(true)], Request).
serve_static(Request) :-
    http_404([], Request).

:- initialization(server).
