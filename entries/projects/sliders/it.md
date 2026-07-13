---
title: "SLIDERS: ricerca visiva interpretabile con feature steering"
type: project
layout: case-study
lang: it
slug: sliders
permalink: /it/entries/sliders/
date: 2026-07-13
year: 2026
image: "https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif"
thumbnail: "https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif"
cover: "https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif"
cover_alt: "Interfaccia di SLIDERS con immagine query e assi visivi interpretabili"
thumbnail_alt: "Interfaccia di ricerca visiva SLIDERS"
label: "RICERCA"
role: "Interpretable Image Retrieval"
technologies: [Python, PyTorch, DINOv2, Sparse Autoencoders, FAISS, FastAPI, Vision-Language Models]
code: "https://github.com/Andrei-Stefan20/SLIDERS"
demo: ""
paper: ""
excerpt: "Un sistema di image retrieval che espone i concetti visivi appresi come slider, permettendo di orientare i risultati verso o lontano da feature interpretabili."
---

SLIDERS è un sistema di image retrieval costruito attorno a un'interazione molto semplice: si carica un'immagine query, si osservano i concetti visivi scoperti dal modello e si spostano degli slider per cambiare quali caratteristiche devono pesare di più nella ricerca.

Il progetto nasce da un limite dei normali sistemi basati su embedding. Un motore nearest-neighbour può trovare immagini simili, ma di solito non permette all'utente di controllare il motivo di quella similarità. La query viene compressa in un vettore, l'indice restituisce i vettori più vicini e i fattori che determinano il risultato rimangono nascosti.

SLIDERS aggiunge uno strato interpretabile tra l'embedding della query e il motore di retrieval. Invece di trattare l'embedding come una rappresentazione indivisibile, usa uno Sparse Autoencoder per scoprire direzioni associate a pattern visivi ricorrenti. Quelle direzioni diventano controlli interattivi.

![Pannello query e assi di steering appresi](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif)

## Pipeline di retrieval

Il backbone visivo principale è DINOv2. L'immagine query viene trasformata in un embedding normalizzato e confrontata con un indice FAISS contenente gli embedding del dataset.

Senza steering, il flusso è quello classico:

```text
query image
  -> DINOv2 encoder
  -> normalized embedding
  -> FAISS search
  -> ranked image results
```

La differenza appare quando l'utente modifica uno o più slider. Ogni slider corrisponde a una feature appresa. Le direzioni selezionate vengono sommate o sottratte dall'embedding della query prima della ricerca:

```text
q_steered = normalize(q + sum(alpha_i * d_i))
```

Qui `q` è l'embedding originale, `d_i` è una direzione del decoder dello Sparse Autoencoder e `alpha_i` è il valore scelto dall'utente. Un valore positivo spinge la ricerca verso il concetto, uno negativo la allontana.

Il vettore modificato viene poi usato direttamente per la ricerca FAISS. Lo steering non funziona quindi come un filtro applicato dopo il retrieval: cambia la geometria della query prima che inizi la ricerca.

## Scoprire assi visivi con uno Sparse Autoencoder

Lo Sparse Autoencoder trasforma la rappresentazione DINOv2 da 1024 dimensioni in uno spazio nascosto sovracompleto da 8192 attivazioni e ricostruisce poi l'embedding originale:

```text
h = ReLU(W_enc x + b_enc)
x_hat = W_dec h + b_dec
```

La rappresentazione nascosta deve essere sparsa. Per ogni immagine dovrebbe attivarsi soltanto un piccolo insieme di feature. Questo favorisce la separazione di fattori visivi che nello spazio denso originale risultano mescolati.

Le colonne del decoder sono particolarmente utili durante il retrieval. Ogni colonna definisce una direzione nello spazio DINOv2 e può quindi essere usata direttamente per modificare la query. La stessa feature è interpretabile attraverso le sue attivazioni e utilizzabile attraverso la sua direzione di decoding.

Il progetto supporta sia embedding CLS dell'intera immagine sia embedding a livello di patch. Il percorso CLS tende a catturare concetti globali, mentre il training sulle patch permette di apprendere feature locali legate a regioni specifiche.

## Dare un nome alle feature

