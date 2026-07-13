---
title: "SLIDERS: orientare la ricerca visiva con feature sparse"
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
cover_alt: "Interfaccia di SLIDERS con immagine query e controlli visivi appresi"
thumbnail_alt: "Interfaccia di ricerca visiva SLIDERS"
label: "RICERCA"
role: "Interpretable Image Retrieval"
technologies: [Python, PyTorch, DINOv2, Sparse Autoencoders, FAISS, FastAPI, Vision-Language Models]
code: "https://github.com/Andrei-Stefan20/SLIDERS"
demo: ""
paper: ""
excerpt: "Un sistema di image retrieval a livello di patch in cui feature visive sparse diventano controlli nominati per modificare il ranking durante la ricerca."
---

La maggior parte dei sistemi di image retrieval risponde a una sola domanda: quali immagini sono più vicine alla query?

SLIDERS ne aggiunge una seconda: **vicine rispetto a quale caratteristica visiva?**

Una ricerca basata su embedding comprime la query in un vettore e restituisce i vicini più prossimi. Funziona bene quando la nozione di similarità desiderata è già espressa nell'immagine iniziale. È meno utile quando si vuole mantenere la struttura generale della query, ma cambiare una proprietà precisa, come una maggiore ingiallimento, lesioni più scure, venature più evidenti o un diverso bordo della foglia.

Il progetto trasforma queste proprietà in controlli. L'utente carica un'immagine, osserva le feature visive scoperte dal modello e ne modifica il peso attraverso slider. La query viene alterata prima del retrieval, quindi il ranking cambia perché si è spostata la rappresentazione, non perché è stato applicato un filtro testuale alla fine.

![Pannello query e assi di steering appresi](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider.gif)

L'implementazione attuale si concentra sull'evidenza locale. Invece di rappresentare ogni immagine con un solo token globale, conserva i descrittori delle patch, apprende feature sparse direttamente su quelle regioni e usa una ricerca late-interaction. È una pipeline più complessa di una normale demo FAISS, ma rende i controlli molto più interpretabili.

## Da un'immagine a 256 regioni visive

Il backbone è la variante con register token di DINOv2 ViT-L/14. Ogni immagine viene ridimensionata, ritagliata al centro a `224 × 224` e divisa in una griglia `16 × 16`. Il risultato è composto da 256 patch token, ciascuno con 1024 dimensioni.

```text
image
  -> DINOv2 ViT-L/14 registers
  -> 256 patch token
  -> tensore [256, 1024]
```

Usare le patch invece di un singolo embedding CLS cambia ciò che il resto del sistema può apprendere. Un vettore globale può indicare che l'immagine contiene una foglia malata, ma non mantiene un legame esplicito tra una feature e la regione che l'ha generata. I patch token conservano quel legame spaziale.

La variante con register token è importante per un altro motivo. I Vision Transformer possono produrre alcune attivazioni di patch con norma molto elevata che non corrispondono chiaramente a contenuto visibile. Un modello sparso rischierebbe di interpretarle come feature reali. I register token assorbono buona parte di questo comportamento e rendono i token spaziali più adatti al dictionary learning.

Il corpus di patch viene salvato in un array memory-mapped invece di essere caricato interamente in RAM. Ogni riga è collegata all'identificatore dell'immagine di origine, mentre i metadati registrano la forma della griglia e il preprocessing. È una parte meno appariscente del progetto, ma rende pratici gli esperimenti su grandi quantità di patch.

## Apprendere un dizionario visivo sparso

Il modello centrale è uno Sparse Autoencoder addestrato direttamente sui patch token di DINOv2.

La sua struttura è volutamente sovracompleta:

```text
patch token da 1024 dimensioni
        -> encoder
codice sparso da 8192 dimensioni
        -> decoder
ricostruzione da 1024 dimensioni
```

Formalmente:

```text
h = ReLU(W_enc x + b_enc)
x_hat = W_dec h + b_dec
```

