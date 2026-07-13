---
title: "Il collo di bottiglia non era l'LLM: cosa ha migliorato davvero il Text-to-SPARQL"
type: article
layout: article
lang: it
slug: text-to-sparql-bottleneck
permalink: /it/entries/text-to-sparql-bottleneck/
date: 2026-06-22
category: "Knowledge Graph"
read_time: 11
image: "/images/articles/text-to-sparql-bottleneck/wikidata-problem.png"
thumbnail: "/images/articles/text-to-sparql-bottleneck/wikidata-problem.png"
cover: "/images/articles/text-to-sparql-bottleneck/wikidata-problem.png"
cover_alt: "Rappresentazione di un Knowledge Graph usata nel progetto Text-to-SPARQL"
thumbnail_alt: "Anteprima del Knowledge Graph Text-to-SPARQL"
excerpt: "Un ablation study sulla generazione Text-to-SPARQL ha mostrato che un entity linking affidabile conta molto più di esempi aggiuntivi, schema hints o prompt sempre più complessi."
---

I Large Language Model riescono a generare SPARQL dall'aspetto convincente molto prima di riuscire a generare SPARQL realmente corretto.

Questa differenza è diventata il problema centrale dei miei esperimenti sulla traduzione di domande in linguaggio naturale in query eseguibili su Wikidata. La sintassi era spesso valida: prefissi, variabili, triple pattern e filtri comparivano nei punti giusti. Nonostante questo, la query poteva restituire una risposta errata o nessun risultato, perché bastava un solo identificatore di entità o proprietà sbagliato.

Il modello non falliva soprattutto nello scrivere SPARQL. Falliva nel collegare il linguaggio umano agli identificatori usati dal grafo.

## Il task

Il progetto usa domande del benchmark QALD-10 e chiede a un modello di generare SPARQL per Wikidata. Una domanda può citare una persona, un luogo, un'opera o un evento con parole normali, mentre la query finale deve usare identificatori come `Q42`, `P19` o `P1346`.

![La domanda deve essere collegata agli identificatori opachi di Wikidata prima della generazione SPARQL](/images/articles/text-to-sparql-bottleneck/wikidata-problem.png)

La pipeline è composta da stadi configurabili in modo indipendente.

Ho confrontato GPT-4o, GPT-4o-mini e Llama 3.3 70B, variando il linker, gli esempi few-shot recuperati con FAISS, i suggerimenti sulle proprietà Wikidata e strategie di prompting come decomposition e self-consistency.

Il valore di questa impostazione non era ottenere soltanto un punteggio finale. Ogni componente poteva essere attivato o rimosso, rendendo possibile misurare il suo contributo reale.

## Perché Wikidata è più difficile della normale code generation

La generazione SPARQL viene spesso trattata come un altro problema di generazione strutturata, simile al Text-to-SQL. Il confronto è valido solo in parte.

Un database relazionale espone di solito uno schema limitato e leggibile. Wikidata contiene invece oltre cento milioni di entità e migliaia di proprietà identificate da QID e PID opachi. La domanda non rivela quegli identificatori.

L'ambiguità peggiora ulteriormente il problema. Una stessa espressione può indicare nodi diversi e le API di ricerca tendono a favorire il candidato più popolare, non necessariamente quello corretto nel contesto.