Un indice numerico non è molto utile se l'interfaccia mostra soltanto etichette come `Feature 1827`.

SLIDERS ordina le immagini che attivano maggiormente ogni feature e presenta gli esempi più rappresentativi a un Vision-Language Model locale. Il VLM cerca il concetto visivo ricorrente e assegna un nome breve all'asse.

Nel caso delle feature addestrate sulle patch, il sistema non mostra soltanto un crop stretto. Mantiene il contesto circostante e evidenzia la regione attiva. Questo è importante perché la causa di un'attivazione può trovarsi vicino alla patch selezionata e non essere perfettamente contenuta al suo interno.

I nomi vengono salvati insieme agli identificatori delle feature e caricati all'avvio dell'applicazione. Se non sono disponibili, l'interfaccia può comunque mostrare le feature ordinate per varianza delle attivazioni.

![Vista di dettaglio di una feature](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider2.gif)

## Unire retrieval denso e sparso

La ricerca non dipende da un solo indice.

L'indice principale lavora nello spazio degli embedding DINOv2. Un secondo indice opzionale lavora invece sulle attivazioni normalizzate dello Sparse Autoencoder. Quando entrambi sono disponibili, il sistema recupera candidati dai due spazi, unisce le liste e applica un nuovo ranking.

Questa struttura a doppio indice è utile perché il significato degli slider vive nello spazio delle feature sparse, mentre la similarità visiva più generale rimane più robusta nello spazio originale di DINOv2.

Il reranking confronta inoltre le feature attive della query con le attivazioni SAE precomputate per ogni candidato. In questo modo il sistema compensa la differenza tra steering nello spazio delle feature e ricerca nearest-neighbour nello spazio denso.

## Retrieval a livello di patch con late interaction

Per i concetti locali, SLIDERS può indicizzare i token patch di DINOv2 invece di usare un solo vettore per immagine.

Una query produce 256 vettori patch. L'indice recupera prima le regioni candidate, poi le immagini vengono valutate con MaxSim: ogni patch della query viene confrontata con la patch più simile dell'immagine candidata e i migliori punteggi vengono sommati.

Questo conserva più struttura locale rispetto a un singolo token CLS. Lo steering viene applicato alle patch della query prima della ricerca, così gli slider possono avere un effetto regionale senza cambiare l'interazione dell'interfaccia.

## Interfaccia e strumenti di ispezione

L'interfaccia non espone soltanto una casella di ricerca. È pensata per rendere il comportamento del modello osservabile.

L'utente può:

- caricare un'immagine query;
- modificare assi positivi e negativi;
- vedere le immagini che attivano maggiormente o minimamente una feature;
- aprire ogni risultato a piena risoluzione;
- copiarne il percorso o scaricarlo;
- resettare la query e confrontare diverse combinazioni di steering.

![Dettaglio di un risultato](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider3.gif)

Il backend è servito tramite FastAPI. Tutti gli artefatti necessari vengono caricati una sola volta all'avvio: embedding, percorsi delle immagini, indici FAISS, pesi SAE, matrici di attivazione e nomi delle feature. In questo modo lo stato del retrieval non viene ricostruito a ogni richiesta.

## Cosa valuta il progetto

SLIDERS non è soltanto un esperimento di interfaccia. Verifica se le feature sparse apprese da un modello visivo forte possano diventare controlli affidabili per il retrieval.

Una buona feature di steering dovrebbe corrispondere a un pattern riconoscibile, modificare i risultati in modo coerente all'aumentare del valore, influenzare poco i concetti non correlati e preservare la query originale quando il valore è vicino a zero.

La valutazione non si limita quindi alle metriche classiche di retrieval. Include misure di monosemanticità, faithfulness, selectivity e comportamento monotono degli slider.

La scelta centrale è mantenere intatta la rappresentazione principale e costruire attorno ad essa uno strato interpretabile. DINOv2 continua a gestire la similarità visiva, FAISS mantiene efficiente la ricerca e lo Sparse Autoencoder fornisce direzioni che una persona può osservare e modificare.

Il risultato è un sistema in cui la similarità non è completamente fissata dall'immagine iniziale. Attraverso gli assi appresi, l'utente può indicare quali aspetti della query devono diventare più importanti e quali invece devono pesare meno.