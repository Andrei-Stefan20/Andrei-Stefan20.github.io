---
title: "Sostituire il Vision Transformer di Qwen con ResNet-50"
type: project
layout: case-study
lang: it
slug: resnet-vit-distillation
permalink: /it/entries/resnet-vit-distillation/
date: 2026-07-12
year: 2026
image: "/images/projects/resnet-vit/hero.png"
label: "RICERCA"
role: "Deep Learning"
technologies: [PyTorch, ResNet-50, Qwen-VL, Vision Transformers, CNN, Feature Distillation]
code: "https://github.com/Fabb-24/ResNet-to-ViT-Feature-Distillation"
demo: ""
paper: ""
excerpt: "Può una rete convoluzionale sostituire il Vision Transformer dentro un moderno Vision-Language Model? Ho costruito una pipeline di feature distillation che insegna a ResNet-50 a produrre gli embedding visivi attesi da Qwen."
---

![Confronto tra l'architettura originale di Qwen e la pipeline con ResNet-50 e adapter](/images/projects/resnet-vit/hero.png)

I Vision-Language Models vengono quasi sempre costruiti attorno alla stessa idea. Un'immagine entra in un Vision Transformer, viene trasformata in una sequenza di embedding e poi passa al modello linguistico.

Funziona, quindi di solito non c'è motivo di mettere in discussione questa scelta.

Io l'ho fatto comunque.

L'idea del progetto era capire se fosse possibile sostituire il visual encoder di Qwen con ResNet-50 senza riaddestrare da zero tutta la parte linguistica. Non cambiando quello che Qwen si aspetta di ricevere, ma insegnando a un encoder completamente diverso a produrre una rappresentazione compatibile.

La differenza sembra piccola, ma in realtà è tutto il progetto.

## Sostituire l'encoder non era il vero problema

Rimuovere il Vision Transformer originale e inserire ResNet-50 è relativamente semplice. I problemi iniziano subito dopo.

Un Vision Transformer produce una sequenza piatta di token visivi. ResNet-50 produce mappe di feature gerarchiche, con risoluzioni e profondità diverse. Una delle due architetture descrive l'immagine come una sequenza, mentre l'altra costruisce gradualmente rappresentazioni spaziali a partire da pattern locali.

Gli output hanno forme, strutture e significati diversi.

Passare direttamente le feature di ResNet a Qwen sarebbe un po' come sostituire un traduttore con qualcuno che parla una lingua completamente diversa e aspettarsi che la conversazione continui normalmente.

Il vero lavoro non era quindi cambiare l'encoder. Era costruire il traduttore tra i due.

## Insegnare a ResNet a parlare la lingua di Qwen

Il modello linguistico rimane invariato. ResNet-50 diventa il nuovo backbone visivo, mentre un adapter addestrabile trasforma le sue feature intermedie nella rappresentazione che Qwen sa già usare.

![Adapter multi-stage usato per collegare ResNet-50 a Qwen](/images/projects/resnet-vit/adapter.png)

Dal punto di vista di Qwen, l'interfaccia non cambia. Il modello continua a ricevere una sequenza di 196 embedding visivi con dimensionalità 2048. La differenza è che quegli embedding vengono ricostruiti dalle feature della CNN invece di essere prodotti dal Vision Transformer originale.

Questo rende l'adapter il componente centrale del sistema. Non sta imparando a classificare immagini. Sta imparando a imitare la rappresentazione interna di un altro modello.

## Il teacher era già dentro Qwen

Per addestrare la nuova pipeline ho usato prima il Vision Transformer originale di Qwen come teacher.

Ogni immagine veniva elaborata dall'encoder originale e gli embedding risultanti venivano salvati. La stessa immagine passava poi attraverso ResNet-50, mentre l'adapter cercava di ricostruire gli embedding del teacher a partire dalle feature della CNN.

L'addestramento minimizzava il Mean Squared Error tra la rappresentazione originale e quella ricostruita.

In pratica, il modello non stava imparando direttamente che nell'immagine ci fosse una pecora, un carro armato o un castello. Stava imparando il modo in cui Qwen rappresenta quell'immagine prima ancora di generare una parola.

È proprio questo che ha reso il problema interessante per me. Tutto succede nello spazio latente, prima che il risultato diventi visibile.

## Un solo adapter non bastava

La prima versione usava una fusione convoluzionale abbastanza semplice. Mi serviva una base e, soprattutto, una prova che il mapping fosse possibile.

La seconda aggiungeva un Transformer Encoder dopo la fusione delle feature, per recuperare una parte delle interazioni globali che un ViT possiede naturalmente.

La terza si concentrava di più sull'informazione spaziale locale, migliorando la fase di fusione convoluzionale.

La quarta combinava entrambe le idee, con una fusione locale più forte e un ragionamento globale basato su Transformer.

![Struttura dettagliata del modello e dimensioni dei tensori](/images/projects/resnet-vit/model-summary.png)

Questa evoluzione è stata più utile che partire direttamente da un'unica architettura complessa. Ogni versione rendeva più chiaro se il modello avesse bisogno di feature locali migliori, più contesto globale oppure di un equilibrio tra le due cose.

## Rispettare l'interfaccia

Qwen si aspetta un tensore con forma `[B, 196, 2048]`. Produrre qualcosa di vagamente simile non basta. L'adapter deve arrivare esattamente alla struttura di token richiesta dal resto del modello.

Le feature di ResNet partono da risoluzioni e dimensioni dei canali molto diverse. L'adapter le proietta in spazi compatibili, fonde le informazioni provenienti da più stage, riduce la parte spaziale e infine genera la sequenza finale.

Questo vincolo rigido ha mantenuto l'esperimento ben definito. Non ho riprogettato Qwen attorno a ResNet. Erano ResNet e l'adapter a doversi adattare al modello già esistente.

## Provare immagini che non hanno quasi nulla in comune

Ho usato esempi molto diversi tra loro perché rendono più facili da notare i fallimenti.

![Carro armato usato come esempio di inferenza](/images/projects/resnet-vit/tank.jpg)

Il carro armato contiene dettagli meccanici, linee nette, testo, cingoli e uno sfondo abbastanza ricco.

![Pecore usate come esempio di inferenza](/images/projects/resnet-vit/sheep.jpg)

L'immagine delle pecore è quasi l'opposto. Ci sono più soggetti simili, forme morbide, texture e una relazione più forte tra primo piano e sfondo.

![Castel del Monte usato come esempio di inferenza](/images/projects/resnet-vit/castle.jpg)

Castel del Monte introduce simmetrie, elementi geometrici ripetuti e una scena molto più ampia.

Queste immagini non costituiscono da sole un benchmark. Sono utili perché un encoder pensato per sostituire un ViT general-purpose non dovrebbe funzionare soltanto su un singolo dominio visivo.

## Fine-tuning dell'intero percorso visivo

Nella prima fase ResNet rimaneva congelato e veniva addestrato soltanto l'adapter. In questo modo il livello di traduzione doveva imparare a lavorare con feature CNN stabili.

Una volta ottenuto un mapping ragionevole, ho sperimentato anche il fine-tuning congiunto. ResNet e adapter venivano allenati insieme usando learning rate differenti, seguiti da un'ulteriore fase dedicata soltanto all'adapter.

Questo lasciava al backbone un po' di libertà per spostarsi verso rappresentazioni più facili da tradurre, senza distruggere subito le feature utili apprese su ImageNet.

Il processo era più lento e delicato, ma trasformava l'esperimento in qualcosa di più di un semplice livello di traduzione sopra una rete congelata. L'intero percorso visivo iniziava ad adattarsi alla rappresentazione attesa da Qwen.

## Cosa mi porto dietro

Prima di questo progetto pensavo soprattutto al Vision Transformer come al componente che permetteva a Qwen di comprendere le immagini.

Dopo averci lavorato ho iniziato a guardare molto di più all'interfaccia tra la parte visiva e quella linguistica.

Il Language Model non vede immagini. Vede tensori.

Naturalmente far combaciare le dimensioni non basta. Due tensori possono avere la stessa forma e rappresentare cose completamente diverse. La difficoltà vera sta nel conservare la struttura latente che il modello linguistico ha imparato a utilizzare.

Per questo il progetto è diventato meno una semplice sostituzione di un Transformer con una CNN e più un tentativo di traduzione tra due spazi di rappresentazione.

Non considero l'implementazione attuale una risposta definitiva. È un esperimento che rende visibile il problema reale e fornisce una pipeline da cui continuare. Obiettivi basati sulla similarità coseno, allineamento contrastivo, adapter più leggeri e valutazioni più sistematiche sono tutte direzioni interessanti.

L'idea centrale, però, ha retto. Un modello multimodale può essere visto come un insieme di componenti collegati da interfacce apprese. Quando una di quelle interfacce viene compresa, parti che sembravano fisse diventano improvvisamente aperte alla sperimentazione.