L'obiettivo non è comprimere. Il livello nascosto è otto volte più largo dell'input perché servono abbastanza unità da permettere una reale specializzazione. In un autoencoder stretto, le stesse unità devono partecipare alla ricostruzione di pattern molto diversi. Nel modello sovracompleto, una feature può rimanere inattiva quasi sempre e rispondere soltanto a una proprietà specifica.

Ho usato un vincolo TopK con `L0 = 40`. Per ogni patch sopravvivono solo le quaranta attivazioni più alte; le altre 8.152 vengono azzerate prima del decoding. Questo rende il budget di sparsità esplicito e facile da controllare.

Su una patch rappresentativa, il codice sparso ricostruisce il token originale con similarità coseno `0.913` usando soltanto 40 feature attive. Sulle 256 patch dell'immagine analizzata, la similarità coseno media di ricostruzione è circa `0.962`. La stessa immagine attiva complessivamente 1.721 feature distinte, ma la maggior parte compare solo in poche patch. È il comportamento desiderato: il dizionario viene usato in modo ampio nell'immagine, mentre le singole feature restano locali.

Le loss di training e validazione scendono insieme. L'early stopping seleziona l'epoca 49 e la percentuale di feature morte resta a zero. Le colonne del decoder vengono normalizzate dopo l'ottimizzazione, così due slider con lo stesso valore numerico corrispondono a direzioni di magnitudine comparabile. Le feature inattive per troppo tempo vengono riciclate usando le direzioni del residuo, evitando che il dizionario perda capacità senza che sia evidente.

Il decoder non serve soltanto a ricostruire. Ogni sua colonna è una direzione a norma unitaria nello spazio DINOv2 originale. Quelle colonne diventano direttamente le direzioni degli slider.

## Prima di dare un nome a una feature serve evidenza

Un indice come `feature 4625` è utile durante il debug, ma non in un'interfaccia. Il naming delle feature è quindi una pipeline separata, non un'aggiunta cosmetica.

Per ogni feature candidata, il sistema cerca nel corpus le patch con attivazione più alta e quelle con attivazione bassa o nulla. Al Vision-Language Model non viene mostrata soltanto la patch isolata. Viene estratto un crop più ampio e viene evidenziata la cella attiva. Questo mantiene il contesto necessario per interpretare la regione senza fingere che la causa dell'attivazione sia sempre contenuta perfettamente in una patch `14 × 14`.

Il VLM riceve gruppi contrastivi:

- patch in cui la feature si attiva fortemente;
- patch in cui la feature è assente o debole;
- il contesto dell'immagine con la regione attiva marcata.

Gli viene chiesto di individuare la proprietà visiva che separa i due gruppi. Un secondo passaggio verifica che il nome proposto sia realmente sostenuto dagli esempi. Le etichette generiche o poco affidabili possono essere rifiutate invece di essere mostrate come corrette.

Da questa procedura emergono nomi come:

- `yellowing leaf tissue`;
- `dark brown lesions`;
- `brown necrotic spots`;
- `leaf edge notches`;
- `bright green veins`;
- `green leaf veins`.

Non sono semplici didascalie aggiunte dopo il training. Le mappe di attivazione mostrano dove la feature risponde e le gallerie delle patch più forti permettono di controllare se l'unità è coerente su foglie differenti. Nel caso della feature 4625, le attivazioni più alte si concentrano ripetutamente sul tessuto ingiallito, non sull'intera foglia o sullo sfondo grigio.

