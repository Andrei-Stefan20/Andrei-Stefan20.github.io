---
title: "The Bottleneck Wasn't the LLM: What Actually Improved Text-to-SPARQL"
type: article
layout: article
lang: en
slug: text-to-sparql-bottleneck
permalink: /entries/text-to-sparql-bottleneck/
date: 2026-06-22
category: "Knowledge Graphs"
read_time: 11
image: "/images/articles/text-to-sparql-bottleneck/hero.png"
thumbnail: "/images/articles/text-to-sparql-bottleneck/hero.png"
cover: "/images/articles/text-to-sparql-bottleneck/hero.png"
cover_alt: "Text-to-SPARQL results showing entity linking as the main source of improvement"
thumbnail_alt: "Text-to-SPARQL article preview"
excerpt: "An ablation study on Text-to-SPARQL generation showed that reliable entity linking mattered far more than extra examples, schema hints or increasingly elaborate prompts."
---

Large language models can produce SPARQL that looks convincing long before they can produce SPARQL that is correct.

That distinction became the central problem in my experiments on translating natural-language questions into executable Wikidata queries. The syntax was often valid. Prefixes, variables, triple patterns and filters appeared in the right places. Yet the query still returned the wrong answer, or no answer at all, because one entity or property identifier was incorrect.

The model was not primarily failing to write SPARQL. It was failing to connect human language with the identifiers used by the graph.

## The task

The project uses questions from QALD-10 and asks a model to generate SPARQL for Wikidata. A question may mention a person, place, work or event in ordinary language, while the final query must use identifiers such as `Q42`, `P19` or `P1346`.

![The same question must be mapped to opaque Wikidata identifiers before SPARQL generation can work](/images/articles/text-to-sparql-bottleneck/wikidata-problem.png)

The pipeline was designed as a set of independently configurable stages:

![Modular Text-to-SPARQL pipeline with entity linking, schema retrieval, examples, prompt construction and generation](/images/articles/text-to-sparql-bottleneck/pipeline.png)

I compared GPT-4o, GPT-4o-mini and Llama 3.3 70B while varying the linker, FAISS-retrieved few-shot examples, Wikidata property hints and prompting strategies such as decomposition and self-consistency.

The useful part of this design was not obtaining one final score. Every component could be enabled or removed, which made it possible to measure what actually helped.

## Why Wikidata is harder than ordinary code generation

SPARQL generation is often presented as another structured-generation problem, similar to SQL. The comparison only goes so far.

A relational database usually exposes a bounded schema with readable table and column names. Wikidata instead contains more than one hundred million entities and thousands of properties identified by opaque QIDs and PIDs. The question itself does not reveal those identifiers.

![DBpedia exposes readable relation names while Wikidata uses opaque property identifiers](/images/articles/text-to-sparql-bottleneck/wikidata-problem.png)

Ambiguity makes the problem worse. A surface form can correspond to many nodes, and search APIs tend to prefer the most popular candidate rather than the one that best fits the sentence.

![Entity resolution ambiguity illustrated with multiple meanings of The Matrix](/images/articles/text-to-sparql-bottleneck/entity-ambiguity.png)

Even when the correct entity is known, the graph structure may still be non-obvious. Temporal constraints, roles and qualifiers require navigating reified statements with prefixes such as `p:`, `ps:` and `pq:` rather than relying only on direct `wdt:` edges.

![Wikidata qualifier navigation requires reified statement paths rather than only direct properties](/images/articles/text-to-sparql-bottleneck/qualifiers.png)

This produces two separate tasks:

1. infer what the mention means;
2. map that meaning to the correct graph identifier and relation path.

Prompting can help with the first. It cannot reliably solve the second without access to the graph or an external retrieval component.

## Retrieving properties and examples

The schema-retrieval component embeds enriched property descriptions containing labels, aliases and short explanations, then indexes them with FAISS. At runtime, the question and linked-entity context are used to retrieve candidate PIDs.

![FAISS property retrieval over enriched Wikidata labels, descriptions and aliases](/images/articles/text-to-sparql-bottleneck/property-retrieval.png)

The goal was to stop the model from guessing relations from memory. A phrase such as “member of Congress” should still retrieve `P39`, even though the official label is “position held”.

A second retriever selects semantically similar QALD-9+ examples and inserts their questions and gold SPARQL queries into the prompt.

![Few-shot retrieval supplies semantically similar questions and gold SPARQL structures](/images/articles/text-to-sparql-bottleneck/few-shot.png)

Both ideas sound useful in isolation. The ablations showed that their effect depended heavily on whether the target entities had already been grounded correctly.

## The strongest improvement came from entity linking

Across the full 394-question test set, configurations without entity linking obtained macro F1 scores of roughly 5–8%. Adding REBEL raised them to approximately 17–20%, depending on the model and prompt.

![Best full-dataset results across models and prompting configurations](/images/articles/text-to-sparql-bottleneck/results.png)

The best configurations reached roughly 24–25% macro F1. GPT-4o benefited most from decomposition, while Llama 3.3 70B was strongest with self-consistency. Those strategies mattered, but only after the question had been grounded in plausible entities.

