---
title: "Replacing Qwen's Vision Transformer with ResNet-50"
type: project
layout: case-study
lang: en
slug: resnet-vit-distillation
permalink: /entries/resnet-vit-distillation/
date: 2026-07-12
year: 2026
image: "/images/projects/resnet-vit/hero.png"
label: "RESEARCH"
role: "Deep Learning"
technologies: [PyTorch, ResNet-50, Qwen-VL, Vision Transformers, CNN, Feature Distillation]
code: "https://github.com/Fabb-24/ResNet-to-ViT-Feature-Distillation"
demo: ""
paper: ""
excerpt: "Can a convolutional network replace the Vision Transformer inside a modern Vision-Language Model? I explored a feature-distillation pipeline that teaches ResNet-50 to produce the visual embeddings expected by Qwen."
---

# Replacing Qwen's Vision Transformer with ResNet-50

![Comparison between the original Qwen architecture and the custom ResNet-50 architecture](/images/projects/resnet-vit/hero.png)

Vision-Language Models usually come with a fairly fixed assumption. Images are processed by a Vision Transformer, converted into a sequence of embeddings and then passed to the language model.

That is how the system was designed, so it is easy to treat the visual encoder as something that cannot really be touched.

I wanted to see what would happen if I touched it anyway.

The question behind this project was simple.

**Can a ResNet-50 replace the Vision Transformer inside Qwen without retraining the entire language model?**

Not by changing what the language model expects, but by teaching a different visual encoder to produce a compatible representation.

That distinction is the whole project.

## Replacing the encoder is the easy part

Technically, removing the original visual encoder and inserting a ResNet is not difficult.

Making the result useful is another story.

A Vision Transformer produces a flat sequence of visual tokens. ResNet-50 produces hierarchical feature maps at different resolutions and channel depths. One architecture describes an image as a sequence, while the other builds progressively more abstract spatial representations.

The outputs do not have the same structure, the same dimensions or the same meaning.

Passing raw ResNet features directly to Qwen would be a little like replacing a translator with someone who speaks a completely different language and expecting the conversation to continue normally.

The real problem was therefore not replacing the encoder.

It was building the translator.

## Teaching ResNet to speak Qwen

The proposed architecture keeps the Qwen language model unchanged.

![Original and custom Qwen visual pipelines](/images/projects/resnet-vit/hero.png)

The original Vision Transformer is replaced by two components.

The first is ResNet-50, used as the new visual backbone.

The second is a learned multi-stage adapter that converts the hierarchical CNN features into the sequence of embeddings expected by Qwen.

From the language model's point of view, the interface remains the same. It still receives 196 visual embeddings with a dimensionality of 2048. The difference is that those embeddings are no longer produced by the original Vision Transformer.

They are reconstructed from ResNet features.

This made the adapter the central part of the project. Its job was not to classify an image or predict a label. It had to imitate a latent representation produced by a completely different architecture.

## The target was already inside the model

To train the adapter, I first used the original Qwen Vision Transformer as a teacher.

Each image was passed through the original visual encoder and the resulting embeddings were saved. Those tensors became the ground truth for the new pipeline.

The same image was then processed by ResNet-50. Its intermediate feature maps were sent to the adapter, which attempted to reconstruct the embeddings produced by the teacher.

Training minimized the Mean Squared Error between the original ViT embeddings and the reconstructed embeddings.

In other words, the model was not learning that an image contains a sheep, a tank or a castle. It was learning how Qwen internally represents that image.

That is what made the project interesting to me. The task happens before language generation and before any visible answer. It lives entirely inside the representation space of the model.

## Building the adapter

![High-level structure of the multi-stage adapter](/images/projects/resnet-vit/adapter.png)

ResNet produces useful information at several stages.

Early layers preserve local details such as edges and textures. Deeper layers lose some spatial precision but gain more semantic information. Ignoring either side would waste part of what makes a CNN useful.

The adapter therefore receives feature maps from multiple ResNet stages and progressively combines them.

Projection blocks align the different channel dimensions.

Fusion blocks merge information coming from different levels of the network.

Attention and Transformer components allow spatially distant features to interact.