![Ambiguità nella risoluzione dell'entità illustrata con i diversi significati di The Matrix](/images/articles/text-to-sparql-bottleneck/entity-ambiguity.png)

Anche quando l'entità è corretta, la struttura del grafo può richiedere navigazione complessa. Date, ruoli e qualificatori usano statement reificati con prefissi come `p:`, `ps:` e `pq:`, non soltanto relazioni dirette `wdt:`.

Il problema contiene quindi due task distinti:

1. capire il significato della menzione;
2. collegarlo all'identificatore e al percorso corretto nel Knowledge Graph.

Il prompting può aiutare con il primo punto. Non può risolvere in modo affidabile il secondo senza accesso al grafo o a un componente esterno di retrieval.

## Recuperare proprietà ed esempi

Lo schema retrieval costruisce un indice FAISS su descrizioni arricchite delle proprietà, combinando etichette, alias e spiegazioni brevi. Durante l'esecuzione, la domanda e il contesto delle entità collegate vengono usati per recuperare PID candidati.

L'obiettivo era evitare che il modello dovesse indovinare le relazioni dalla memoria. Un'espressione come “member of Congress” dovrebbe recuperare `P39`, anche se l'etichetta ufficiale è “position held”.

Un secondo retriever seleziona esempi semanticamente simili da QALD-9+ e inserisce nel prompt le rispettive domande e query SPARQL gold.

![Il few-shot retrieval fornisce domande simili e strutture SPARQL gold](/images/articles/text-to-sparql-bottleneck/few-shot.png)

Entrambe le idee sembrano utili. Gli ablation study hanno mostrato che il loro effetto dipendeva fortemente dalla correttezza dell'entity linking.

## Il miglioramento principale arrivava dall'entity linking

Sul test set completo di 394 domande, le configurazioni senza entity linking ottenevano un macro F1 di circa 5–8%. Aggiungendo REBEL, il risultato saliva approssimativamente al 17–20%, a seconda del modello e del prompt.

Le configurazioni migliori raggiungevano circa il 24–25% di macro F1. GPT-4o beneficiava maggiormente della decomposition, mentre Llama 3.3 70B risultava più forte con self-consistency. Queste strategie contavano, ma soprattutto dopo aver fornito alla pipeline entità plausibili.

Un solo componente produceva un miglioramento di due o tre volte. Tutto il resto insieme aggiungeva soltanto pochi punti.

Questo ha cambiato il modo in cui interpretavo gli errori. Un punteggio basso non significava necessariamente che il modello non sapesse ragionare sulla domanda. In molti casi ragionava sul nodo sbagliato.

## Il retrieval può peggiorare il prompt

Il few-shot retrieval senza linking affidabile spesso funzionava peggio della generazione senza contesto.

Gli esempi non erano sempre irrilevanti. Erano spesso simili dal punto di vista linguistico, ma richiedevano relazioni differenti. Una domanda sul coniuge può somigliare a una su un collaboratore, un creatore o un membro del cast. Il modello può copiare una struttura plausibile ma sbagliata per il percorso target.

Anche gli schema hints mostravano lo stesso problema. Quando l'entity linking era già attivo, aggiungere proprietà candidate riduceva talvolta il macro F1. Una lista di relazioni plausibili amplia lo spazio di scelta e spinge il modello a fidarsi di suggerimenti che suonano corretti ma non corrispondono al grafo.

![Gli ablation study mostrano che esempi e schema hints possono ridurre le prestazioni](/images/articles/text-to-sparql-bottleneck/ablation.png)

La conclusione non è che il retrieval sia inutile. È che deve essere valutato componente per componente. Più contesto aiuta solo quando riduce l'incertezza invece di aggiungerne altra.

## Una query valida può essere comunque sbagliata

Una query generata può fallire a livelli differenti:

- sintassi SPARQL non valida;
- query valida ma non eseguibile;
- query valida che non restituisce binding;
- query eseguibile che restituisce l'entità sbagliata;
- entità corretta ma proprietà errata;
- struttura diversa dalla gold query ma risposta comunque corretta.

La validazione sintattica rileva soltanto il primo caso. La validazione tramite esecuzione ne intercetta alcuni altri. Nessuna delle due dimostra che gli identificatori selezionati corrispondano davvero all'intento dell'utente.

Per questo anche la correzione automatica ha limiti precisi. Un errore di esecuzione può aiutare a correggere un filtro malformato o una parentesi mancante. Non sempre permette di capire che una menzione è stata collegata al nodo sbagliato quando entrambe le query vengono eseguite correttamente.

## La correzione iterativa aiutava alcuni modelli e ne peggiorava un altro

Su un esperimento più piccolo da 100 domande, la correzione iterativa produceva guadagni importanti per GPT-4o e Llama 3.3, mentre GPT-4o-mini peggiorava. Il modello più debole tendeva a semplificare la query dopo il feedback, perdendo una parte del significato originale.

![La correzione iterativa migliora GPT-4o e Llama ma riduce le prestazioni di GPT-4o-mini](/images/articles/text-to-sparql-bottleneck/iterative-correction.jpg)

Questo risultato è interessante proprio perché non è universalmente positivo. Un correction loop non migliora automaticamente un sistema. Il suo valore dipende dalla capacità del modello di interpretare il feedback senza distruggere la struttura della query.

## Il graph traversal agentico cambia il problema

La versione agentica non dipende soltanto dagli identificatori forniti all'inizio. Può ispezionare risultati del grafo, provare un percorso, recuperare da una risposta vuota e cambiare relazione.

L'esempio della Emu War mostra la differenza. La query single-shot sceglieva la proprietà sbagliata e non trovava risultati. L'agente esplorava un percorso indiretto, identificava l'evento, ne esaminava i partecipanti e filtrava il risultato fino agli animali.

Questo approccio è più vicino alla ricerca che alla semplice generazione. Il modello non deve ricordare perfettamente il grafo: può verificare le proprie ipotesi sui dati.

## Il prompt engineering aiutava, ma non eliminava il collo di bottiglia

Decomposition e self-consistency miglioravano alcune configurazioni. I guadagni rimanevano però molto più piccoli rispetto a quelli prodotti dall'entity linking.

Più ragionamento non compensa un grounding errato. Può invece generare una spiegazione più lunga e coerente costruita sull'interpretazione sbagliata.

I prompt migliori funzionavano perché operavano su input migliori. Una volta disponibili i QID rilevanti, la decomposition poteva concentrarsi su join, filtri, ordinamento e aggregazioni invece di indovinare i nodi del grafo.

## Confronto con altri sistemi

Il confronto con lavori precedenti deve essere letto con attenzione perché i sistemi usano assunzioni, modelli e metriche diverse. Alcuni sono fine-tuned, altri usano graph search, altri ancora ricevono entità gold.

Il confronto più interessante non è la posizione assoluta in classifica. È ciò che accade quando si rimuovono le entità gold. Sistemi apparentemente molto più forti perdono gran parte del vantaggio quando devono risolvere autonomamente le menzioni.

Questo sostiene il risultato principale: una parte importante dell'intelligenza apparente del generatore finale dipende dalla qualità degli identificatori forniti prima della generazione.

## Cosa cambierei nella prossima versione

La pipeline attuale tratta l'entity linking come preprocessing. Gli esperimenti suggeriscono che dovrebbe diventare uno strumento richiamabile durante la generazione.

Invece di ricevere una lista fissa di entità, il modello potrebbe avviare una ricerca quando incontra una menzione ambigua. Lo strumento restituirebbe candidati con etichette, descrizioni e contesto selezionato dal grafo. Il modello potrebbe scegliere, affinare la ricerca o richiedere altri candidati prima di scrivere SPARQL.

Renderei condizionale anche lo schema retrieval. I suggerimenti sulle proprietà dovrebbero essere richiesti soltanto per relazioni non risolte e classificati usando le entità già collegate.

Una valutazione più utile dovrebbe separare gli errori in categorie:

- selezione dell'entità;
- selezione della proprietà;
- struttura della query;
- aggregazioni e filtri;
- output sintatticamente non valido;
- problemi di endpoint o esecuzione.

Un singolo valore F1 è utile per confrontare i sistemi, ma nasconde quale componente richieda davvero intervento.

## La lezione più generale

![Principali lezioni emerse dagli esperimenti Text-to-SPARQL](/images/articles/text-to-sparql-bottleneck/lessons.png)

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