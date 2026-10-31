# STE glossary

The `real` files follow ASD-STE100 Simplified Technical English style.
This glossary fixes one word for each idea. Use the word in the first column. Do not use the words in the last column.

## Style rules
- Write procedure sentences with at most 20 words. Write descriptive sentences with at most 25 words.
- Write one instruction in each sentence. Start with the verb. Use the active voice.
- Use one word for one idea. Do not use synonyms.
- Do not use idioms or metaphors.
- Do not use `should`, `may` or `might`. Write "do" or "do not".
- Keep product names, tool names, model and tier names, and skill names as they are.
- Keep every command, file path, number and code block as it is.
- Run `scripts/ste-lint.py` on a file to find long sentences and banned words. It also prints NOTE lines for semicolons, phrasal verbs, marketing adjectives, nominalizations, passive voice and present perfect.

## Fixed terms
| Use | Meaning | Do not use |
|---|---|---|
| verify | Prove with evidence: a source, a test or a measurement. | check, validate, ensure |
| confirm | Use only for an act of the user: the user says yes. Never use it as a synonym of verify. | |
| test | Run something to find a result or a fault. | check (as a verb) |
| ask | Put a question to the user and wait for the answer. | prompt, query, request |
| user | The person who gives the task. | owner, operator |
| customer | An organisation for which the user works. | client |
| tool | Software that the user runs, for example Claude Code. | client, harness |
| agent | Software that does a task for the main session. | bot, worker, helper |
| use | Apply a thing for a purpose. | utilise, employ, leverage |
| change | Make a thing different. | modify, alter |
| delete | Take a thing away for good. | remove, erase, drop |
| find | Get a thing by searching. | locate, discover |
| show | Make a thing visible to the user. | display, present |
| give | Hand a thing to the user or to an agent. | provide, supply |
| deliver | Give final work to the user. | hand off, ship |
| keep | Do not change or delete. | retain, preserve |
| save | Write for later use. | store, persist |
| start | Begin a process or an agent. | launch, spawn, kick off |
| stop | End a process. | terminate, halt |
| finding | A verified problem that an audit reports. | issue |
| step | One numbered action in a procedure. | stage (except the named stages of a skill) |
| gate | A point where the user must approve before work continues. | checkpoint (except the name CHECKPOINT) |
| rule | An instruction that the agent must obey. | guideline, policy |
| source | The place that a fact comes from. | reference (except the `references/` folder) |
| local overlay | The private files that add to `real.md`. | private layer, personal file |
| repo | A code repository. | repository, project repo |
| folder | A place that holds files. | directory |
| if | A condition that is not sure. | in case, provided that |
| when | A time that is sure to come. | once, as soon as |
| because | The reason for a fact. | since, as |
| before / after | Order in time. | prior to, subsequent to |
| and / or | Join or choose. | as well as, and/or |
