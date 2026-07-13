---
title: "Il collo di bottiglia non era l'LLM: cosa ha migliorato davvero il Text-to-SPARQL"
type: article
layout: article
lang: it
slug: text-to-sparql-bottleneck
permalink: /it/entries/text-to-sparql-bottleneck/
date: 2026-06-22
category: "Knowledge Graph"
read_time: 9
excerpt: "Un ablation study sulla generazione Text-to-SPARQL ha mostrato che un entity linking affidabile conta molto più di esempi aggiuntivi, schema hints o prompt sempre più complessi."
---

I Large Language Model riescono a generare SPARQL dall'aspetto convincente molto prima di riuscire a generare SPARQL realmente corretto.

Questa differenza è diventata il problema centrale dei miei esperimenti sulla traduzione di domande in linguaggio naturale in query eseguibili su Wikidata. La sintassi prodotta era spesso valida. La query conteneva prefissi, variabili, triple pattern e filtri nei punti giusti. Nonostante questo, poteva restituire una risposta errata o nessun risultato, perché bastava un solo identificatore di entità o proprietà sbagliato.

Il modello non falliva soprattutto nello scrivere SPARQL. Falliva nel collegare il linguaggio usato da una persona agli identificatori usati dal Knowledge Graph.

## Il task

Il progetto usa domande del benchmark QALD-10 e chiede al modello di generare SPARQL per Wikidata. Una domanda può citare una persona, un luogo, un'opera o un evento storico con parole normali, mentre la query finale deve usare identificatori come `Q42` o `P31`.

La pipeline è stata costruita come un insieme di componenti configurabili in modo indipendente:

```text
domanda in linguaggio naturale
  -> entity linking
  -> retrieval di esempi simili
  -> schema hints
  -> costruzione del prompt
  -> generazione con LLM
  -> validazione sintattica ed esecuzione
  -> query SPARQL
```

Ho confrontato GPT-4o, GPT-4o-mini e Llama 3.3 70B, variando attorno a essi il linker, gli esempi few-shot recuperati con FAISS, i suggerimenti sulle proprietà Wikidata e strategie di prompting come decomposition e self-consistency.

Il valore di questa impostazione non era ottenere soltanto un punteggio finale. Ogni componente poteva essere attivato o rimosso, rendendo possibile misurare il suo contributo reale.

## Perché non è semplice code generation

La generazione SPARQL viene spesso presentata come un altro problema di generazione strutturata, simile al Text-to-SQL. Il confronto è corretto solo in parte.

Un database relazionale espone in genere uno schema controllato dall'applicazione. Tabelle e colonne hanno nomi leggibili, sono in numero limitato e possono essere mostrate al modello. Wikidata contiene invece milioni di entità e proprietà identificate da QID e PID opachi. La domanda non rivela questi identificatori.

La parola `Mercury`, per esempio, può indicare un pianeta, un elemento chimico, una divinità romana, un giornale, un'etichetta discografica o una persona. Un modello può comprendere la frase e selezionare comunque il nodo Wikidata sbagliato. Da quel momento, anche una query costruita perfettamente rimane semanticamente errata.

Esistono quindi due problemi distinti:

1. capire il significato inteso della menzione;
2. collegare quel significato all'identificatore corretto del Knowledge Graph.

Il prompting può aiutare con il primo punto. Non può risolvere in modo affidabile il secondo senza accesso al grafo o a un componente di retrieval.

## Il miglioramento principale arrivava dall'entity linking

Sul test set completo di 394 domande, le configurazioni senza entity linking ottenevano un macro F1 di circa 5–8%. Aggiungendo il linker, il risultato saliva approssimativamente al 17–20%, a seconda del modello e del prompt.

Si tratta di un miglioramento di due o tre volte prodotto da un solo componente. Nessuna delle altre aggiunte ha avuto un effetto della stessa dimensione.

Le configurazioni migliori raggiungevano circa il 24–25% di macro F1. GPT-4o beneficiava maggiormente della decomposition, mentre GPT-4o-mini e Llama 3.3 70B risultavano più competitivi con la self-consistency. Queste strategie erano utili, ma soprattutto dopo aver fornito alla pipeline entità plausibili.

Questo ha cambiato il modo in cui interpretavo gli errori. Un punteggio finale basso non significava necessariamente che il modello non sapesse ragionare sulla domanda. In molti casi ragionava sul nodo sbagliato.

## Una query valida può essere comunque sbagliata

Una query generata può fallire a livelli differenti:

- sintassi SPARQL non valida;
- query valida ma non eseguibile;
- query valida che non restituisce binding;
- query eseguibile che restituisce l'entità sbagliata;
- entità corretta ma relazione errata;
- struttura diversa dalla gold query ma risposta comunque corretta.

La validazione sintattica rileva soltanto il primo caso. La validazione tramite esecuzione identifica alcuni dei due successivi. Nessuna delle due dimostra che gli identificatori selezionati corrispondano davvero all'intento dell'utente.

