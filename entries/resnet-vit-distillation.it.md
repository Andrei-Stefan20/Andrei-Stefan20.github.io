---
title: "Sostituire il Vision Transformer di Qwen con ResNet-50"
type: project
layout: case-study
lang: it
slug: resnet-vit-distillation
permalink: /it/entries/resnet-vit-distillation/
date: 2026-07-12
year: 2026
image: "/images/projects/resnet-vit/adapter2.png"
label: "RICERCA"
role: "Deep Learning"
technologies: [PyTorch, ResNet-50, Qwen-VL, Vision Transformers, CNN, Feature Distillation]
code: "https://github.com/Fabb-24/ResNet-to-ViT-Feature-Distillation"
demo: ""
paper: ""
excerpt: "Può una rete convoluzionale sostituire il Vision Transformer dentro un moderno Vision-Language Model? Ho costruito una pipeline di feature distillation che insegna a ResNet-50 a produrre gli embedding visivi attesi da Qwen."
---

I Vision-Language Models vengono spesso presentati come sistemi enormi in cui ogni componente sembra intoccabile. Un'immagine entra da una parte, una risposta testuale esce dall'altra e tutto quello che succede nel mezzo finisce per sembrare una scatola nera.

Io ho voluto togliere uno di quei pezzi e vedere cosa si sarebbe rotto.

Qwen usa normalmente un Vision Transformer per trasformare l'immagine in una sequenza di embedding. La domanda che mi sono posto era se quell'encoder fosse davvero indispensabile oppure se al Language Model interessasse soprattutto ricevere la rappresentazione corretta nel punto di contatto.

Così ho provato a sostituirlo con ResNet-50.

Non riaddestrando da zero tutto il modello multimodale e non modificando la parte linguistica. L'idea era lasciare Qwen invariato e insegnare a un nuovo percorso visivo a produrre qualcosa di abbastanza vicino agli embedding originali del ViT.

## Il vero progetto era l'adapter

![Adapter multi-stage che collega ResNet-50 a Qwen](/images/projects/resnet-vit/adapter2.png)

Sostituire un encoder con un altro richiede pochissimo codice. Rendere il nuovo encoder compatibile con il resto del modello è il punto in cui inizia il lavoro vero.

Un Vision Transformer produce una sequenza piatta di token visivi. ResNet-50 produce mappe di feature gerarchiche con risoluzioni e profondità diverse. I primi livelli conservano bordi, texture e dettagli locali, mentre quelli più profondi contengono informazioni più astratte e semantiche.

Le due architetture non producono soltanto tensori con forme differenti. Descrivono l'immagine in modi completamente diversi.

L'adapter è diventato il traduttore tra i due sistemi.

Riceve feature da più stage di ResNet, le proietta in spazi compatibili, fonde informazione locale e semantica e infine converte il risultato nella sequenza esatta richiesta da Qwen.

Il contratto sull'output è rigido. Il Language Model si aspetta un tensore con forma `[B, 196, 2048]`. Avere le stesse dimensioni è necessario, ma non basta. La rappresentazione deve anche conservare la struttura latente che Qwen ha imparato durante il training multimodale originale.

## Distillare una rappresentazione, non una semplice etichetta

Il Vision Transformer originale di Qwen veniva usato come teacher.

Ogni immagine veniva prima elaborata dall'encoder visivo nativo e gli embedding risultanti venivano salvati. La stessa immagine passava poi attraverso ResNet-50, mentre l'adapter cercava di ricostruire la rappresentazione del teacher partendo dalle feature della CNN.

Il primo obiettivo minimizzava il Mean Squared Error tra gli embedding originali e quelli ricostruiti.

Questo cambia completamente la natura del problema. Il modello non sta imparando direttamente se in un'immagine ci sia un carro armato, un animale o un edificio. Sta imparando il modo in cui Qwen rappresenta internamente quell'immagine prima ancora di generare una parola.

È proprio la parte che mi ha interessato di più. Un tensore può avere la forma corretta ed essere comunque inutile se l'informazione al suo interno vive nella geometria sbagliata.

## Quattro versioni invece di un'unica architettura enorme

Non volevo costruire subito un adapter molto complesso e poi non riuscire più a capire quale parte avesse davvero aiutato.

Il progetto è quindi passato attraverso quattro versioni principali.

La prima era una baseline convoluzionale basata su blocchi di proiezione e fusione. Serviva prima di tutto a verificare che il mapping fosse possibile.

La seconda aggiungeva un Transformer Encoder dopo la fusione delle feature per recuperare una parte delle interazioni globali disponibili naturalmente in un ViT.

La terza si concentrava maggiormente sul contesto spaziale locale e migliorava la fusione convoluzionale.

