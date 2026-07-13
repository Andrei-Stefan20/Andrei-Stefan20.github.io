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
excerpt: "Can a convolutional network replace the Vision Transformer inside a modern Vision-Language Model? I built a feature-distillation pipeline that teaches ResNet-50 to produce the visual embeddings expected by Qwen."
---

![Original Qwen architecture compared with the ResNet-50 and adapter pipeline](/images/projects/resnet-vit/hero.png)

Vision-Language Models are usually presented as large, almost indivisible systems. An image enters one side, a textual answer comes out of the other, and everything in the middle tends to feel fixed.

I wanted to pull one part out and see what would break.

The visual encoder used by Qwen is a Vision Transformer. It converts an image into a sequence of embeddings that the language model has learned to interpret. My question was whether that encoder was truly indispensable, or whether Qwen mainly cared about receiving the right representation at the boundary.

So I tried replacing it with ResNet-50.

Not by retraining the entire multimodal model from scratch and not by changing the language model. The idea was to keep Qwen untouched and teach a new visual pipeline to produce something close enough to the original ViT embeddings.

That small distinction is where the whole project lives.

## The model comparison that started the project

![Animated comparison between the original visual backbone and the custom one](https://raw.githubusercontent.com/Fabb-24/ResNet-to-ViT-Feature-Distillation/main/readme_data/models.gif)

At a high level, the two systems look similar. An image is encoded, converted into visual tokens and passed to the language model.

The difference is hidden inside the visual path.

The original architecture uses Qwen's Vision Transformer directly. The custom architecture uses ResNet-50 to extract hierarchical feature maps, then sends those maps through a learned adapter. The adapter has to reconstruct the token sequence that Qwen normally receives from its ViT.

On paper this sounds like a component swap. In practice, it is a translation problem between two architectures that describe images in completely different ways.

## Replacing the encoder was the easy part

Removing a module and inserting another one takes very little code. The trouble begins with the first tensor.

A Vision Transformer divides the image into patches and produces a flat sequence of tokens. Each token already lives in a representation space shaped by self-attention and by the original multimodal training process.

ResNet-50 does something else. It gradually builds feature maps at multiple resolutions. Early layers preserve edges, textures and local detail. Deeper layers reduce the spatial resolution while increasing semantic abstraction.

The outputs differ in shape, structure and meaning.

Passing raw ResNet features directly to Qwen would therefore be like replacing a translator with someone who speaks a different language and hoping the conversation continues normally.

The real work was not replacing the encoder. It was building the translator between them.

## The adapter became the actual project

![Multi-stage adapter used to connect ResNet-50 with Qwen](/images/projects/resnet-vit/adapter.png)

The adapter receives feature maps from several ResNet stages instead of using only the final layer. This matters because the different stages contain different kinds of information.

Using only the shallow features would preserve detail but lose much of the high-level meaning. Using only the deepest layer would keep more semantics but discard useful spatial structure. The adapter has to combine both.

Projection blocks first bring the different channel dimensions into compatible spaces. Fusion blocks then merge information from multiple resolutions. Attention and Transformer components introduce broader interactions between regions that a purely local convolutional path may not capture well. Finally, the spatial representation is compressed and converted into the sequence expected by Qwen.

The output contract is strict. Qwen expects a tensor with shape `[B, 196, 2048]`. Producing a tensor with the same number of values is not enough. The information inside it also needs to resemble the representation the language model learned to use.

That is why the adapter is not a simple dimensionality projection. It is the bridge between two visual paradigms.

## The teacher was already inside Qwen

The original Vision Transformer provided the training target.

Each image was first processed by Qwen's native visual encoder. The resulting embeddings were stored and treated as ground truth. The same image then passed through ResNet-50, and the adapter attempted to reconstruct those teacher embeddings from the CNN feature maps.

The first objective was straightforward. Minimize the Mean Squared Error between the original ViT representation and the reconstructed one.

This means the model was not trained directly to predict whether an image contained a tank, a sheep or a castle. It was trained to imitate the way Qwen internally represents those images before generating any text.

I found this part especially interesting because all the important work happens before there is a visible answer. The model can produce a tensor with the correct shape and still fail completely if the latent structure is wrong.

The experiment therefore became less about image classification and more about representation alignment.

## Four adapters instead of one final architecture

I did not want to build one complicated adapter immediately and then have no idea which part actually helped.

The project evolved through four versions.

The first version was a convolutional baseline based on projection and fusion blocks. It was intentionally simple. Its job was to show whether the mapping could work at all.

The second version added a Transformer Encoder after feature fusion. The idea was to recover some of the global interaction that a Vision Transformer obtains naturally through self-attention.

The third version moved in the opposite direction and focused more on local spatial context. It improved the fusion stage with larger convolutional kernels.

The fourth version combined both ideas. It used the improved local fusion from the third version together with the Transformer-based global reasoning introduced in the second.

This progression was more useful than jumping straight to the largest model. Each version answered a slightly different question. Did the adapter mainly need stronger local processing? Was global context the missing piece? Or did the mapping require a balance between the two?

## What actually happens to the tensors

![Detailed model structure and tensor dimensions](/images/projects/resnet-vit/model-summary.png)

ResNet produces several feature maps with different spatial resolutions and channel depths. The adapter cannot simply concatenate all of them and hope for the best.

Each stage is projected into a compatible representation. Higher-resolution maps are gradually compressed, while deeper maps contribute more abstract information. The fusion process repeatedly combines these signals until the model reaches a single visual representation.

The final blocks reshape that representation into 196 visual tokens, each with dimensionality 2048.

This exact interface kept the project focused. I did not redesign Qwen around ResNet or modify the language model to accept arbitrary CNN outputs. ResNet and the adapter had to fit the model that already existed.

That constraint made the experiment harder, but also more meaningful. A replacement encoder should respect the existing system instead of forcing every downstream component to change around it.

## Training was only the first phase

The initial training stage kept ResNet frozen and optimized only the adapter.

This gave the translation layer a stable input distribution. ResNet continued to provide its pretrained ImageNet features, while the adapter learned how to transform them into the teacher space.

Once the adapter had reached a reasonable mapping, I experimented with joint fine-tuning. ResNet and the adapter were trained together using different learning rates. The backbone received a smaller learning rate, while the adapter remained more flexible.

A final adapter-only phase followed the joint training.

The purpose was to let the visual backbone move slightly toward representations that were easier to translate without immediately destroying its useful pretrained features.

This stage was slower and more delicate, but it changed the nature of the experiment. The system was no longer only translating a fixed CNN representation. The entire visual path was adapting to the latent interface expected by Qwen.

## Why I used very different images

A visual encoder designed to replace a general-purpose ViT should not work only on one narrow kind of input.

I therefore looked at examples that were visually far apart. They are not a complete benchmark, but they make different failure modes easier to notice.

### Mechanical structure and clutter

![Tank used as an inference example](/images/projects/resnet-vit/tank.jpg)

The tank image contains straight edges, tracks, mechanical parts, text and a relatively busy background. Preserving this kind of scene requires attention to both small local details and the overall object structure.

A representation that keeps only broad semantics may still understand that there is a vehicle, but lose the visual evidence needed to describe it properly.

### Repeated subjects and natural texture

![Sheep used as an inference example](/images/projects/resnet-vit/sheep.jpg)

The sheep image presents almost the opposite problem. There are multiple similar subjects, softer shapes, irregular texture and a stronger relationship between foreground and background.

The encoder has to preserve the fact that the scene contains several animals, not just one generic object. It also needs enough spatial information to distinguish the subjects from the field around them.

### Symmetry and a wider scene

![Castel del Monte used as an inference example](/images/projects/resnet-vit/castle.jpg)

Castel del Monte introduces geometry, symmetry, repeated architectural elements and a much wider composition.

This kind of image is useful because local features alone are not enough. Understanding the scene requires combining details across distant regions while preserving the overall arrangement of the structure.

Together, these examples expose different demands on the visual representation. Fine mechanical detail, repeated organic subjects and large-scale architectural geometry should all survive the trip through ResNet and the adapter.

## The difficult part is not the tensor shape

One of the easiest mistakes in this kind of project is to treat compatibility as a shape problem.

If Qwen expects `[B, 196, 2048]`, then producing `[B, 196, 2048]` may look like success. It is not.

Two tensors can have identical dimensions and represent completely different things. The language model has learned to rely on the geometry of the original embedding space. Similar images should occupy meaningful regions, visual concepts should be encoded consistently and token relationships should preserve enough information for generation.

Mean Squared Error gives a useful starting point because it directly pushes the student representation toward the teacher. It does not guarantee that every important semantic relation is preserved.

This is where future work becomes interesting. Cosine objectives could focus more on direction than absolute magnitude. Contrastive alignment could preserve relationships between images. Perceptual or downstream losses could optimize the generated descriptions rather than only the intermediate tensors.

The current pipeline makes those experiments possible because the teacher extraction, adapter training, fine-tuning, evaluation and custom inference stages are already separated.

## What I would improve next

The first improvement would be a more systematic evaluation of the generated text.

MSE tells us whether two embedding tensors are numerically close, but it does not fully tell us whether Qwen can use them in the same way. A stronger evaluation would compare captions, question answering performance and semantic consistency across the original and custom encoders.

I would also explore smaller adapters. The purpose of replacing the ViT is partly to investigate a more efficient visual path, so an adapter that becomes too large can erase the practical advantage.

Another direction would be layer-wise or token-wise distillation. Instead of aligning only the final visual sequence, the training process could preserve relationships at multiple levels.

Finally, I would test whether the same idea transfers to other multimodal models. If the interface can be learned reliably, the approach should not be tied to a single version of Qwen.

## What I took away from the project

Before working on this, I mostly thought of the Vision Transformer as the component that allowed Qwen to understand images.

After working on it, I started thinking much more about the boundary between the visual and linguistic parts.

The language model never sees pixels. It sees tensors produced by another component.

That does not make the problem easy. Matching the dimensions is trivial compared with preserving the latent structure the model has learned to interpret. Still, once the interface is isolated, components that initially look fixed become open to experimentation.

For me, that is the most valuable result of the project.

It is not simply a CNN replacing a Transformer. It is an attempt to understand how two very different representation systems can be connected without rebuilding everything around them.

The current implementation is not a final answer, and I do not want to present it as one. It is a working research pipeline that makes the real problem visible and gives me a concrete base for exploring better objectives, lighter architectures and stronger evaluation.

That is exactly what I wanted from it.