![Vista di dettaglio di una feature nell'interfaccia](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider2.gif)

## Lo steering è un'operazione geometrica

Uno slider modifica la query sommando una o più direzioni del decoder:

```text
q_steered = normalize(q + sum(alpha_i * d_i))
```

`q` è la patch query, `d_i` è una direzione unitaria del decoder e `alpha_i` è il valore dello slider. I valori positivi spingono la query verso la feature, quelli negativi la allontanano. La normalizzazione riporta il risultato sulla sfera unitaria usata dalla similarità coseno.

Non è equivalente a premiare alcuni candidati dopo il retrieval. La query viene modificata prima della ricerca e il nuovo vettore viene usato direttamente nell'indice. Il risultato deve quindi emergere dalla geometria appresa e non da una regola di categoria scritta a mano.

Uno slider utile deve avere un comportamento regolare. Aumentando il valore, la feature selezionata dovrebbe aumentare progressivamente nei risultati. Per la feature `yellowing leaf tissue`, l'attivazione media nei risultati cresce rapidamente tra `α = 0` e `α = 2`, poi tende a saturare. La correlazione di Spearman tra intensità dello slider e attivazione recuperata è `ρ = 0.90`.

Il confronto qualitativo è chiaro. Con `α = 0`, i risultati rimangono vicini alla foglia verde originale. Con `α = 6`, il ranking si sposta verso foglie gialle e danneggiate, mantenendo però l'oggetto e la struttura generale della query.

Questo è il comportamento che l'interfaccia deve rendere visibile: non un nuovo prompt testuale e non un filtro di classe, ma un movimento controllato lungo una direzione appresa dalla rappresentazione visiva stessa.

## Perché il nearest-neighbour globale non bastava

Una prima versione del sistema usava un solo embedding globale per immagine. È un percorso veloce e ancora utile per la similarità generale, ma indebolisce il rapporto tra una feature locale e il risultato.

Supponiamo che lo slider rappresenti una piccola lesione marrone. L'embedding globale può muoversi nella direzione corretta e continuare a premiare immagini simili per forma, colore medio o sfondo, anche se non contengono davvero la lesione desiderata. La proprietà locale viene facilmente coperta dalla similarità complessiva.

Il retrieval a livello di patch affronta il problema con la late interaction. Query e immagini del corpus sono entrambe insiemi di patch vector. Le immagini candidate vengono valutate con MaxSim:

```text
score(Q, C) = sum_j max_k similarity(q_j, c_k)
```

Per ogni patch query `q_j`, il sistema cerca la patch più simile `c_k` nell'immagine candidata. Le 256 similarità migliori vengono poi sommate. Nell'esempio analizzato, il punteggio MaxSim risultante è `216.3`.

La matrice di similarità rende visibile il calcolo. Ogni riga rappresenta una patch della query e ogni colonna una patch dell'immagine del corpus. Il massimo scelto su ogni riga mostra quale regione del candidato spiega meglio quella regione della query. Il punteggio finale nasce quindi da molte corrispondenze locali, non da un unico vettore aggregato.

Lo steering viene applicato alle patch della query prima della ricerca MaxSim. Una direzione associata al tessuto giallo può modificare i descrittori locali rilevanti, mentre le altre patch continuano a conservare forma, texture e contesto.

Per corpus più grandi, l'indice patch usa FAISS e può passare a IVF-PQ oltre una soglia configurabile. L'indice recupera prima patch candidate, le riconduce agli identificatori delle immagini e calcola MaxSim esatto solo sulle immagini candidate. Questo rende la late interaction gestibile senza confrontare ogni possibile coppia di patch.

## Similarità densa e significato sparso

Il sistema mantiene due rappresentazioni complementari.

Lo spazio DINOv2 originale resta il segnale più forte per la similarità visiva generale. Lo spazio SAE è più interpretabile e contiene le direzioni controllate dagli slider. SLIDERS può quindi combinare:

1. un indice FAISS sugli embedding DINOv2;
2. un indice opzionale sulle attivazioni SAE normalizzate;
3. vettori di attivazione precomputati usati nel reranking.

Le liste provenienti dagli indici denso e sparso possono essere unite, normalizzate e riordinate in base alle feature attive. Questo è utile quando una direzione è semanticamente chiara nello spazio SAE ma non produce da sola uno spostamento abbastanza forte nello spazio denso.

Le metriche di steering vengono calcolate prima di questo reranking compensativo. In caso contrario, una regola di reranking forte potrebbe nascondere una direzione debole e far sembrare l'interfaccia più fedele di quanto sia realmente la rappresentazione.

## Valutare un sistema di retrieval controllabile

Recall, precision e mean average precision restano necessari, ma non dicono se uno slider funziona.

Ho separato la valutazione in quattro proprietà aggiuntive.

### Faithfulness

La faithfulness misura se lo steering aumenta davvero la feature richiesta nei risultati. Confronta l'attivazione target dopo lo steering con la baseline senza steering. Diverse direzioni apprese producono incrementi moltiplicativi elevati, soprattutto quelle legate a punte verdi, venature chiare e lesioni scure.

### Isotonicity

L'isotonicity verifica che valori maggiori dello slider producano effetti maggiori. La misuro con la correlazione di Spearman tra `α` e l'attivazione media della feature target nei risultati. Un punteggio alto indica un controllo prevedibile invece di salti casuali tra regioni non correlate dello spazio.

### Selectivity

Uno slider dovrebbe influenzare la feature desiderata più delle altre. La selectivity misura la quota on-target del cambiamento di attivazione. Serve a distinguere un controllo realmente specifico da uno che sembra efficace soltanto perché altera in modo ampio l'embedding.

### Monosemanticity

Una unità nominata dovrebbe corrispondere ripetutamente allo stesso pattern visibile. La monosemanticity viene stimata tramite la purezza delle patch con attivazione più alta. Le feature migliori raggiungono una purezza elevata, mentre quelle più deboli mostrano dove il dizionario sta ancora mescolando concetti differenti.

Queste metriche evidenziano un compromesso che le metriche classiche non mostrano. Una feature può essere visivamente coerente ma troppo debole per cambiare il ranking. Un'altra può spostare molto i risultati ma influenzare più concetti contemporaneamente. Uno slider utile deve essere sia interpretabile sia controllabile.

## Il ruolo dell'interfaccia

Il frontend non è soltanto un involucro per il modello. Espone gli strumenti necessari per ispezionare il comportamento:

- caricare o sostituire l'immagine query;
- applicare steering positivo e negativo;
- vedere gli esempi con attivazione più alta e più bassa;
- confrontare combinazioni di assi;
- aprire i risultati a piena risoluzione;
- copiare o scaricare il file originale;
- resettare la query senza ricaricare il modello.

![Modale di ispezione di un risultato](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider3.gif)

FastAPI serve gli endpoint e il frontend statico. All'avvio vengono caricati encoder, checkpoint SAE, nomi delle feature, percorsi delle immagini, matrici di attivazione e indici FAISS in uno stato condiviso. Le richieste devono quindi eseguire solo encoding e retrieval, senza ricostruire ogni volta le risorse del modello.

## Stato attuale del progetto

SLIDERS non dimostra che ogni feature sparse sia automaticamente un buon controllo utente. Alcune unità restano miste, alcuni nomi sono più affidabili di altri e valori molto alti degli slider possono saturare. Il retrieval a livello di patch richiede inoltre più memoria e calcolo rispetto alla ricerca con un solo vettore per immagine.

Il progetto offre però un percorso completo dalla rappresentazione all'interazione:

```text
immagini
  -> patch token DINOv2
  -> Sparse Autoencoder
  -> evidenza locale delle feature
  -> nomi prodotti dal VLM
  -> direzioni del decoder
  -> steering della query
  -> retrieval MaxSim
  -> metriche di faithfulness e interpretabilità
```

La scelta più importante è stata evitare di trattare l'interpretabilità come una spiegazione grafica aggiunta dopo il retrieval. La stessa feature sparse viene usata in tre punti: si attiva su un'evidenza locale, riceve un nome da quell'evidenza e modifica la query attraverso la propria direzione del decoder.

È questo oggetto condiviso a collegare il modello all'interfaccia. Lo slider non è un controllo arbitrario associato a una regola. È una direzione appresa di cui si possono osservare esempi, posizione, effetto e limiti.