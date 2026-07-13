---
title: "SLIDERS: orientare la ricerca visiva con feature sparse"
type: project
layout: case-study
lang: it
slug: sliders
permalink: /it/entries/sliders/
date: 2026-07-13
year: 2026
image: "/images/projects/sliders/11_steering_results.png"
thumbnail: "/images/projects/sliders/11_steering_results.png"
cover: "/images/projects/sliders/11_steering_results.png"
cover_alt: "Risultati del retrieval prima e dopo lo steering verso il tessuto fogliare ingiallito"
thumbnail_alt: "Risultati SLIDERS con e senza steering"
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

Una ricerca basata su embedding comprime la query in un vettore e restituisce i vicini più prossimi. Funziona bene quando la similarità desiderata è già espressa nell'immagine iniziale. È meno utile quando si vuole mantenere la struttura generale della query ma modificare una proprietà precisa, come un ingiallimento più marcato, lesioni più scure, venature più evidenti o un diverso bordo della foglia.

Il progetto trasforma queste proprietà in controlli. La query viene modificata prima del retrieval, quindi il ranking cambia perché la rappresentazione si è spostata nello spazio degli embedding, non perché è stato applicato un filtro testuale dopo la ricerca.

![Risultati prima e dopo lo steering verso il tessuto fogliare ingiallito](/images/projects/sliders/11_steering_results.png)

L'implementazione attuale lavora soprattutto sull'evidenza locale. Invece di rappresentare ogni immagine con un solo token globale, conserva i descrittori delle patch, apprende feature sparse direttamente su quelle regioni e usa una ricerca late-interaction.

## Da un'immagine a 256 regioni visive

Il backbone è la variante con register token di DINOv2 ViT-L/14. Ogni immagine viene ridimensionata, ritagliata al centro a `224 × 224` e divisa in una griglia `16 × 16`. Il risultato è composto da 256 patch token, ciascuno con 1024 dimensioni.