![Entity linking raises performance from roughly six percent to twenty percent before prompting adds the final gains](/images/articles/text-to-sparql-bottleneck/linker-gain.png)

One component produced a two-to-threefold improvement. Everything else together added only a few more points.

This changed how I interpreted the errors. A weak score did not necessarily mean that the model could not reason about the question. In many cases, it reasoned over the wrong node.

## Retrieval can make the prompt worse

Few-shot retrieval without reliable linking often performed worse than context-free generation.

The examples were not always irrelevant. They were frequently similar at the sentence level while requiring a different graph relation. A question about a spouse may resemble one about a collaborator, creator or cast member. The model can copy a plausible-looking structure that is wrong for the target graph path.

Schema hints showed the same problem. Once entity linking was enabled, adding candidate properties sometimes reduced F1 instead of improving it. A list of plausible relations expands the search space and encourages the model to trust hints that sound right but do not match the graph.

![Ablation results showing that examples and schema hints can degrade performance while linking dominates](/images/articles/text-to-sparql-bottleneck/ablation.png)

The lesson was not that retrieval is useless. It was that retrieval must be evaluated component by component. More context is only helpful when it reduces uncertainty rather than adding new ambiguity.

## A valid query can still be wrong

A generated query can fail at several levels:

- invalid SPARQL syntax;
- a valid query that cannot execute;
- a valid query that returns no bindings;
- a query that returns the wrong entity;
- the right entity with the wrong property;
- a structurally different query that still returns the correct answer.

Syntax validation only detects the first category. Execution validation catches some of the next two. Neither proves that the identifiers match the user's intent.

This is why automatic correction has limits. Feeding an execution error back to the model can repair a malformed filter or a missing brace. It cannot always detect that a mention was linked to the wrong node when both candidate queries execute successfully.

## Iterative correction helped some models and hurt another

On a smaller 100-question experiment, iterative correction produced large gains for GPT-4o and Llama 3.3, while GPT-4o-mini became worse. The weaker model often simplified the query after feedback and lost part of the original meaning.

![Iterative correction improves GPT-4o and Llama but reduces GPT-4o-mini performance](/images/articles/text-to-sparql-bottleneck/iterative-correction.jpg)

This result is useful precisely because it is not universally positive. A correction loop does not automatically improve a system. Its value depends on whether the model can interpret feedback without collapsing the query structure.

## Agentic graph traversal changes the kind of problem being solved

The agentic version does not rely entirely on identifiers supplied at the start. It can inspect graph results, test a path, recover from an empty answer and try a different relation.

The Emu War example shows the difference. A single-shot query chose the wrong property and returned nothing. The agent explored an indirect path, identified the event, inspected its participants and filtered the result to animals.

![Agentic graph traversal recovers the Emu War answer by checking identifiers and relations against live data](/images/articles/text-to-sparql-bottleneck/react.png)

This is closer to search than to plain generation. The model is no longer asked to remember the graph perfectly; it is allowed to verify hypotheses against the data.

## Prompt engineering helped, but it did not remove the bottleneck

Decomposition and self-consistency improved some configurations. Their gains remained much smaller than the gain from entity linking.

More reasoning does not compensate for incorrect grounding. It can instead produce a longer and more coherent explanation of the wrong interpretation.

The best prompts worked because they operated on better inputs. Once the relevant QIDs were available, decomposition could focus on joins, filters, ordering and aggregation rather than guessing which graph nodes the question referred to.

## How the result compares with other systems

The comparison with previous work must be read carefully because the systems use different assumptions, models and evaluation settings. Some are fine-tuned, some perform graph search, and others receive gold entities.

![Comparison with previous Text-to-SPARQL systems under different assumptions](/images/articles/text-to-sparql-bottleneck/comparison.png)

The most revealing comparison is not the absolute ranking. It is what happens when gold entities are removed. Systems that look dramatically stronger with perfect entity grounding lose much of that advantage once they must resolve mentions themselves.

That supports the central finding: much of the apparent intelligence of the final generator depends on the quality of the identifiers supplied before generation begins.

## What I would change next

The current pipeline treats entity linking as preprocessing. The experiments suggest it should become a tool available during generation.

Instead of receiving one fixed list of entities, the model could request a search whenever it encounters an ambiguous mention. The tool would return candidates with labels, descriptions and selected graph context. The model could choose, refine the search or request additional candidates before writing SPARQL.

Schema retrieval should also become conditional. Property hints should be requested only for unresolved relations and ranked using the linked entities, not only the question text.

A stronger evaluation would separate errors into categories:

- entity-selection errors;
- property-selection errors;
- incorrect query structure;
- aggregation and filtering errors;
- syntactically invalid output;
- endpoint or execution failures.

A single F1 score is useful for comparison, but it hides which component actually needs improvement.

## The broader lesson

![Main lessons from the Text-to-SPARQL experiments](/images/articles/text-to-sparql-bottleneck/lessons.png)

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

In these experiments, the main bottleneck was not the ability of the LLM to write a query. It was the quality of the bridge between natural language and the knowledge graph.

That bridge was entity linking.