Per questo anche la correzione automatica ha limiti precisi. Restituire al modello un errore di esecuzione può correggere una parentesi mancante, un filtro malformato o una variabile non valida. Non sempre può capire che `Apple` è stata collegata al frutto invece che all'azienda, soprattutto se entrambi gli identificatori producono risultati validi.

## Il few-shot retrieval non aiutava automaticamente

La pipeline recupera con FAISS domande di training simili e inserisce nel prompt le relative query SPARQL. L'aspettativa era semplice: gli esempi avrebbero mostrato strutture ricorrenti e uso corretto degli identificatori Wikidata.

In pratica, il few-shot retrieval senza un entity linking affidabile spesso funzionava peggio della generazione senza contesto.

Il problema non era che gli esempi fossero sempre irrilevanti. Potevano essere simili dal punto di vista linguistico e richiedere una struttura del grafo diversa. Una domanda sul coniuge di una persona può somigliare a una su un collaboratore, un creatore o un membro del cast. Copiare la struttura visibile dell'esempio può portare il modello verso la proprietà sbagliata.

Gli esempi introducono inoltre altri identificatori nel contesto. Quando le entità target non sono già state risolte, il modello può copiare un QID o una relazione perché sembrano adatti dal punto di vista strutturale.

La conclusione non è che il few-shot prompting sia inutile. È che gli esempi devono essere selezionati e ancorati rispetto alla parte del problema che devono risolvere. La sola similarità semantica tra domande non basta.

## Anche gli schema hints possono distrarre

Ho testato anche suggerimenti sulle proprietà recuperati dallo schema di Wikidata. In teoria, fornire PID candidati dovrebbe ridurre la necessità per il modello di ricordare le relazioni.

L'effetto è stato misto. Quando l'entity linking era già attivo, gli schema hints riducevano spesso il macro F1 invece di migliorarlo.

Una lista di proprietà plausibili amplia lo spazio di scelta del modello. Alcune relazioni hanno descrizioni sovrapposte e la distinzione emerge solo osservando dominio, range e contesto del grafo. Mostrare molti candidati può rendere il prompt apparentemente più informativo, ma anche più incerto.

Questo suggerisce che lo schema retrieval dovrebbe essere selettivo. È più utile quando il modello è davvero incerto su una relazione, non quando viene aggiunto a ogni domanda per impostazione predefinita. Una versione successiva dovrebbe recuperare proprietà in modo condizionale, usando le entità già collegate e la forma attesa della query.

## Il prompt engineering aiutava, ma non eliminava il collo di bottiglia

La decomposition chiede al modello di separare una domanda complessa in decisioni più piccole prima di produrre la query finale. La self-consistency genera più candidati e ne seleziona o aggrega il risultato. Entrambe hanno migliorato alcune configurazioni.

I loro guadagni rimanevano però molto più piccoli rispetto a quello prodotto dall'entity linking.

È una distinzione pratica importante. Più ragionamento non compensa un grounding errato. Può invece generare una spiegazione più lunga e coerente costruita sull'interpretazione sbagliata.

I prompt migliori funzionavano perché operavano su input migliori. Una volta disponibili i QID rilevanti, la decomposition poteva concentrarsi su join, filtri, ordinamento e aggregazioni invece di indovinare a quali nodi del grafo facesse riferimento la domanda.

## Cosa cambierei nella prossima versione

La pipeline attuale tratta l'entity linking come preprocessing. Gli esperimenti suggeriscono che dovrebbe diventare uno strumento richiamabile durante la generazione.

Invece di ricevere una lista fissa di entità, il modello potrebbe avviare una ricerca quando incontra una menzione ambigua. Lo strumento restituirebbe candidati con etichetta, descrizione e una parte del contesto nel grafo. Il modello potrebbe scegliere, riformulare la ricerca o chiedere altri candidati prima di scrivere SPARQL.

Renderei condizionale anche lo schema retrieval. I suggerimenti sulle proprietà dovrebbero essere richiesti solo per relazioni non risolte e classificati usando le entità collegate, non soltanto il testo della domanda.

Una valutazione più utile dovrebbe inoltre separare gli errori in categorie:

- errore nella selezione dell'entità;
- errore nella selezione della proprietà;
- struttura della query errata;
- errori di aggregazione o filtro;
- output sintatticamente non valido;
- problemi di endpoint o esecuzione.

Un singolo valore F1 è utile per confrontare i sistemi, ma nasconde quale componente richieda davvero intervento.

## La lezione più generale per i sistemi RAG

Il progetto riguarda SPARQL, ma la conclusione è più ampia.

Un LLM può ragionare soltanto sull'evidenza che riceve. Quando il retrieval restituisce l'oggetto sbagliato, più contesto e prompt più elaborati possono aumentare la sicurezza apparente senza aumentare la correttezza.

L'ordine delle priorità dovrebbe essere:

```text
grounding corretto
  -> contesto rilevante
  -> ragionamento strutturato
  -> generazione
  -> validazione
```

In questi esperimenti, il principale collo di bottiglia non era la capacità dell'LLM di scrivere una query. Era la qualità del ponte tra linguaggio naturale e Knowledge Graph.

Quel ponte era l'entity linking.