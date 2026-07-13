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

# Sostituire il Vision Transformer di Qwen con ResNet-50

![Confronto tra l'architettura originale di Qwen e quella personalizzata con ResNet-50](/images/projects/resnet-vit/hero.png)

Quando si parla di Vision-Language Models si parte quasi sempre da un presupposto. Le immagini vengono elaborate da un Vision Transformer, trasformate in una sequenza di embedding e poi passate al modello linguistico.

Il sistema nasce così, quindi viene naturale considerare il visual encoder come una parte che non si può toccare più di tanto.

Io ho voluto vedere cosa sarebbe successo toccandola comunque.

La domanda alla base del progetto era abbastanza semplice.

**È possibile sostituire il Vision Transformer di Qwen con ResNet-50 senza riaddestrare tutto il modello linguistico?**

Non cambiando ciò che il Language Model si aspetta di ricevere, ma insegnando a un encoder completamente diverso a produrre una rappresentazione compatibile.

La differenza sembra piccola, ma in realtà è tutto il progetto.

## Togliere il vecchio encoder è la parte facile

Dal punto di vista tecnico, rimuovere il visual encoder originale e inserire un ResNet non è particolarmente difficile.

Fare in modo che il risultato abbia senso è un altro discorso.

Un Vision Transformer produce una sequenza piatta di token visivi. ResNet-50 produce mappe di feature gerarchiche con risoluzioni e profondità diverse. Una delle due architetture descrive l'immagine come una sequenza, mentre l'altra costruisce rappresentazioni spaziali sempre più astratte.

Gli output non hanno la stessa struttura, le stesse dimensioni e neppure lo stesso significato.

Passare direttamente le feature di ResNet a Qwen sarebbe un po' come sostituire un traduttore con qualcuno che parla una lingua completamente diversa e aspettarsi che la conversazione continui normalmente.

Il vero problema non era quindi sostituire l'encoder.

Era costruire il traduttore.

## Insegnare a ResNet a parlare la lingua di Qwen

L'architettura proposta lascia completamente invariato il modello linguistico di Qwen.

![Pipeline visiva originale e personalizzata di Qwen](/images/projects/resnet-vit/hero.png)

Il Vision Transformer originale viene sostituito da due componenti.

Il primo è ResNet-50, usato come nuovo backbone visivo.

Il secondo è un adapter multi-stage che trasforma le feature gerarchiche della CNN nella sequenza di embedding che Qwen si aspetta.

Dal punto di vista del Language Model, l'interfaccia non cambia. Continua a ricevere 196 embedding visivi con dimensionalità 2048. La differenza è che quegli embedding non arrivano più dal Vision Transformer originale.

Vengono ricostruiti a partire dalle feature di ResNet.

Questo ha reso l'adapter il centro vero del progetto. Il suo compito non era classificare un'immagine o prevedere un'etichetta. Doveva imitare una rappresentazione latente prodotta da un'architettura completamente diversa.

## Il target era già dentro il modello

Per addestrare l'adapter ho usato prima il Vision Transformer originale di Qwen come teacher.

Ogni immagine è stata elaborata dall'encoder visivo originale e gli embedding risultanti sono stati salvati. Quei tensori sono diventati il ground truth della nuova pipeline.

La stessa immagine è stata poi passata attraverso ResNet-50. Le sue feature intermedie sono state inviate all'adapter, che ha provato a ricostruire gli embedding prodotti dal teacher.

L'addestramento minimizza il Mean Squared Error tra gli embedding originali del ViT e quelli ricostruiti.

In altre parole, il modello non stava imparando che in un'immagine ci fosse una pecora, un carro armato o un castello. Stava imparando il modo in cui Qwen rappresenta internamente quell'immagine.

È la parte che mi ha interessato di più. Il compito avviene prima della generazione del testo e prima di qualsiasi risposta visibile. Si svolge interamente nello spazio delle rappresentazioni del modello.

## Costruire l'adapter

![Struttura generale dell'adapter multi-stage](/images/projects/resnet-vit/adapter.png)

ResNet produce informazioni utili in più punti della rete.

I primi livelli mantengono dettagli locali come bordi e texture. I livelli più profondi perdono parte della precisione spaziale, ma acquistano più informazione semantica. Ignorare una delle due parti avrebbe significato sprecare proprio ciò che rende utile una CNN.

L'adapter riceve quindi feature provenienti da diversi stage di ResNet e le combina progressivamente.

I projection block allineano le diverse dimensioni dei canali.

I fusion block uniscono le informazioni provenienti dai vari livelli.

I componenti di attenzione e Transformer permettono a zone lontane dell'immagine di interagire.

Il pooling comprime la rappresentazione spaziale.

Il sequence block finale produce esattamente la struttura di token richiesta da Qwen.

L'obiettivo non era costringere ResNet a comportarsi internamente come un Transformer. Volevo lasciargli usare la sua struttura gerarchica naturale e tradurre il risultato soltanto nel punto di contatto con il modello linguistico.

## Quattro versioni, perché fingere che la prima idea funzioni sarebbe stato poco credibile

L'adapter è stato sviluppato attraverso quattro versioni principali.

La prima versione era volutamente semplice e utilizzava blocchi convoluzionali di proiezione e fusione. Mi serviva una base e, soprattutto, una prova che il mapping fosse possibile.

La seconda versione aggiungeva un Transformer Encoder dopo la fusione delle feature. L'idea era recuperare una parte delle interazioni globali che un Vision Transformer possiede naturalmente.

La terza versione si concentrava maggiormente sull'informazione spaziale locale, migliorando la fusione con kernel convoluzionali più ampi.

La quarta combinava entrambe le direzioni, usando una fusione locale migliore insieme al ragionamento globale del Transformer.

Questa è stata probabilmente la parte più utile del lavoro. Invece di guardare soltanto il modello finale, potevo osservare cosa cambiava quando l'adapter acquisiva una visione locale migliore, una visione globale migliore oppure entrambe.

## Cosa riceve davvero il modello

![Riepilogo dettagliato del modello con le forme dei tensori](/images/projects/resnet-vit/model-summary.png)

La forma dell'output non è un semplice dettaglio implementativo.

Qwen si aspetta una sequenza con forma `[B, 196, 2048]`. Se l'adapter produce qualcosa di diverso, il resto del modello non può continuare.

Le feature estratte da ResNet partono da forme molto differenti. A seconda dello stage, possono contenere centinaia o migliaia di canali e avere risoluzioni spaziali diverse.

L'adapter proietta, fonde e comprime queste rappresentazioni fino a ottenere una sequenza compatibile con l'interfaccia originale del ViT.

Questo vincolo rigido è stato utile perché ha mantenuto l'esperimento ben definito. Il Language Model non doveva essere riprogettato attorno al nuovo encoder. Era il nuovo encoder a dover guadagnarsi il posto rispettando il contratto esistente.

## Testare immagini molto diverse

Ho utilizzato immagini appartenenti a categorie visive differenti per verificare che l'encoder personalizzato conservasse informazioni utili anche al di fuori di un singolo dominio.

### Un carro armato

![Carro armato usato come esempio di inferenza](/images/projects/resnet-vit/tank.jpg)

Questa immagine contiene dettagli meccanici, linee nette, testo, cingoli e uno sfondo abbastanza ricco.

### Pecore in un campo

![Pecore usate come esempio di inferenza](/images/projects/resnet-vit/sheep.jpg)

Qui l'informazione importante è completamente diversa. Il modello deve preservare forme, texture, più soggetti simili e la relazione tra primo piano e sfondo.

### Castel del Monte

![Castel del Monte usato come esempio di inferenza](/images/projects/resnet-vit/castle.jpg)

L'architettura introduce un altro tipo di struttura, con simmetrie, elementi geometrici ripetuti e una scena molto più ampia.

Queste immagini non sono state scelte per formare un benchmark. Mi servivano perché rendevano più facili da individuare i fallimenti. Un visual encoder che funziona soltanto su una categoria di immagini non sarebbe un sostituto molto convincente per un ViT general-purpose.

## Fine-tuning dell'intero percorso visivo

Nella prima fase di addestramento ResNet rimaneva congelato e veniva allenato soltanto l'adapter.

Aveva senso iniziare così, perché obbligava il livello di traduzione a lavorare su feature CNN stabili. Una volta ottenuto un mapping ragionevole, ho sperimentato anche il fine-tuning congiunto.

ResNet e adapter sono stati addestrati insieme con learning rate differenti, seguiti da un'ulteriore fase dedicata soltanto all'adapter.

In questo modo il backbone visivo aveva un po' di libertà per spostarsi verso rappresentazioni più facili da tradurre, senza distruggere immediatamente le feature utili apprese su ImageNet.

Il processo era più lento e delicato rispetto all'addestramento del solo adapter, ma rendeva anche l'esperimento più completo. A quel punto il sistema non stava più soltanto traducendo feature ResNet congelate. L'intero percorso visivo si stava adattando alla rappresentazione attesa da Qwen.

## Cosa mi porto dietro

Prima di lavorare a questo progetto pensavo soprattutto al Vision Transformer come al componente che permette a Qwen di comprendere le immagini.

Dopo averci lavorato ho iniziato a guardare molto di più all'interfaccia tra la parte visiva e quella linguistica.

Il Language Model non vede immagini.

Vede tensori.

Finché un altro sistema riesce a produrre tensori con la struttura corretta e abbastanza informazione utile, l'architettura interna che li ha generati può cambiare.

Naturalmente far combaciare le dimensioni non basta. Due tensori possono avere la stessa forma e contenere rappresentazioni completamente diverse. La difficoltà vera sta nel conservare la geometria latente che il modello linguistico ha imparato a utilizzare.

Per questo motivo il progetto è diventato meno una semplice sostituzione di un Transformer con una CNN e più un tentativo di traduzione tra due spazi di rappresentazione.

Non considero l'implementazione attuale come una risposta definitiva. È un esperimento che mostra dove si trova il problema reale e offre una pipeline con cui studiarlo.

Le direzioni da esplorare sono ancora parecchie, tra obiettivi basati sulla similarità coseno, allineamento contrastivo, adapter più leggeri, valutazioni percettive e test più sistematici delle descrizioni generate.

L'idea centrale, però, ha retto.

Un grande modello multimodale può essere visto come un insieme di componenti collegati da interfacce apprese. Quando quell'interfaccia viene compresa, parti che sembravano fisse diventano improvvisamente aperte alla sperimentazione.
