## Wiki Contract

The wiki is the authoritative record of all project decisions. It lives in `docs/wiki/`.

**Reading:** Before making any architectural, behavioural, or design decision, check
the relevant wiki document. Do not fill gaps from assumptions — if the wiki is silent
on something, flag it and ask before proceeding.

**Writing:** When a decision is made that is not yet in the wiki, update the relevant
document before closing the task. If a wiki document contains something incorrect,
correct it as part of the same task. Treat an out-of-date wiki as a bug.

**Pre-PR check:** Before opening any pull request, confirm that all wiki documents
reflect the current state of the code. An out-of-date wiki is a merge blocker.