La quarta combinava entrambe le idee, con un'elaborazione locale più forte e un ragionamento globale basato su Transformer.

Questo percorso è stato più utile che partire direttamente dal modello più grande. Ogni versione rispondeva a una domanda leggermente diversa su ciò che mancava davvero all'adapter.

## Cosa succede davvero ai tensori

![Architettura dettagliata dell'adapter e dimensioni dei tensori](/images/projects/resnet-vit/adapter_architecture.png)

ResNet produce più mappe di feature con risoluzioni spaziali e profondità dei canali differenti. Non si possono semplicemente concatenare e passare al modello sperando che funzioni.

Ogni stage viene prima proiettato in una rappresentazione compatibile. Le feature a risoluzione maggiore conservano più struttura locale, mentre quelle più profonde contribuiscono con informazione più astratta. Il percorso di fusione combina progressivamente questi segnali fino a ottenere una singola rappresentazione visiva.

I blocchi finali trasformano quella rappresentazione in 196 token visivi, ciascuno con dimensionalità 2048.

Questa interfaccia precisa ha mantenuto l'esperimento ben definito. Non ho riprogettato Qwen attorno a ResNet. Erano ResNet e l'adapter a doversi adattare al modello già esistente.

## Addestrare l'intero percorso visivo

Nella prima fase ResNet rimaneva congelato e veniva ottimizzato soltanto l'adapter.

In questo modo il livello di traduzione riceveva una distribuzione di input stabile. ResNet continuava a produrre le feature apprese con il pretraining su ImageNet, mentre l'adapter imparava a trasformarle nello spazio del teacher.

Quando il mapping diventava abbastanza ragionevole, ho sperimentato anche il fine-tuning congiunto. ResNet e adapter venivano allenati insieme usando learning rate differenti, più piccolo per il backbone e maggiore per l'adapter.

A questa fase seguiva un'ulteriore rifinitura del solo adapter.

Lo scopo era lasciare al backbone un po' di libertà per muoversi verso rappresentazioni più facili da tradurre senza distruggere immediatamente le feature utili del pretraining.

## Guardare un'immagine reale

![Carro armato usato come esempio qualitativo di inferenza](/images/projects/resnet-vit/tank.jpg)

Questa immagine è utile perché combina diversi elementi visivi difficili nello stesso momento: linee nette, cingoli, testo, componenti meccaniche e uno sfondo relativamente complesso.

Una rappresentazione debole potrebbe conservare soltanto il concetto generale di “veicolo”, perdendo però i dettagli locali necessari per una descrizione più precisa. L'adapter deve quindi mantenere sia la semantica ad alto livello sia abbastanza struttura spaziale perché il Language Model possa usarla.

L'immagine non è un benchmark da sola. È un controllo qualitativo che rende alcuni fallimenti molto più facili da notare.

## La parte difficile non è far combaciare le dimensioni

Uno degli errori più semplici in un progetto del genere è trattare la compatibilità come un problema puramente dimensionale.

Se Qwen si aspetta `[B, 196, 2048]`, produrre `[B, 196, 2048]` può sembrare un successo. Non lo è.

Due tensori possono avere dimensioni identiche e rappresentare cose completamente diverse. Immagini simili dovrebbero occupare regioni sensate, le relazioni tra token dovrebbero restare coerenti e il Language Model dovrebbe continuare a estrarre informazione utile dalla sequenza.

L'MSE è un buon punto di partenza perché spinge direttamente la rappresentazione student verso quella del teacher. Non garantisce però che tutte le relazioni semantiche importanti vengano conservate.

È qui che i prossimi esperimenti diventano interessanti. Obiettivi basati sulla similarità coseno potrebbero concentrarsi più sulla direzione che sulla magnitudine. Un allineamento contrastivo potrebbe conservare meglio le relazioni tra immagini. Loss downstream potrebbero ottimizzare captioning o visual question answering invece dei soli tensori intermedi.

## Cosa mi porto dietro

Prima di lavorare a questo progetto pensavo soprattutto al Vision Transformer come al componente che permetteva a Qwen di capire le immagini.

Dopo averci lavorato ho iniziato a guardare molto di più al confine tra la parte visiva e quella linguistica.

Il Language Model non vede pixel. Vede tensori prodotti da un altro componente.

Questo non rende il problema semplice. Far combaciare le dimensioni è banale rispetto al mantenere la struttura latente che il modello ha imparato a interpretare. Però, una volta isolata l'interfaccia, componenti che sembravano fissi diventano improvvisamente aperti alla sperimentazione.

Per me è questo il risultato più importante del progetto.

Non è soltanto una CNN che sostituisce un Transformer. È un tentativo di collegare due sistemi di rappresentazione molto diversi senza dover ricostruire tutto il resto attorno a loro.