![Griglia 16 per 16 applicata all'immagine di input](/images/projects/sliders/01_patch_grid.png)

```text
image
  -> DINOv2 ViT-L/14 registers
  -> 256 patch token
  -> tensore [256, 1024]
```

Usare le patch invece di un singolo embedding CLS mantiene un legame esplicito tra una feature e la regione che l'ha generata. Un vettore globale può indicare che l'immagine contiene una foglia malata, ma non dice quale parte dell'immagine abbia prodotto una determinata attivazione.

![Patch selezionate e relativi token DINOv2 da 1024 dimensioni](/images/projects/sliders/02_patch_tokenization.png)

La variante con register token riduce inoltre il problema di alcune patch con norma anormalmente elevata che non corrispondono chiaramente a contenuto visibile. Un modello sparso potrebbe interpretarle come feature reali.

![Norma L2 dei patch token distribuita sull'immagine](/images/projects/sliders/03_patch_token_norm.png)

Il corpus di patch viene salvato in un array memory-mapped. Ogni riga è collegata all'immagine di origine e i metadati registrano forma della griglia e preprocessing.

## Apprendere un dizionario visivo sparso

Il modello centrale è uno Sparse Autoencoder addestrato direttamente sui patch token DINOv2. La sua struttura è volutamente sovracompleta:

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

L'obiettivo non è comprimere. Il livello nascosto è otto volte più largo dell'input per permettere alle singole unità di specializzarsi. Una feature può restare inattiva per quasi tutte le patch e rispondere soltanto a un pattern preciso.

Ho usato un vincolo TopK con `L0 = 40`: per ogni patch sopravvivono solo le quaranta attivazioni più forti, mentre le altre 8.152 vengono azzerate prima del decoding.

![Codifica sparsa e ricostruzione di un patch token DINOv2](/images/projects/sliders/04_sae_encode_decode.png)

Su una patch rappresentativa, il codice sparso ricostruisce il token con similarità coseno `0.913` usando 40 feature attive. Sulle 256 patch dell'immagine, la similarità coseno media è circa `0.962`. La stessa immagine attiva complessivamente 1.721 feature distinte, ma la maggior parte compare solo in poche patch.

![Utilizzo delle feature e qualità di ricostruzione sulle 256 patch](/images/projects/sliders/05_sae_sparsity.png)

Le loss di training e validazione scendono insieme. L'early stopping seleziona l'epoca 49 e la percentuale di feature morte resta a zero. Le colonne del decoder vengono normalizzate e le feature inattive troppo a lungo vengono riciclate tramite direzioni del residuo.

![Curve di training e validazione dello Sparse Autoencoder](/images/projects/sliders/15_training_curves.png)

Il decoder non serve soltanto a ricostruire. Ogni sua colonna è una direzione nello spazio DINOv2 originale e diventa direttamente una direzione utilizzabile da uno slider.

## Prima di dare un nome a una feature serve evidenza

Un indice come `feature 4625` è utile durante il debug, ma non in un'interfaccia. Per ogni feature il sistema cerca patch con attivazione alta e bassa, estrae crop più ampi e marca la cella attiva.

![Mappa di attivazione spaziale della feature 4625](/images/projects/sliders/06_feature_activation.png)

Il Vision-Language Model riceve gruppi contrastivi e deve individuare la proprietà visiva che separa gli esempi. Un secondo passaggio verifica che il nome proposto sia sostenuto dai dati.

![Esempi ad alta e bassa attivazione usati per nominare una feature](/images/projects/sliders/07_feature_naming.png)

Da questa procedura emergono nomi come `yellowing leaf tissue`, `dark brown lesions`, `brown necrotic spots`, `leaf edge notches`, `bright green veins` e `green leaf veins`.

I crop localizzati rendono l'evidenza verificabile: mostrano la patch attiva nel proprio contesto e aiutano a capire se la feature risponde davvero al pattern desiderato o a un artefatto vicino.

![Crop contestuali con la patch attiva evidenziata](/images/projects/sliders/08_localized_crops.png)

Una galleria più ampia permette poi di verificare se la stessa etichetta rimanga coerente su immagini e condizioni diverse.

![Galleria di feature sparse nominate e relative patch più attive](/images/projects/sliders/14_feature_gallery.png)

## Lo steering è un'operazione geometrica

Uno slider modifica la query sommando una o più direzioni del decoder:

```text
q_steered = normalize(q + sum(alpha_i * d_i))
```

`q` è la patch query, `d_i` è una direzione unitaria del decoder e `alpha_i` è il valore dello slider. I valori positivi spingono la query verso la feature, quelli negativi la allontanano. La normalizzazione riporta il vettore sulla sfera unitaria usata dalla similarità coseno.

![Interpretazione geometrica dello steering e della rinormalizzazione](/images/projects/sliders/12_steering_geometry.png)

La query viene modificata prima della ricerca. Non si tratta quindi di premiare alcuni risultati dopo il retrieval.

Per la feature `yellowing leaf tissue`, l'attivazione media nei risultati cresce rapidamente tra `alpha = 0` e `alpha = 2`, poi tende a saturare. La correlazione di Spearman tra intensità dello slider e attivazione recuperata è `rho = 0.90`.

![Attivazione media della feature target al crescere dello slider](/images/projects/sliders/13_slider_isotonicity.png)

Con `alpha = 0`, i risultati restano vicini alla foglia verde originale. Con `alpha = 6`, il ranking si sposta verso foglie gialle e danneggiate mantenendo l'oggetto e la struttura generale della query.

## Perché il nearest-neighbour globale non bastava

Un embedding globale è veloce e utile per la similarità generale, ma può coprire una proprietà locale con forma, colore medio o sfondo. Il retrieval a livello di patch affronta il problema con la late interaction.

```text
score(Q, C) = sum_j max_k similarity(q_j, c_k)
```

Per ogni patch query `q_j`, il sistema cerca la patch più simile `c_k` nell'immagine candidata. Le 256 similarità migliori vengono poi sommate.

![Matrice di similarità patch-to-patch con massimi MaxSim](/images/projects/sliders/09_maxsim_matrix.png)

Ogni riga rappresenta una patch della query e ogni colonna una patch dell'immagine del corpus. Il massimo selezionato su ogni riga mostra quale regione del candidato spiega meglio quella regione della query. Nell'esempio analizzato, il punteggio MaxSim è `216.3`.

![Immagine query seguita dai risultati migliori secondo MaxSim](/images/projects/sliders/10_maxsim_retrieval.png)

Lo steering viene applicato alle patch della query prima della ricerca MaxSim. Per corpus più grandi, FAISS recupera prima le patch candidate, le riconduce alle immagini e calcola MaxSim esatto solo sui candidati. L'indice può passare a IVF-PQ oltre una soglia configurabile.

## Similarità densa e significato sparso

Lo spazio DINOv2 resta il segnale principale per la similarità visiva generale. Lo spazio SAE è più interpretabile e contiene le direzioni degli slider. SLIDERS può combinare un indice FAISS denso, un indice opzionale sulle attivazioni SAE e vettori precomputati per il reranking.

Le metriche di steering vengono calcolate prima del reranking compensativo, così una regola forte non può nascondere una direzione debole.

## Valutare un sistema di retrieval controllabile

Recall, precision e mean average precision non dicono se uno slider funziona. Ho quindi separato la valutazione in quattro proprietà.

**Faithfulness** misura se lo steering aumenta davvero la feature richiesta rispetto alla baseline.

**Isotonicity** misura se valori maggiori dello slider producono effetti maggiori, tramite correlazione di Spearman.

**Selectivity** misura se cambia soprattutto la feature target invece di alterare indiscriminatamente l'embedding.

**Monosemanticity** stima se una feature nominata corrisponde ripetutamente allo stesso pattern visibile attraverso la purezza delle patch più attive.

![Faithfulness, isotonicity, selectivity e monosemanticity delle feature apprese](/images/projects/sliders/16_metric_distributions.png)

Queste metriche mostrano compromessi che le metriche classiche non evidenziano. Una feature può essere coerente ma troppo debole per spostare il ranking; un'altra può essere forte ma poco selettiva.

## Il ruolo dell'interfaccia

Il frontend consente di caricare la query, applicare steering positivo e negativo, ispezionare esempi forti e deboli, combinare assi e aprire i risultati a piena risoluzione.

![Vista di dettaglio di una feature nell'interfaccia](https://raw.githubusercontent.com/Andrei-Stefan20/SLIDERS/main/docs/assets/slider2.gif)

FastAPI serve gli endpoint e il frontend statico. All'avvio vengono caricati encoder, checkpoint SAE, nomi delle feature, percorsi delle immagini, matrici di attivazione e indici FAISS in uno stato condiviso.

## Stato attuale del progetto

SLIDERS non dimostra che ogni feature sparse sia automaticamente un buon controllo utente. Alcune unità restano miste, alcuni nomi sono più affidabili di altri e valori molto alti possono saturare. Il retrieval a livello di patch richiede inoltre più memoria e calcolo rispetto alla ricerca con un solo vettore per immagine.

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

La stessa feature sparse viene usata in tre punti: si attiva su un'evidenza locale, riceve un nome da quell'evidenza e modifica la query attraverso la propria direzione del decoder. È questo oggetto condiviso a collegare il modello all'interfaccia.