Pooling reshapes the spatial representation.

The final sequence block produces the exact token structure required by Qwen.

The objective was not to force ResNet to behave like a Transformer internally. It was to let ResNet work in its natural hierarchical way and translate the final result only at the boundary.

## Four versions instead of pretending the first idea worked

The adapter was developed through four main versions.

The first version was deliberately simple and used convolutional projection and fusion blocks. It gave me a baseline and, more importantly, showed that the mapping was possible at all.

The second version added a Transformer Encoder after feature fusion. The idea was to recover some of the global interaction naturally present in a Vision Transformer.

The third version focused more on local spatial information by improving the fusion stage with larger convolutional kernels.

The fourth combined both directions, using the improved local fusion together with Transformer-based global reasoning.

This was probably the most useful part of the work. Instead of looking only at the final model, I could see what changed when the adapter gained a better local view, a better global view or both.

## What the model actually receives

![Detailed model summary with input and output tensor shapes](/images/projects/resnet-vit/model-summary.png)

The shape of the output is not a minor implementation detail.

Qwen expects a sequence with shape `[B, 196, 2048]`. If the adapter produces something different, the rest of the model cannot continue.

The feature maps extracted from ResNet begin with very different shapes. Depending on the stage, they can contain hundreds or thousands of channels and different spatial resolutions.

The adapter projects, fuses and compresses these representations until they become a sequence that matches the original ViT interface.

This strict boundary was useful because it kept the experiment focused. The language model did not need to be redesigned around the new encoder. The new encoder had to earn its place by respecting the existing contract.

## Testing on very different images

I used images from different visual categories to check whether the custom encoder preserved useful information outside a single narrow domain.

### A tank

![Tank used as an inference example](/images/projects/resnet-vit/tank.jpg)

This example contains mechanical details, straight edges, text, tracks and a relatively cluttered background.

### Sheep in a field

![Sheep used as an inference example](/images/projects/resnet-vit/sheep.jpg)

Here the important information is very different. The model has to preserve shapes, texture, multiple similar subjects and the relationship between foreground and background.

### Castel del Monte

![Castel del Monte used as an inference example](/images/projects/resnet-vit/castle.jpg)

Architecture introduces another type of structure, with symmetry, repeated geometric elements and a much wider scene.

These examples were not selected because they form a benchmark. They were useful because they made failures easier to notice. A visual encoder that works only on one kind of image is not a convincing replacement for a general-purpose ViT.

## Fine-tuning the full visual path

The first training stage kept ResNet fixed and trained only the adapter.

This made sense initially because it forced the translation layer to work with stable CNN features. Once the adapter had learned a reasonable mapping, I also experimented with joint fine-tuning.

ResNet and the adapter were trained together using different learning rates, followed by another adapter-only phase.

This gave the visual backbone some freedom to move towards representations that were easier to translate, without immediately destroying the useful features learned from ImageNet.

The process was slower and more delicate than training the adapter alone, but it also made the experiment more complete. At that point, the system was no longer just translating frozen ResNet features. The whole visual pipeline was adapting to the representation expected by Qwen.

## What I learned from it

Before working on this project, I mostly thought about the Vision Transformer as the component that allows Qwen to understand images.

After working on it, I started thinking more about the interface between the visual and linguistic parts.

The language model never sees an image.

It sees tensors.

As long as another system can produce tensors with the right structure and enough of the right information, the internal architecture that created them can change.

Of course, matching dimensions is not enough. Two tensors can have the same shape and contain completely different representations. The hard part is preserving the latent geometry that the language model has learned to use.

That is why this project became less about replacing a Transformer with a CNN and more about translating between two representation spaces.

I do not see the current implementation as the final answer. It is an experiment that shows where the real difficulty is and provides a pipeline for studying it.

There are several directions I would continue exploring, including cosine-based objectives, contrastive alignment, lightweight adapters, perceptual evaluation and more systematic testing of the generated descriptions.

Still, the central idea held up.

A large multimodal model can be treated as a set of components connected by learned interfaces. Once that interface is understood, parts that initially look fixed become open to experimentation.
