---
title: "Sostituire il Vision Transformer di Qwen con ResNet-50"
type: project
layout: case-study
lang: it
slug: resnet-vit-distillation
permalink: /it/entries/resnet-vit-distillation/
date: 2026-06-24
year: 2026
image: "/images/projects/resnet-vit/adapter2.png"
label: "RICERCA"
role: "Deep Learning"
technologies: [PyTorch, ResNet-50, Qwen-VL, Vision Transformers, CNN, Feature Distillation]
code: "https://github.com/Fabb-24/ResNet-to-ViT-Feature-Distillation"
demo: ""
paper: ""
excerpt: "Una pipeline di feature distillation per sostituire il visual encoder di Qwen con ResNet-50, mantenendo invariato il Language Model."
---

Questo progetto nasce da una domanda precisa: **è possibile sostituire il Vision Transformer di Qwen con ResNet-50 senza modificare il Language Model?**

Il punto non era confrontare genericamente CNN e Transformer. Volevo mantenere invariata l'interfaccia visiva di Qwen e verificare se un backbone convoluzionale, insieme a un adapter addestrabile, potesse produrre embedding compatibili con quelli del visual encoder originale.

Qwen si aspetta una sequenza con forma `[B, 196, 2048]`. ResNet-50, invece, restituisce mappe di feature gerarchiche con risoluzioni e numero di canali differenti. Il progetto consiste quindi nel trasformare più feature map della CNN in una sequenza di token che il modello linguistico possa usare senza essere riaddestrato.

## Architettura della pipeline

![Adapter multi-stage che collega ResNet-50 a Qwen](/images/projects/resnet-vit/adapter2.png)

La pipeline personalizzata contiene tre parti:

1. **ResNet-50**, usata come backbone visivo;
2. **un adapter multi-stage**, che raccoglie feature da più livelli della rete;
3. **il Language Model di Qwen**, lasciato invariato.

Non ho usato soltanto l'ultimo layer di ResNet. I livelli iniziali conservano dettagli locali, bordi e texture; quelli più profondi descrivono meglio la struttura semantica dell'immagine, ma hanno una risoluzione spaziale inferiore. L'adapter combina entrambe le informazioni.

Ogni feature map viene prima proiettata in uno spazio con dimensioni compatibili. Le mappe vengono poi ridimensionate e fuse progressivamente. I blocchi finali trasformano la rappresentazione spaziale in 196 token da 2048 dimensioni.

Il vincolo sulla forma è necessario, ma non rappresenta da solo il risultato. Due tensori con forma `[B, 196, 2048]` possono contenere informazioni completamente diverse. Per questo l'obiettivo del training non era soltanto produrre l'output corretto dal punto di vista dimensionale, ma avvicinarsi allo spazio latente del ViT originale.

## Feature distillation

Il Vision Transformer di Qwen viene usato come teacher.

Per ogni immagine, il visual encoder originale produce una sequenza di embedding. Questi tensori vengono salvati e usati come target. La stessa immagine viene elaborata da ResNet-50; le sue feature passano attraverso l'adapter, che produce la sequenza student.

La prima loss utilizzata è il Mean Squared Error:

```text
L = MSE(E_student, E_teacher)
```

Dove `E_teacher` è l'output del ViT originale ed `E_student` è l'output prodotto da ResNet-50 e adapter.

Questa configurazione separa il problema di allineamento dal task finale. Il modello non viene addestrato direttamente su caption o classi. Impara invece a ricostruire la rappresentazione visiva che Qwen utilizza prima della generazione del testo.

## Le quattro versioni dell'adapter

Ho sviluppato quattro varianti per capire quali componenti contribuissero davvero al mapping.

**V1** usa proiezioni `1×1` e fusione convoluzionale. È la baseline più semplice e serve a verificare se le feature di ResNet contengano informazione sufficiente per approssimare gli embedding del ViT.

**V2** aggiunge un Transformer Encoder dopo la fusione. Le convoluzioni elaborano bene il contesto locale, ma non modellano direttamente le dipendenze tra regioni lontane dell'immagine. Il Transformer introduce questa componente globale.

**V3** modifica la fusione convoluzionale usando kernel `3×3`. Rispetto alle proiezioni puntuali, consente a ogni posizione di utilizzare anche il vicinato spaziale.

**V4** combina il kernel `3×3` con il Transformer Encoder. È la versione più completa: prima rafforza il contesto locale, poi modella le interazioni globali tra i token.

Questa progressione permette di distinguere il contributo della fusione spaziale da quello dell'attenzione globale, invece di aggiungere tutti i componenti in una sola architettura.

## Flusso dei tensori

![Architettura dettagliata dell'adapter e dimensioni dei tensori](/images/projects/resnet-vit/adapter_architecture.png)

ResNet produce feature map a più risoluzioni. L'adapter le elabora in questo ordine:

- proiezione dei canali;
- allineamento delle risoluzioni spaziali;
- fusione tra feature superficiali e profonde;
- compressione della dimensione spaziale;
- conversione finale in una sequenza di token.

Il risultato deve mantenere l'ordine e la dimensionalità richiesti da Qwen. Non ho modificato il modello linguistico per accettare un formato diverso: tutta la compatibilità viene gestita dal nuovo percorso visivo.

## Strategia di training

La prima fase mantiene ResNet congelata e ottimizza soltanto l'adapter. In questo modo l'adapter lavora su feature stabili e il training è più controllabile.

Nella seconda fase vengono ottimizzati insieme backbone e adapter, ma con learning rate differenti. ResNet usa un learning rate più basso per evitare di alterare rapidamente le feature apprese su ImageNet; l'adapter mantiene un learning rate maggiore.

Dopo il fine-tuning congiunto, una breve fase adapter-only permette di riallineare l'output al teacher con il backbone ormai aggiornato.

La pipeline include anche l'estrazione preventiva degli embedding del teacher, la valutazione tramite MSE e l'inferenza usando il visual encoder personalizzato.

## Controllo qualitativo

![Carro armato usato come esempio qualitativo di inferenza](/images/projects/resnet-vit/tank.jpg)

L'immagine del carro armato combina testo, bordi netti, componenti meccaniche, cingoli e uno sfondo complesso. È utile per controllare se la rappresentazione conserva sia il concetto generale dell'oggetto sia i dettagli locali necessari a descriverlo.

Non è una valutazione quantitativa. Serve a confrontare il comportamento del visual encoder originale e di quello personalizzato su un input con strutture visive diverse tra loro.

## Limiti e sviluppi successivi

L'MSE è un obiettivo diretto, ma non garantisce che tutte le relazioni semantiche presenti nello spazio del teacher vengano preservate. Due embedding possono essere vicini numericamente e produrre comunque differenze nel testo generato.

Le estensioni più utili sarebbero:

- una loss basata sulla similarità coseno;
- allineamento contrastivo tra immagini;
- distillazione layer-wise o token-wise;
- valutazione su captioning e visual question answering;
- confronto tra qualità dell'output, numero di parametri e costo di inferenza.

Il risultato principale del progetto non è dimostrare che ResNet-50 sia già un sostituto completo del ViT. È aver costruito una pipeline modulare con cui misurare quanto una CNN possa avvicinarsi all'interfaccia latente richiesta da un Vision-Language Model.