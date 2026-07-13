---
title: "SLIDERS: Steering Image Retrieval with Sparse Visual Features"
type: project
layout: case-study
lang: en
slug: sliders
permalink: /entries/sliders/
date: 2026-07-13
year: 2026
image: "https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif"
thumbnail: "https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif"
cover: "https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif"
cover_alt: "SLIDERS interface with an image query and learned visual steering controls"
thumbnail_alt: "SLIDERS visual retrieval interface"
label: "RESEARCH"
role: "Interpretable Image Retrieval"
technologies: [Python, PyTorch, DINOv2, Sparse Autoencoders, FAISS, FastAPI, Vision-Language Models]
code: "https://github.com/Andrei-Stefan20/SLIDERS"
demo: ""
paper: ""
excerpt: "A patch-level image retrieval system in which sparse visual features become named controls for changing the ranking at query time."
---

Most image retrieval systems answer one question: which images are closest to this query?

SLIDERS asks a second one: **closest in which visual direction?**

A normal embedding search compresses the query into a vector and returns its nearest neighbours. That works well when the desired notion of similarity is already encoded in the original query. It is less useful when the user wants to preserve the general image while changing one property, such as stronger yellowing, darker lesions, a more prominent vein or a different edge pattern.

The project turns those properties into controls. A user uploads an image, inspects the visual features discovered by the model and changes their strength through sliders. The query is modified before retrieval, so the ranking changes because the representation itself has moved, not because a text filter was applied afterwards.

![SLIDERS query panel and learned steering axes](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif)

The current implementation focuses on local visual evidence. Instead of representing an image with only one global token, it preserves its patch descriptors, learns sparse features from those patches and performs retrieval through late interaction. This made the system more complicated than a conventional FAISS demo, but it also made the controls much easier to interpret.

## From an image to 256 visual regions

The visual backbone is the register-token variant of DINOv2 ViT-L/14. Every input is resized, centre-cropped to `224 × 224` and divided into a `16 × 16` grid. The result is 256 patch tokens, each with 1024 dimensions.

```text
image
  -> DINOv2 ViT-L/14 registers
  -> 256 patch tokens
  -> tensor with shape [256, 1024]
```

Using patches rather than a single CLS embedding changes what the rest of the system can learn. A whole-image vector may encode that an image contains a diseased leaf, but it does not preserve an explicit correspondence between a feature and the region that caused it. Patch tokens retain that spatial link.

The register variant matters here. Standard Vision Transformers can produce a small number of unusually high-norm patch activations that do not correspond cleanly to visible content. A sparse model may treat those artefacts as meaningful features. Register tokens absorb much of that behaviour, leaving the spatial tokens more suitable for dictionary learning.

The patch corpus is written as a memory-mapped array rather than loaded entirely into RAM. Each row is associated with an image identifier, while metadata records the grid shape and preprocessing configuration. This is less glamorous than the model itself, but it is what makes experiments on large patch collections practical.

## Learning a sparse visual dictionary

The central model is a Sparse Autoencoder trained directly on the DINOv2 patch tokens.

Its shape is deliberately overcomplete:

```text
1024-dimensional patch token
        -> encoder
8192-dimensional sparse code
        -> decoder
1024-dimensional reconstruction
```

Formally:

```text
h = ReLU(W_enc x + b_enc)
x_hat = W_dec h + b_dec
```

The objective is not compression. The hidden layer is eight times wider than the input because the model needs enough capacity for individual units to specialise. A narrow autoencoder would force the same units to participate in many unrelated reconstructions. In the overcomplete model, a feature can remain inactive for most patches and respond only to a specific pattern.

I used a TopK constraint with `L0 = 40`. For every patch, only the forty strongest activations survive; the other 8,152 units are set to zero before decoding. This makes the sparsity budget explicit and easy to inspect.

On one representative patch, the sparse code reconstructed the original token with a cosine similarity of `0.913` using only 40 active features. Across the 256 patches of the inspected image, the mean reconstruction cosine was approximately `0.962`. The same image activated 1,721 distinct features in total, but most of them fired on only a small number of patches. That pattern is useful: the dictionary is broadly used across the image while individual features remain local.

