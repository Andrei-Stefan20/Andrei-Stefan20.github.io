---
title: "SLIDERS: Interpretable Image Retrieval with Sparse Feature Steering"
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
cover_alt: "SLIDERS interface showing an image query and interpretable visual steering axes"
thumbnail_alt: "SLIDERS visual search interface"
label: "RESEARCH"
role: "Interpretable Image Retrieval"
technologies: [Python, PyTorch, DINOv2, Sparse Autoencoders, FAISS, FastAPI, Vision-Language Models]
code: "https://github.com/Andrei-Stefan20/SLIDERS"
demo: ""
paper: ""
excerpt: "An image-retrieval system that exposes learned visual concepts as sliders, allowing users to steer search results toward or away from interpretable features."
---

SLIDERS is an image-retrieval system built around a simple interaction: upload a query image, inspect the visual concepts discovered by the model, and move sliders to change what the search should emphasize.

The project began from a limitation of standard embedding search. A nearest-neighbour system can return visually similar images, but it usually gives the user no direct control over *why* an image is considered similar. The query is represented by one vector, the index returns nearby vectors, and the internal factors driving the result remain hidden.

SLIDERS introduces an interpretable layer between the query embedding and the retrieval engine. Instead of treating the embedding as an indivisible representation, it uses a Sparse Autoencoder to discover directions associated with recurring visual patterns. Those directions become interactive controls.

![Query panel and learned steering axes](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif)

## The retrieval pipeline

The main visual backbone is DINOv2. A query image is encoded into a normalized embedding and searched against a FAISS index containing the dataset embeddings.

Without steering, the runtime path is conventional:

```text
query image
  -> DINOv2 encoder
  -> normalized embedding
  -> FAISS search
  -> ranked image results
```

The difference appears when the user changes one or more sliders. Each slider corresponds to a learned feature direction. The selected directions are added to, or subtracted from, the query embedding before the search:

```text
q_steered = normalize(q + sum(alpha_i * d_i))
```

Here, `q` is the original query embedding, `d_i` is a decoder direction learned by the Sparse Autoencoder, and `alpha_i` is the value chosen by the user. Positive values push the search toward the concept; negative values push it away.

The modified vector is then used for the FAISS search. This keeps the interaction immediate: moving a slider changes the geometry of the query itself rather than applying a text filter after retrieval.

## Discovering visual axes with a Sparse Autoencoder

The Sparse Autoencoder maps the 1024-dimensional DINOv2 representation into an overcomplete hidden space of 8192 activations and reconstructs the original embedding:

```text
h = ReLU(W_enc x + b_enc)
x_hat = W_dec h + b_dec
```

The hidden representation is intentionally sparse. Only a small subset of features should activate strongly for a given image. This encourages the model to separate recurring factors that are entangled in the original dense embedding.

The decoder columns are especially useful at retrieval time. Each column defines a direction in the original DINOv2 space, so it can be used directly to modify a query embedding. The same feature is therefore both interpretable through its activations and actionable through its decoder direction.

The project supports both whole-image CLS embeddings and patch-level embeddings. The CLS path learns broad image-level concepts, while patch training can expose local features tied to specific image regions.

## Naming the learned features

A feature index is not useful to a person if it is displayed only as `Feature 1827`.

SLIDERS ranks the images that activate each feature most strongly and sends representative examples to a local Vision-Language Model. The VLM looks for the recurring visual concept and assigns a short name to the axis.

For patch-trained features, the system does not show only a tightly cropped patch. It keeps the surrounding context and marks the active region. This matters because the source of an activation may be close to the selected patch rather than perfectly contained inside it.

The resulting names are stored with the feature identifiers and loaded by the interface at startup. If names are unavailable, the application can still expose features ranked by activation variance.

![Feature detail view with strongest and weakest activations](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider2.gif)

## Combining dense and sparse retrieval

The search does not rely on a single index.

The primary FAISS index operates in the original DINOv2 embedding space. A second optional index operates on normalized SAE activations. When both are available, the system retrieves candidates from each space, merges the result lists and reranks them.

This dual-index design is useful because the slider meaning lives in sparse-feature space, while the strongest general-purpose image similarity signal remains in the original DINOv2 representation.

The reranking step also compares the active slider features with precomputed SAE activations for each candidate. This compensates for the mismatch between steering in feature space and nearest-neighbour search in dense embedding space.

## Patch-level retrieval with late interaction

For local visual concepts, SLIDERS can index DINOv2 patch tokens instead of one vector per image.

A query image produces 256 patch vectors. The patch index retrieves candidate regions, then candidate images are scored using MaxSim: each query patch is matched to the most similar patch in a candidate image, and those best-match scores are summed.

This preserves more local structure than compressing the whole image into a single CLS token. Steering is applied to the query patches before retrieval, which gives the sliders a region-level effect while keeping the same frontend interaction.

## Interface and inspection tools

The browser interface is designed to make the model inspectable rather than exposing only a search box.

A user can:

- upload a query image;
- move positive and negative steering axes;
- inspect the images that activate a feature most and least;
- open any result at full resolution;
- copy its path or download it;
- reset the query and compare different steering combinations.

![Image detail modal](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider3.gif)

The backend is served through FastAPI. Runtime artifacts are loaded once at startup: embeddings, image paths, FAISS indexes, SAE weights, activation matrices and feature names. This avoids rebuilding the retrieval state for every request.

## What the project is testing

SLIDERS is not only a user-interface experiment. It tests whether sparse features learned from a strong visual embedding model can become reliable controls for retrieval.

A useful steering feature should satisfy several conditions. It should correspond to a recognizable visual pattern, change results consistently as its value increases, avoid affecting unrelated concepts too strongly and preserve the original query when its value is close to zero.

The evaluation code therefore goes beyond nearest-neighbour accuracy. It includes retrieval metrics together with measures for monosemanticity, faithfulness, selectivity and the monotonic behaviour of slider values.

The central design choice is to keep the original retrieval representation and add an interpretable control layer around it. DINOv2 remains responsible for visual similarity, FAISS keeps the search efficient, and the Sparse Autoencoder provides directions that a person can inspect and manipulate.

The result is a search system in which similarity is no longer completely fixed by the initial query. The user can state, through the learned axes, which parts of that similarity should matter more and which should matter less.