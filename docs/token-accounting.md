# Token accounting

Forgehand stores the endpoint's `prompt_tokens`, `completion_tokens`, and
`total_tokens` for every HTTP response that reports usage. Billed responses that
fail schema or semantic validation are included. Transport failures without a
provider usage object cannot be assigned inferred tokens.

## What this measures

It measures work processed by the configured worker endpoint. It does not directly
measure Codex tokens, ChatGPT credits, API cost avoided, or the counterfactual cost
of having Codex perform the task itself.

Verified savings require paired runs with the same source revision, task contract,
acceptance criteria, budgets, model, endpoint, and final validation.

## Preliminary A/B

| Runtime | Calls | Prompt | Completion | Total | Wall time |
| --- | ---: | ---: | ---: | ---: | ---: |
| Conversational baseline | 5 | 24,921 | 905 | 25,826 | 47.541 s |
| Forgehand | 11 | 9,384 | 1,324 | 10,708 | 50.166 s |

Both produced the same one-file result. Forgehand used 58.54% fewer local-worker
tokens and 5.52% more wall time. This single microbenchmark must not be extrapolated
as a general percentage.