Training and validation reconstruction losses decreased together. Early stopping selected epoch 49, and the dead-feature fraction remained at zero. Decoder columns are normalised after optimisation, so two sliders with the same numerical value correspond to directions with comparable magnitude. Features that remain inactive for too long are recycled using residual directions, preventing the dictionary from quietly losing capacity.

The decoder is more than a reconstruction matrix. Each column is a unit-length direction in the original 1024-dimensional DINOv2 space. Those columns are the actual slider directions.

## A feature needs evidence before it gets a name

An index such as `feature 4625` is useful for debugging, but not for an interface. Naming the features therefore became a separate pipeline rather than a cosmetic step.

For every candidate feature, the system searches the patch corpus for high-activation and low-activation examples. It does not send only the raw patch to the Vision-Language Model. Instead, it extracts a larger context crop and marks the active cell. This keeps enough surrounding information to interpret the pattern without pretending that the cause of the activation always fits perfectly inside a `14 × 14` patch.

The VLM is shown contrasting groups:

- patches where the feature activates strongly;
- patches where it is absent or weak;
- the corresponding image context with the active region marked.

It is then asked for the visual property that separates the two groups. A second pass checks whether the proposed label is actually supported by the examples. Weak or generic names can be rejected rather than displayed as if they were reliable.

This process produced features such as:

- `yellowing leaf tissue`;
- `dark brown lesions`;
- `brown necrotic spots`;
- `leaf edge notches`;
- `bright green veins`;
- `green leaf veins`.

The examples are not merely captions attached after training. The activation maps show where the sparse feature responds, and the top-patch galleries expose whether the unit is consistent across different leaves. In the case of feature 4625, the strongest activations repeatedly aligned with yellow tissue rather than with the entire leaf or the grey background.

![Feature inspection view in the SLIDERS interface](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider2.gif)

## Steering is a geometric operation

A slider changes the query by adding one or more decoder directions:

```text
q_steered = normalize(q + sum(alpha_i * d_i))
```

Here, `q` is a query patch, `d_i` is a unit decoder direction and `alpha_i` is the slider value. Positive values move the query toward the feature; negative values move it away. Renormalisation returns the result to the unit sphere used by cosine similarity.

This is not equivalent to boosting candidates after retrieval. The query is edited first, and the new representation is used to search the index. The result should therefore emerge from the learned geometry rather than from a hard-coded category rule.

A useful slider should behave smoothly. Increasing its value should progressively increase the selected feature in the returned images. For the `yellowing leaf tissue` feature, the mean activation in retrieved results rose sharply between `α = 0` and `α = 2`, then saturated. Its Spearman correlation between slider strength and retrieved activation was `ρ = 0.90`.

The qualitative result is easy to read. With `α = 0`, the nearest results remain close to the original green query leaf. With `α = 6`, the ranking shifts toward yellow and damaged leaves while retaining the general object and structure of the query.

This is the behaviour the interface is meant to expose: not a new text prompt and not a class filter, but a controlled movement along a feature learned from the visual representation itself.

## Why global nearest-neighbour search was not enough

A first version of the system used one global embedding per image. That path is fast and remains useful for broad similarity, but it weakens the relationship between a local feature and the result.

Suppose the slider represents a small brown lesion. A global embedding may move in the correct direction while still ranking an image highly because of its overall shape, colour or background. The local property can be overwhelmed by global similarity.

Patch-level retrieval addresses this with late interaction. Both the query and every corpus image are represented by sets of patch vectors. Candidate images are scored with MaxSim:

```text
score(Q, C) = sum_j max_k similarity(q_j, c_k)
```

For each query patch `q_j`, the system finds the best matching corpus patch `c_k`. The 256 best-match similarities are then summed. In the inspected example, the resulting MaxSim score was `216.3`.

The similarity matrix makes the computation visible. Every row corresponds to a query patch and every column to a corpus patch. The selected maximum in each row traces which region of the candidate image best explains each region of the query. The final score is therefore built from many local correspondences rather than from one globally pooled vector.

