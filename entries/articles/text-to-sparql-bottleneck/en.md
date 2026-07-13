---
title: "The Bottleneck Wasn't the LLM: What Actually Improved Text-to-SPARQL"
type: article
layout: article
lang: en
slug: text-to-sparql-bottleneck
permalink: /entries/text-to-sparql-bottleneck/
date: 2026-06-22
category: "Knowledge Graphs"
read_time: 9
excerpt: "An ablation study on Text-to-SPARQL generation showed that reliable entity linking mattered far more than extra examples, schema hints or increasingly elaborate prompts."
---

Large language models can produce SPARQL that looks convincing long before they can produce SPARQL that is correct.

That distinction became the central problem in my experiments on translating natural-language questions into executable Wikidata queries. The generated syntax was often valid. The query contained prefixes, variables, triple patterns and filters in the right places. Yet it still returned the wrong answer, or no answer at all, because one entity or property identifier was incorrect.

The model was not primarily failing to write SPARQL. It was failing to connect the language used by a person with the identifiers used by a knowledge graph.

## The task

The project uses questions from QALD-10 and asks a model to generate SPARQL for Wikidata. A typical example may mention a person, place, work or historical event in ordinary language, while the final query must use identifiers such as `Q42` or `P31`.

The complete pipeline was designed as a set of independently configurable components:

```text
natural-language question
  -> entity linking
  -> similar-example retrieval
  -> schema hints
  -> prompt construction
  -> LLM generation
  -> syntax and execution validation
  -> SPARQL query
```

I compared three language models: GPT-4o, GPT-4o-mini and Llama 3.3 70B. Around them I varied the entity linker, FAISS-retrieved few-shot examples, Wikidata property hints and prompting strategies such as decomposition and self-consistency.

The useful part of this design was not merely obtaining one final score. Every component could be enabled or removed, which made it possible to measure what actually improved the system.

## Why the problem is harder than code generation

SPARQL generation is often presented as another structured-generation task, similar to SQL. The comparison is only partly accurate.

A relational database usually exposes a schema controlled by the application. Table and column names are readable, bounded and available to the model. Wikidata instead contains millions of entities and properties identified by opaque QIDs and PIDs. The question itself does not reveal those identifiers.

Consider the word `Mercury`. It may refer to a planet, an element, a Roman deity, a newspaper, a record label or a person. A language model can understand the sentence and still choose the wrong Wikidata node. Once that happens, a perfectly structured query remains semantically wrong.

This creates two separate problems:

1. infer the intended meaning of the mention;
2. map that meaning to the correct knowledge-graph identifier.

Prompting can help with the first problem. It cannot reliably solve the second without access to the graph or a retrieval component.

## The strongest improvement came from entity linking

Across the full 394-question test set, configurations without entity linking obtained macro F1 scores of roughly 5–8%. Adding the linker raised them to approximately 17–20%, depending on the model and prompt.

That was a two-to-threefold improvement from one component. None of the remaining additions produced a gain of the same magnitude.

The best configurations reached roughly 24–25% macro F1. GPT-4o benefited most from decomposition, while GPT-4o-mini and Llama 3.3 70B were more competitive with self-consistency. Those strategies mattered, but only after the query had been grounded in plausible entities.

This changed the way I interpreted the errors. A weak final score did not necessarily mean that the model could not reason about the question. In many cases it reasoned over the wrong node.

## A correct query can still be wrong

There are several levels at which a generated query may fail:

- invalid SPARQL syntax;
- a valid query that cannot execute;
- a valid query that returns no bindings;
- a query that executes and returns the wrong entity;
- a query with the right entity but the wrong relation;
- a structurally different query that still returns the correct answer.

Syntax validation only detects the first category. Execution validation can identify some of the next two. Neither proves that the selected identifiers match the user's intent.

This explains why automatic correction has limits. Feeding an execution error back to the model can repair a missing brace, malformed filter or invalid variable. It cannot always detect that `Apple` was linked to the fruit instead of the company when both identifiers produce valid results.

## Few-shot retrieval was not automatically useful

The pipeline retrieves similar training questions with FAISS and places their SPARQL queries in the prompt. The expectation was straightforward: examples should teach the model recurring query structures and demonstrate the use of Wikidata identifiers.

In practice, few-shot retrieval without reliable entity linking often performed worse than context-free generation.

The problem was not that examples were always irrelevant. They were often similar at the sentence level while requiring different graph structures. A question about a person's spouse may resemble one about a collaborator, creator or cast member. Reusing the visible structure of the example can lead the model toward the wrong property.

Examples also introduce additional identifiers into the context. When the target entities have not already been resolved, the model may copy an identifier or relation because it looks structurally appropriate.

The lesson was not that few-shot prompting is useless. It was that retrieved examples need to be grounded and selected for the part of the problem they are intended to solve. Semantic similarity between questions is not enough.

## Schema hints can become distractions

I also tested property hints retrieved from the Wikidata schema. In theory, exposing candidate PIDs should reduce the need for the model to recall relations from memory.

The effect was mixed. Once entity linking was enabled, schema hints frequently reduced F1 rather than improving it.

A list of plausible properties expands the model's search space. Some relations have overlapping descriptions, and the distinction becomes clear only through domain, range and graph context. Presenting several candidates can make the prompt look informative while adding uncertainty.

This suggests that schema retrieval should be selective. It is more useful when the model is uncertain about a relation than when it is added to every question by default. A future version of the system should retrieve schema information conditionally, after analysing the linked entities and the expected query shape.

## Prompt engineering helped, but it did not remove the bottleneck

Decomposition asks the model to separate a complex question into smaller decisions before writing the final query. Self-consistency generates multiple candidates and selects or aggregates them. Both techniques improved some configurations.

Their gains were nevertheless much smaller than the gain from entity linking.

This is an important practical distinction. More reasoning does not compensate for incorrect grounding. It can instead produce a longer and more coherent explanation of the wrong interpretation.

The strongest prompts worked because they operated on better inputs. Once the relevant QIDs were available, decomposition could focus on joins, filters, ordering and aggregation rather than guessing which graph nodes the question referred to.

## What I would change in the next version

The current pipeline treats entity linking as a preprocessing stage. The experiments suggest it should become an interactive tool available during generation.

Instead of receiving one fixed list of entities, the model could request a search when it encounters an ambiguous mention. The tool would return candidates with labels, descriptions and selected graph context. The model could then choose or refine the search before producing SPARQL.

I would also make schema retrieval conditional. Property hints should be requested only for unresolved relations, and ranked using the linked entities rather than only the question text.

A stronger evaluation would separate errors into categories:

- entity-selection errors;
- property-selection errors;
- incorrect query structure;
- aggregation and filtering errors;
- syntactically invalid output;
- endpoint or execution failures.

A single F1 score is useful for comparison, but it hides which component needs improvement.

## The broader lesson for RAG systems

This project was nominally about SPARQL, but the result applies more broadly to retrieval-augmented generation.

A language model can only reason over the evidence it receives. When retrieval returns the wrong object, more context and more elaborate prompting may increase confidence without increasing correctness.

The priority should therefore be:

```text
correct grounding
  -> relevant context
  -> structured reasoning
  -> generation
  -> validation
```

In this experiment, the main bottleneck was not the ability of the LLM to write a query. It was the quality of the bridge between natural language and the knowledge graph.

That bridge was entity linking.