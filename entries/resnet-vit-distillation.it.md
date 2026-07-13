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

I Vision-Language Models vengono spesso presentati come sistemi enormi e quasi indivisibili. Un'immagine entra da una parte, una risposta testuale esce dall'altra e tutto quello che succede nel mezzo finisce per sembrare fisso.

Io ho voluto togliere uno di quei pezzi e vedere cosa si sarebbe rotto.

Il visual encoder usato da Qwen è un Vision Transformer. Trasforma l'immagine in una sequenza di embedding che il modello linguistico ha imparato a interpretare. La domanda che mi sono posto era se quell'encoder fosse davvero indispensabile oppure se, alla fine, a Qwen interessasse soprattutto ricevere la rappresentazione corretta nel punto di contatto.

Così ho provato a sostituirlo con ResNet-50.

Non riaddestrando da zero l'intero modello multimodale e non modificando il Language Model. L'idea era lasciare Qwen intatto e insegnare a una nuova pipeline visiva a produrre qualcosa di abbastanza vicino agli embedding originali del ViT.

Sembra una differenza piccola, ma in realtà è tutto il progetto.

## Il confronto da cui è partito tutto

![Confronto animato tra il backbone visivo originale e quello personalizzato](https://raw.githubusercontent.com/Fabb-24/ResNet-to-ViT-Feature-Distillation/main/readme_data/models.gif)

A un livello molto generale, i due sistemi sembrano quasi identici. Un'immagine viene codificata, trasformata in token visivi e poi passata al modello linguistico.

La differenza è nascosta dentro il percorso visivo.

L'architettura originale usa direttamente il Vision Transformer di Qwen. Quella personalizzata usa ResNet-50 per estrarre feature gerarchiche e poi invia quelle feature a un adapter addestrabile. L'adapter deve ricostruire la sequenza di token che Qwen riceverebbe normalmente dal suo ViT.

Sulla carta sembra una semplice sostituzione di componenti. In pratica è un problema di traduzione tra due architetture che descrivono le immagini in modi completamente diversi.

## Sostituire l'encoder era la parte facile

Rimuovere un modulo e inserirne un altro richiede pochissimo codice. I problemi iniziano con il primo tensore.

Un Vision Transformer divide l'immagine in patch e produce una sequenza piatta di token. Ogni token vive già in uno spazio di rappresentazione costruito dalla self-attention e dal processo di addestramento multimodale originale.

ResNet-50 fa qualcosa di diverso. Costruisce progressivamente mappe di feature a più risoluzioni. I primi livelli conservano bordi, texture e dettagli locali. I livelli più profondi riducono la precisione spaziale, ma aumentano l'astrazione semantica.

Gli output hanno forme, strutture e significati differenti.

Passare direttamente le feature di ResNet a Qwen sarebbe un po' come sostituire un traduttore con qualcuno che parla una lingua completamente diversa e sperare che la conversazione continui normalmente.

Il vero lavoro non era cambiare l'encoder. Era costruire il traduttore tra i due.

## L'adapter è diventato il progetto vero

![Adapter multi-stage usato per collegare ResNet-50 a Qwen](/images/projects/resnet-vit/adapter.png)

L'adapter riceve feature provenienti da più stage di ResNet invece di usare soltanto l'ultimo livello. È una scelta importante, perché ogni stage contiene un tipo diverso di informazione.

Usare soltanto le feature iniziali significherebbe conservare molti dettagli, ma perdere parte del significato ad alto livello. Usare solo l'ultimo stage manterrebbe più semantica, ma scarterebbe una buona parte della struttura spaziale.

L'adapter deve combinare entrambe.

I projection block portano prima le diverse dimensioni dei canali in spazi compatibili. I fusion block uniscono le informazioni provenienti da più risoluzioni. I componenti di attenzione e Transformer introducono interazioni più ampie tra regioni dell'immagine che un percorso puramente convoluzionale potrebbe faticare a modellare. Infine, la rappresentazione spaziale viene compressa e convertita nella sequenza richiesta da Qwen.

Il contratto sull'output è rigido. Qwen si aspetta un tensore con forma `[B, 196, 2048]`. Produrre lo stesso numero di valori non basta. Anche l'informazione contenuta in quel tensore deve assomigliare alla rappresentazione che il Language Model ha imparato a usare.

Per questo l'adapter non è una semplice proiezione dimensionale. È il ponte tra due modi diversi di rappresentare la visione.

## Il teacher era già dentro Qwen

Il Vision Transformer originale forniva direttamente il target per l'addestramento.

Ogni immagine veniva prima elaborata dall'encoder visivo nativo di Qwen. Gli embedding risultanti venivano salvati e trattati come ground truth. La stessa immagine passava poi attraverso ResNet-50, mentre l'adapter cercava di ricostruire gli embedding del teacher usando le feature della CNN.

Il primo obiettivo era semplice. Ridurre il Mean Squared Error tra la rappresentazione originale del ViT e quella ricostruita.

Questo significa che il modello non stava imparando direttamente se nell'immagine ci fosse un carro armato, una pecora o un castello. Stava imparando il modo in cui Qwen rappresenta internamente quelle immagini prima ancora di produrre una parola.

È una delle parti che mi ha interessato di più, perché tutto il lavoro importante avviene prima che esista una risposta visibile. Il modello può produrre un tensore con la forma corretta e fallire completamente se la struttura latente è sbagliata.

L'esperimento è quindi diventato molto meno un problema di classificazione e molto più un problema di allineamento tra rappresentazioni.

## Quattro adapter invece di una sola architettura finale

Non volevo costruire subito un adapter enorme e poi non riuscire più a capire quale parte avesse davvero aiutato.

Il progetto è quindi passato attraverso quattro versioni.

La prima era una baseline convoluzionale basata su blocchi di proiezione e fusione. Era volutamente semplice. Doveva prima di tutto mostrare se il mapping fosse possibile.

La seconda aggiungeva un Transformer Encoder dopo la fusione delle feature. L'idea era recuperare una parte delle interazioni globali che un Vision Transformer ottiene naturalmente attraverso la self-attention.

La terza andava nella direzione opposta e si concentrava maggiormente sul contesto spaziale locale. Migliorava la fusione con kernel convoluzionali più ampi.

La quarta combinava entrambe le idee. Usava la fusione locale più forte della terza versione insieme al ragionamento globale introdotto nella seconda.

Questo percorso è stato più utile che partire direttamente dal modello più grande. Ogni versione rispondeva a una domanda leggermente diversa. Mancavano soprattutto feature locali migliori? Il problema era il contesto globale? Oppure serviva un equilibrio tra i due?

## Cosa succede davvero ai tensori

![Struttura dettagliata del modello e dimensioni dei tensori](/images/projects/resnet-vit/model-summary.png)

ResNet produce più mappe di feature con risoluzioni spaziali e profondità dei canali differenti. L'adapter non può semplicemente concatenarle tutte e sperare che funzioni.

Ogni stage viene proiettato in una rappresentazione compatibile. Le mappe con maggiore risoluzione vengono compresse progressivamente, mentre quelle più profonde contribuiscono con informazione più astratta. La fusione combina ripetutamente questi segnali fino ad arrivare a una rappresentazione visiva unica.

I blocchi finali trasformano questa rappresentazione in 196 token visivi, ciascuno con dimensionalità 2048.

Questa interfaccia precisa ha mantenuto il progetto ben definito. Non ho riprogettato Qwen attorno a ResNet e non ho modificato il Language Model per accettare output arbitrari da una CNN. Erano ResNet e l'adapter a doversi adattare al sistema esistente.

Il vincolo rende l'esperimento più difficile, ma anche più interessante. Un encoder sostitutivo dovrebbe rispettare il sistema che trova, non costringere ogni componente successivo a cambiare attorno a lui.

## L'addestramento era soltanto la prima fase

Nella fase iniziale ResNet rimaneva congelato e veniva ottimizzato soltanto l'adapter.

In questo modo il livello di traduzione riceveva una distribuzione di input stabile. ResNet continuava a produrre le feature apprese su ImageNet, mentre l'adapter imparava a trasformarle nello spazio del teacher.

Una volta raggiunto un mapping ragionevole, ho sperimentato anche il fine-tuning congiunto. ResNet e adapter venivano addestrati insieme usando learning rate differenti. Il backbone riceveva un learning rate più piccolo, mentre l'adapter restava più libero di adattarsi.

Dopo questa fase seguiva un'ulteriore rifinitura del solo adapter.

Lo scopo era lasciare al backbone un po' di libertà per muoversi verso rappresentazioni più facili da tradurre, senza distruggere immediatamente le feature utili del pretraining.

Questa fase era più lenta e delicata, ma cambiava anche la natura dell'esperimento. Il sistema non stava più soltanto traducendo una rappresentazione CNN congelata. L'intero percorso visivo iniziava ad adattarsi all'interfaccia latente attesa da Qwen.

## Perché ho usato immagini molto diverse

Un encoder pensato per sostituire un ViT general-purpose non dovrebbe funzionare bene soltanto su una categoria molto stretta di input.

Ho quindi scelto esempi visivamente lontani tra loro. Non costituiscono da soli un benchmark completo, ma rendono più facili da notare fallimenti differenti.

### Struttura meccanica e sfondo complesso

![Carro armato usato come esempio di inferenza](/images/projects/resnet-vit/tank.jpg)

L'immagine del carro armato contiene linee nette, cingoli, componenti meccaniche, testo e uno sfondo relativamente ricco. Conservare questo tipo di scena richiede attenzione sia ai piccoli dettagli sia alla struttura generale dell'oggetto.

Una rappresentazione che mantiene soltanto la semantica più larga potrebbe capire che si tratta di un veicolo, ma perdere le informazioni necessarie per descriverlo bene.

### Soggetti ripetuti e texture naturali

![Pecore usate come esempio di inferenza](/images/projects/resnet-vit/sheep.jpg)

L'immagine delle pecore presenta quasi il problema opposto. Ci sono più soggetti simili, forme morbide, texture irregolari e una relazione più forte tra primo piano e sfondo.

L'encoder deve conservare il fatto che nella scena ci siano più animali, non semplicemente un oggetto generico. Deve anche mantenere abbastanza informazione spaziale per distinguere i soggetti dal campo che li circonda.

### Simmetria e scena più ampia

![Castel del Monte usato come esempio di inferenza](/images/projects/resnet-vit/castle.jpg)

Castel del Monte introduce geometria, simmetria, elementi architettonici ripetuti e una composizione molto più ampia.

Qui le sole feature locali non bastano. Comprendere la scena richiede di collegare dettagli lontani tra loro senza perdere l'organizzazione generale della struttura.

Messi insieme, questi esempi impongono richieste molto diverse alla rappresentazione visiva. Dettagli meccanici, soggetti organici ripetuti e geometria architettonica su larga scala dovrebbero tutti sopravvivere al passaggio attraverso ResNet e adapter.

## La parte difficile non è la forma del tensore

Uno degli errori più facili in un progetto del genere è trattare la compatibilità come un semplice problema di dimensioni.

Se Qwen si aspetta `[B, 196, 2048]`, produrre `[B, 196, 2048]` può sembrare un successo. Non lo è.

Due tensori possono avere dimensioni identiche e rappresentare cose completamente diverse. Il Language Model ha imparato a usare la geometria dello spazio degli embedding originale. Immagini simili dovrebbero occupare regioni sensate, i concetti visivi dovrebbero essere codificati in modo coerente e le relazioni tra token dovrebbero conservare abbastanza informazione per la generazione.

Il Mean Squared Error è un buon punto di partenza perché spinge direttamente la rappresentazione student verso quella del teacher. Non garantisce però che tutte le relazioni semantiche importanti vengano mantenute.

È qui che il lavoro futuro diventa interessante. Obiettivi basati sulla similarità coseno potrebbero concentrarsi più sulla direzione che sulla magnitudine assoluta. L'allineamento contrastivo potrebbe preservare meglio le relazioni tra immagini. Loss percettive o downstream potrebbero ottimizzare direttamente la qualità delle descrizioni invece di guardare soltanto ai tensori intermedi.

La pipeline attuale rende possibili questi esperimenti perché separa già l'estrazione degli embedding, l'addestramento dell'adapter, il fine-tuning, la valutazione e l'inferenza con l'encoder personalizzato.

## Cosa migliorerei come prossimo passo

La prima cosa sarebbe una valutazione più sistematica del testo generato.

L'MSE dice se due tensori sono numericamente vicini, ma non dice fino in fondo se Qwen riesce a usarli allo stesso modo. Una valutazione più forte dovrebbe confrontare caption, visual question answering e consistenza semantica tra encoder originale e personalizzato.

Esplorerei anche adapter più piccoli. Parte dell'interesse nel sostituire il ViT è verificare se si possa ottenere un percorso visivo più efficiente, quindi un adapter troppo grande rischia di annullare il vantaggio pratico.

Un'altra direzione sarebbe la distillazione layer-wise o token-wise. Invece di allineare soltanto la sequenza finale, il training potrebbe preservare relazioni a più livelli.

Infine, vorrei verificare se la stessa idea si trasferisce ad altri modelli multimodali. Se l'interfaccia può essere appresa in modo affidabile, l'approccio non dovrebbe dipendere da una singola versione di Qwen.

## Cosa mi porto dietro

Prima di lavorare a questo progetto pensavo soprattutto al Vision Transformer come al componente che permetteva a Qwen di capire le immagini.

Dopo averci lavorato ho iniziato a guardare molto di più al confine tra la parte visiva e quella linguistica.

Il Language Model non vede pixel. Vede tensori prodotti da un altro componente.

Questo non rende il problema semplice. Far combaciare le dimensioni è banale rispetto al mantenere la struttura latente che il modello ha imparato a interpretare. Però, una volta isolata l'interfaccia, componenti che sembravano fissi diventano improvvisamente aperti alla sperimentazione.

Per me è questo il risultato più importante del progetto.

Non è soltanto una CNN che sostituisce un Transformer. È un tentativo di capire come collegare due sistemi di rappresentazione molto diversi senza dover ricostruire tutto il resto attorno a loro.

Non considero l'implementazione attuale una risposta definitiva e non voglio presentarla come tale. È una pipeline di ricerca funzionante che rende visibile il problema reale e offre una base concreta per esplorare obiettivi migliori, architetture più leggere e valutazioni più forti.

Era esattamente quello che volevo ottenere.