Steering is applied to the query patches before MaxSim retrieval. A direction associated with yellow tissue can modify the relevant local descriptors while the remaining patches continue to preserve shape, texture and context.

For larger corpora, the patch index uses FAISS and can switch to IVF-PQ above a configurable size. The index first retrieves candidate patches, maps them back to image identifiers and then computes exact MaxSim only for the candidate images. This keeps the late-interaction model practical without loading every possible patch pair into memory.

## Dense similarity, sparse meaning

The system keeps two complementary representations.

The original DINOv2 space is still the strongest source of general visual similarity. The SAE space is easier to interpret and contains the directions controlled by the sliders. SLIDERS can therefore combine:

1. a FAISS index over DINOv2 embeddings;
2. an optional FAISS index over normalised SAE activations;
3. precomputed activation vectors used for reranking.

The result lists from the dense and sparse indexes can be merged, normalised and reranked according to the active features. This is useful when a direction is semantically clear in SAE space but does not produce enough movement in the dense index by itself.

The steering metrics are measured before this compensating reranker. Otherwise, a strong reranking rule could hide a weak feature direction and make the interface appear more faithful than the representation actually is.

## Evaluating a steerable retrieval system

Standard metrics such as recall, precision and mean average precision are still necessary, but they do not tell us whether a slider works.

I separated the evaluation into four additional properties.

### Faithfulness

Faithfulness measures whether steering actually increases the requested feature in the results. It compares the target activation after steering with the unsteered baseline. Several learned directions produced large multiplicative increases, particularly features associated with green stem tips, bright veins and dark lesions.

### Isotonicity

Isotonicity asks whether larger slider values cause larger effects. I measure it with Spearman correlation between `α` and the mean target activation in the retrieved set. A high score means the slider behaves predictably rather than jumping between unrelated regions of the space.

### Selectivity

A slider should affect its intended feature more than unrelated ones. Selectivity measures the on-target share of the activation change. This guards against controls that appear effective only because they broadly disturb the embedding.

### Monosemanticity

A named unit should repeatedly correspond to the same visible pattern. Monosemanticity is estimated through the purity of its top-activating patches. The strongest features reached high top-patch purity, while weaker units exposed where the learned dictionary was still mixing concepts.

These metrics reveal a trade-off that ordinary retrieval scores miss. A feature can be visually coherent but too weak to move the ranking. Another can move the ranking strongly but affect several concepts at once. A useful slider needs both interpretability and control.

## What the interface contributes

The frontend is not only a wrapper around the model. It exposes the pieces needed to inspect a result:

- upload or replace the query image;
- apply positive and negative steering;
- inspect the strongest and weakest examples for a feature;
- compare combinations of axes;
- open results at full resolution;
- copy or download the original file;
- reset the query without reloading the model.

![Result inspection modal](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider3.gif)

FastAPI serves the retrieval endpoints and static frontend. At startup, the application loads the encoder, SAE checkpoint, feature names, image paths, activation matrices and FAISS indexes into a shared state. Query requests therefore perform encoding and retrieval without rebuilding the model resources.

## Where the project stands

SLIDERS does not prove that every sparse visual feature is automatically a good user control. Some units remain mixed, some names are more reliable than others and large slider values can saturate. Patch-level retrieval also increases storage and computation compared with one-vector-per-image search.

What the project provides is a complete experimental path from representation to interaction:

```text
images
  -> DINOv2 patch tokens
  -> Sparse Autoencoder
  -> local feature evidence
  -> VLM feature names
  -> decoder directions
  -> query steering
  -> MaxSim retrieval
  -> faithfulness and interpretability metrics
```

The most important design choice was to avoid treating interpretability as a visual explanation added after retrieval. The same sparse feature is used in three places: it activates on local evidence, it receives a name from that evidence and its decoder direction edits the query.

That shared object is what connects the model to the interface. The slider is not an arbitrary control mapped to a rule. It is a learned direction whose examples, location, effect and limitations can all be inspected.