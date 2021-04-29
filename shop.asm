asm shop

// Un negozio di articoli sportivi ha inizialmente x magliette di Juve, Inter e Milan e un budget iniziale.
// Il gestore del negozio riceve i clienti che possono scegliere quale prodotto acquistare.
// Il gestore sceglie se vendere le magliette (solo se disponibili in magazzino)
// oppure se effettuare degli ordini ai fornitori per incrementare la disponibilità in magazzino (solo se il budget lo permette).
// Ad ogni vendita ai clienti o ordine ai fornitori viene calcolato il guadagno o il costo, aggiornato il budget e visualizzati il numero di prodotti venduti.

import StandardLibrary

signature:

	// Domini
	enum domain Product = {JUVE | INTER | MILAN} // Prodotti disponibili
	enum domain State = {SCELTA_PRODOTTO | SCELTA_OPZIONI | QUANTITA_ORDINE | QUANTITA_VENDITA | AGGIORNAMENTO_BUDGET}
	enum domain Option = {VENDITA | FORNITORI | ESCI} // Opzioni rese disponibili al gestore
	domain Order subsetof Integer
	
	// Valori iniziali
	static initBudget: Integer // Static, non cambia
	dynamic controlled stock: Product -> Integer // Disponibilità in magazzino per ogni prodotto
	dynamic controlled soldProducts: Product -> Integer // Numero prodotti venduti

	// Valori correnti
	dynamic controlled currentBudget: Integer
	dynamic controlled currentProduct: Product // Prodotto scelto dal cliente

	// Costi
	dynamic controlled productCost: Product -> Integer // Prezzo d'acquisto dai fornitori per ogni prodotto
	dynamic controlled totalCost: Integer
	
	// Ricavi
	dynamic controlled productPrice: Product -> Integer // Prezzo di vendita ai clienti per ogni prodotto
	dynamic controlled totalRevenue: Integer
		
	// Profitto
	dynamic controlled profit: Integer
	
	// Utils
	dynamic controlled state: State
	out message: String
	derived productToString: Product -> String

	// Monitorate
	dynamic monitored selectedProduct: Product // Prodotto selezionato dal cliente
	dynamic monitored selectedOption: Option // Opzione scelta dal gestore
	dynamic monitored insertedQuantity: Order // Quantità richiesta
	
definitions:

	// Domini
	domain Order = {10: 100} // Un ordine ai fornitori deve contenere almeno x articoli e al massimo y
	
	// Static
	function initBudget = 500
	
	function productToString($p in Product) =
	switch($p)
		case JUVE: "Juve"
		case MILAN: "Milan"
		case INTER: "Inter"
	endswitch

	// Rules
	
	// Scelta del prodotto da parte del cliente
	macro rule r_SelectProduct =
		if state = SCELTA_PRODOTTO then
			if (exist $c in Product with $c=selectedProduct) then
				par
					currentProduct := selectedProduct
					state := SCELTA_OPZIONI
					message := "Scegli operazione"
				endpar
			endif
		endif
	
	// Il gestore sceglie se vendere il prodotto o effettuare un ordine da fornitori
	// E' anche possibile tornare alla selezione del prodotto
	macro rule r_SelectOption =
		if state = SCELTA_OPZIONI then
			par
				if selectedOption = FORNITORI then
					par
						state := QUANTITA_ORDINE
						message := "Scegli quantità da rifornire"
					endpar
				endif

				if selectedOption = VENDITA then
					par
						state := QUANTITA_VENDITA
						message := "Scegli quantità da vendere"
					endpar
				endif
				
				if selectedOption = ESCI then
					par
						state := SCELTA_PRODOTTO
						message := "Scelta del prodotto"
					endpar
				endif
				
			endpar
		endif
	
	// Scelta della quantità da acquistare presso fornitori. Se il costo dell'ordine supera il budget viene richiesta una quantità minore.
	macro rule r_AmountToOrder =
		if state = QUANTITA_ORDINE then
			if (productCost(currentProduct) * insertedQuantity) <= currentBudget then
				par
					totalCost := totalCost + (productCost(currentProduct) * insertedQuantity) // Aggiungo al costo totale il costo delle unità ordinate
					stock(currentProduct) := stock(currentProduct) + insertedQuantity // Incremento disponibilità del prodotto
					state := AGGIORNAMENTO_BUDGET
					message := concat("Aggiorno bilancio dopo l'ordine di ", productToString(currentProduct))
				endpar
			else
				par
					state := QUANTITA_ORDINE
					message := "Budget attuale non sufficiente. Scegli un'altra quantità"
				endpar
			endif
		endif
	
	// Scelta della quantità da vendere al cliente. Se la quantità da vendere supera la disponibilità in magazzino viene richiesta una quantità minore.
	macro rule r_AmountToSell =
		if state = QUANTITA_VENDITA then
			if insertedQuantity <= stock(currentProduct) then
				par
					totalRevenue := totalRevenue + productPrice(currentProduct)* insertedQuantity // Aggiungo ai ricavi il prezzo di un'unità
					stock(currentProduct) := stock(currentProduct) - insertedQuantity // Decremento disponibilità del prodotto
					soldProducts(currentProduct) := soldProducts(currentProduct) + insertedQuantity // Incremento numero di prodotti venduti
					state := AGGIORNAMENTO_BUDGET
					message := concat("Aggiorno bilancio dopo vendita di ", productToString(currentProduct))
				endpar
			else
				par
					state := QUANTITA_VENDITA
					message := "Quantità richiesta non sufficiente. Scegli un'altra quantità"
				endpar		
			endif
		endif

	// Calcolo del profitto e aggiornamento del budget
	macro rule r_UpdateBudget =
		if state = AGGIORNAMENTO_BUDGET then
			seq
				profit := totalRevenue - totalCost
				currentBudget := initBudget + profit
				par
					state := SCELTA_PRODOTTO
					message := "Scelta del prodotto"
				endpar
			endseq
		endif
	
	// Ogni passo dell'ASM corrisponde ad un'interazione con il gestore
	main rule r_Main =	
		par
			r_SelectProduct[]
			r_SelectOption[]
			r_AmountToOrder[]
			r_AmountToSell[]
			r_UpdateBudget[]
    	endpar  

default init s0:

	// Valori iniziali
	function currentBudget = initBudget // Il budget corrente inzialmente è uguale a quello iniziale
	
	// Disponibilità iniziale in magazzino per ogni prodotto
	function stock($c in Product) =
		switch($c)
			case JUVE : 20
			case INTER : 20
			case MILAN : 20
		endswitch
	
	function soldProducts($p in Product) = 0 // Inizialmente non ho prodotti venduti

	// Costi
	
	// Prezzo d'acquisto presso fornitori per ogni prodotto
	function productCost($p in Product) =
		switch($p)
			case JUVE: 10
			case MILAN: 5
			case INTER: 4
		endswitch
	
	function totalCost = 0 
	
	// Ricavi
	
	// Prezzo di vendita ai clienti per ogni prodotto
	function productPrice($p in Product) =
		switch($p)
			case JUVE: 25
			case MILAN: 15
			case INTER: 10
		endswitch
	
	function totalRevenue = 0

	// Profitto
	function profit = 0

	// Utils
	
	function state = SCELTA_PRODOTTO // Lo stato iniziale è la scelta del prodotto da parte del cliente
