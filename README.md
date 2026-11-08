# newos

A web chatbot in SWI-Prolog that understands and generates natural language. It learns facts, rules, words and replies as you talk, saves everything to an editable Prolog file, and lets you choose what "if… then" means.

## Run

```sh
swipl newos.pl
```

Then open <http://localhost:8081>. You can type, or press 🎙 to talk (voice input works in Chrome, Edge and Safari). Turn on 🔊 Voice to have replies read aloud. The 🧠 panel shows the facts, rules, possible worlds, dictionary, learned replies and files newos knows.

## Straight from GitHub

With GitHub Pages on, <https://luciangreen.github.io/newos/web/> opens the chat page directly. If newos is running on your computer (`swipl newos.pl`), the page talks to it at `http://localhost:8081`. Otherwise it uses a smaller brain that runs in the browser. That brain learns facts, rules, words, your name and replies, and reads "if" as material and relevance logic. Its memory stays in that browser.

## What you can say

| | Examples |
|---|---|
| Facts | `Socrates is a man.` · `The moon is not cheese.` · `Tweety can fly.` · `John likes Mary.` |
| Rules | `All men are mortal.` · `Birds can fly.` · `No fish are birds.` |
| Questions | `Is Socrates mortal?` · `Who is mortal?` · `What does John like?` · `What is 6*7?` · `Why?` · `What do you know about Socrates?` |
| "If" | `If the moon is cheese, then 2+2=4.` · `Compare if the moon is cheese then 2+2=4` · `Remember that if it rains then the grass is wet.` |
| Semantics | `use material / strict / relevance / lewis / stalnaker / adams semantics` · `which semantics?` |
| Possible worlds | `In world w1, the moon is cheese.` · `World w1 is 2 away.` · `World w1 has probability 0.3.` · `list worlds` |
| Dictionary | `Flurb means a small blue bird.` · `What does flurb mean?` newos also asks what new words mean. |
| Replies | `When I say good night, you say sleep well!` If newos doesn't understand something, it asks how it should reply and remembers your answer. |
| Files | `open welcome` · `save notes "buy milk"` · `add "eggs" to notes` · `dear diary I enjoyed writing today` · `make folder work` · `navigate to work` · `list` · `search for milk` · `delete notes` |
| Memory | `save` · `forget the moon` · `reset everything` · Export and Import buttons in the panel |

## The semantics of "if"

The material conditional gives odd results for everyday "if…then". For example, "If the moon is cheese, then 2+2=4" comes out true. These are the paradoxes of material implication, so newos supports six readings. `compare if A then B` shows all of them side by side.

| Semantics | "If A then B" is true when… | "If the moon is cheese, then 2+2=4" |
|---|---|---|
| **material** | not (A true and B false) in the actual world | true, but only because A is false |
| **strict** (modal) | B holds in every possible world where A holds | true: no world makes A true, and 2+2=4 is necessary (a paradox of strict implication) |
| **relevance** | A and B share content, and B follows from A plus what newos knows | false: no shared content |
| **lewis** | B holds in all the closest worlds where A holds (counterfactuals) | vacuously true if no world makes A true; otherwise it checks the closest A-worlds |
| **stalnaker** | B holds in the single closest A-world | like Lewis, but indeterminate when several worlds tie for closest |
| **adams** | the conditional is assertable to the degree that P(B \| A) is high | P(B \| A) over the worlds' weights; undefined if P(A) = 0 |

Possible worlds inherit the actual world's facts unless they say otherwise. Arithmetic and `remember that if…` laws hold in every world. Truth uses a closed-world assumption: what can't be proved in a world counts as false there, and newos says when that is the reason.

## Files

| File | What it does |
|---|---|
| `nl_engine.pl` | Tokenizer, grammar (DCG), dialogue, learning, English generation, explanations |
| `logic.pl` | Knowledge base, proofs, possible worlds, the six semantics of "if" |
| `dictionary.pl` | Growing dictionary, inflection (plurals, verb forms, a/an) |
| `vfs.pl` | The file system, including the spec's `open / write / save / navigate / search` predicates |
| `newos.pl` | Web server and JSON API |
| `web/index.html` | The chat page |
| `web/tts.js` | Shared speech module: text-to-speech with lip-sync data, and voice recognition (retromr uses it) |
| `data/knowledge.pl` | Everything newos has learned, as plain Prolog terms. You can edit it; it is read back with `read_term/2`, so nothing in it is executed. |
| `specs/newos_spec.pl` | The original spec-to-algorithm examples |

## API

`POST /api/chat {"text": "..."}` returns `{"reply", "speak", "semantics", "pending"}`. Every endpoint allows cross-origin calls, so other apps (such as retromr) can talk through newos. The other endpoints are `GET /api/state`, `POST /api/semantics {"name"}`, `POST /api/save`, `GET /api/export`, `POST /api/import` and `POST /api/reset`.

## Tests

```sh
swipl -g run_tests -t halt tests/test_newos.pl
```

These include the spec's examples. In the spec, "I can feel it." comes back as "I can feel it" without the full stop, which looks like a typo, so the test expects the text unchanged. The spec file also has unbalanced brackets, so it is kept as a reference and not consulted.

## Inputs and outputs

`io/ios.txt` lists 200 inputs and the outputs they give, from real runs of this repo's predicates (which predicates, and how the inputs are made, is in `io/cases.pl`; the inputs are made the same way every time). `swipl io/check_ios.pl` runs them again and fails if any output changed; the "Inputs and outputs" workflow does the same on every push. If a change is meant, run `swipl io/make_ios.pl` and check the diff.

## Inputs and outputs

`io/ios.txt` lists 200 inputs and the outputs they give, from real runs of this repo's predicates (which predicates, and how the inputs are made, is in `io/cases.pl`; the inputs are made the same way every time). `swipl io/check_ios.pl` runs them again and fails if any output changed; the "Inputs and outputs" workflow does the same on every push. If a change is meant, run `swipl io/make_ios.pl` and check the diff.
