#Include 'Protheus.ch'

User Function prcm_lote(lauto)
	
	
	Local aSays := {}
	Local aButtons := {}
	
	
	DEFAULT lauto := .F.
	
	// Documentação
	/*
	lauto = define se a rotina será executada automaticamente via schedule ou manual (.T. ou .F. )
	
	*/
	//
	
	If !lauto
		
		AADD(aSays,"Este programa tem o objetivo de gravar os valores de preço médio de compra por lote.")
		AADD(aSays,"A partir das notas de entrada será feita a avaliação e gravação dos valores.")
		AADD(aSays,"Podendo ser utilizada de maneira automática ou manual.")
		AADD(aSays,"Conforme processo definido pela Sulmedic.")
		
		AADD(aButtons, { 1,.T.,{ || Processa({|lEnd| Atuprcm(),FechaBatch()},"Gravação Preço Médio por Lote","Reprocessamento em execução...",.F.)} } )
		AADD(aButtons, { 2,.T.,{|| FechaBatch() }} )
		
		FormBatch("Gravação Preço Médio por Lote",aSays,aButtons,,220,560)
		
	Else
		
		procAtuprcm_arq(lauto)
		
	Endif
	
Return()

Static Function Atuprcm(lauto)
	Local nPreco
	Local cLote
	Local cProduto
	Local cData
	Local SldIni
	Local PrecoM 
	Local cQuery
	Local UltNota
	Local nUltVal := 0
	Local nQtdFech := 0
	Local lPassei := .F.
	Local aUltPrc := {}
	Local cFrom := ""
	Local cCC := ""
	Local cTo := ""
	Local cSubject := ""
	Local cAttach := ""
	Local cMsg := ""
	Local y
	
	
	dbSelectArea("SB8")
	SB8->(dbSetOrder(3))
	
	If !lauto
	ProcRegua(RecCount())
	Endif
	
	While !SB8->(Eof())
		
		nUltVal := 0
		nQtdFech := 0
		
		SldIni	:= getNextAlias()
		PrecoM  := getNextAlias()
		UltNota := getNextAlias()
		
		BeginSql alias SldIni
			%noParser%
			SELECT TOP (1) BJ_DATA, BJ_COD, SUM(BJ_QINI) AS BJ_QINI
			FROM %table:SBJ% SBJ
			WHERE SBJ.%notDel%
			AND BJ_COD =  %exp:SB8->B8_PRODUTO% AND BJ_LOTECTL = %exp:SB8->B8_LOTECTL%
			GROUP BY BJ_DATA, BJ_COD
			ORDER BY BJ_DATA DESC, BJ_COD
		EndSql
		
		If !(SldIni)->(Eof())
			(SldIni)->(dbGoTop())	
			
			lPassei := .T.
			cData := (SldIni)->BJ_DATA
			
			cQuery := "SELECT SUM(D1_TOTAL-D1_VALDESC) AS VALOR, SUM(D1_QUANT) AS QUANT  FROM "
   			cQuery += "  SD1010 WHERE D1_COD = '"+SB8->B8_PRODUTO+"' AND D1_TIPO = 'N' "
   			cQuery += " AND SD1010.D_E_L_E_T_ = ''  AND D1_LOTECTL = '"+SB8->B8_LOTECTL+"' "
   			cQuery += " AND D1_DTDIGIT > '"+cData+"' "
   		
   			cQuery := ChangeQuery(cQuery)
   			dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),PrecoM)
   			TcSetField( PrecoM, "VALOR", "N", 16, 4 )
			TcSetField( PrecoM, "QUANT", "N", 14, 3 )

			
			BeginSql alias UltNota
				%noParser%
				SELECT TOP (1) D1_VUNIT, D1_COD, D1_DTDIGIT
				FROM %table:SD1% SD1
				WHERE SD1.%notDel%
				AND D1_DTDIGIT <= %exp:cData%
				AND D1_TIPO = 'N'
				AND D1_COD =  %exp:SB8->B8_PRODUTO% AND D1_LOTECTL = %exp:SB8->B8_LOTECTL%
				ORDER BY D1_DTDIGIT DESC, D1_DOC DESC
			EndSql
			
			If !(UltNota)->(Eof())
				(UltNota)->(dbGoTop())
			
				nUltVal := (UltNota)->D1_VUNIT
				nQtdFech := (SldIni)->BJ_QINI 
			
			Endif
			/*
			If Alltrim(SB8->B8_PRODUTO) == 'M0480'
				MsgStop("DATA: "+CDATA)
				MsgStop("Qini:"+Transform((SldIni)->BJ_QINI ,"@E 999,999.99"))
				MsgStop("vunit:"+Transform((UltNota)->D1_VUNIT ,"@E 999,999.99"))
				MsgStop("Valor PreçoM1:"+Transform((PrecoM)->VALOR,"@E 999,999.99"))
			Endif
			*/
			(UltNota)->(dbclosearea())
			
		Else
			
			
			lPassei := .T.
		   	cQuery := "SELECT SUM(D1_TOTAL-D1_VALDESC) AS VALOR, SUM(D1_QUANT) AS QUANT  FROM "
   			cQuery += "  SD1010 WHERE D1_COD = '"+SB8->B8_PRODUTO+"' AND D1_TIPO = 'N' "
   			cQuery += " AND SD1010.D_E_L_E_T_ = ''  AND D1_LOTECTL = '"+SB8->B8_LOTECTL+"' "
   		
   			cQuery := ChangeQuery(cQuery)
   			dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),PrecoM)
   			TcSetField( PrecoM, "VALOR", "N", 16, 4 )
			TcSetField( PrecoM, "QUANT", "N", 14, 3 )
		
			/*
			BeginSql alias PrecoM
				%noParser%
				SELECT(ISNULL((SELECT SUM(D1_TOTAL-D1_VALDESC) FROM %table:SD1% WHERE D1_COD = %exp:SB8->B8_PRODUTO% AND D1_TIPO = 'N' AND %notDel%  AND D1_LOTECTL = %exp:SB8->B8_LOTECTL% ),(SELECT TOP (1) B1_UPRC FROM %table:SB1% WHERE B1_COD = %exp:SB8->B8_PRODUTO% AND %table:SB1%.%notDel% )) / ISNULL((SELECT SUM(D1_QUANT) FROM %table:SD1% WHERE D1_COD = %exp:SB8->B8_PRODUTO% AND D1_TIPO = 'N' AND %notDel% AND D1_LOTECTL = %exp:SB8->B8_LOTECTL%),1)) AS PRECOM
			EndSql
		
			If Alltrim(SB8->B8_PRODUTO) == 'M0480'
			
				MsgStop("Valor PreçoM2:"+Transform((PrecoM)->VALOR,"@E 999,999.99"))
			Endif
			*/
			
		Endif
		
		If !(PrecoM)->(Eof()) .and. lPassei .and. ((nQtdFech > 0 .and. nUltVal > 0) .or. ((PrecoM)->VALOR > 0 .and. (PrecoM)->QUANT > 0))
			(PrecoM)->(dbGoTop())

			//If Alltrim(SB8->B8_PRODUTO) == 'M0480'
			//
			//	MsgStop("Gravação:"+Transform(((PrecoM)->VALOR+(nUltVal*nQtdFech))/((PrecoM)->QUANT+nQtdFech),"@E 999,999.99"))
			//Endif
		
			
			RecLock("SB8",.F.)
				SB8->B8_PRCM := ((PrecoM)->VALOR+(nUltVal*nQtdFech))/((PrecoM)->QUANT+nQtdFech)
			SB8->(MsUnLock())
		
		Else
		
			dbSelectArea("SB1")
			SB1->(dbSetOrder(1))
			SB1->(dbSeek(xFilial("SB1")+SB8->B8_PRODUTO))
			RecLock("SB8",.F.)
				SB8->B8_PRCM := SB1->B1_UPRC
				//aadd(aUltPrc,{SB8->B8_PRODUTO,SB1->B1_DESC})
			SB8->(MsUnLock())
			
		
		Endif
		
		If !lauto
			Incproc("Processando produto: "+Alltrim(SB8->B8_PRODUTO)+" e lote: "+Alltrim(SB8->B8_LOTECTL))
		Endif
	
		(PrecoM)->(dbCloseArea())
		
		(SldIni)->(dbclosearea())
		
		
		SB8->(dbSkip())
	EndDo
	/*
	If Len(aUltPrc) > 0
	
		cFrom := GETMV("MV_RELFROM")
		cTo := GETMV("SUL_UPRC")
		cSubject := "Produtos com preço de compra zerado"
		cCC := ""
		cAttach := ""
		
		cMsg := "Abaixo os Itens que tiveram o preço de compra zerado e utilizaram o último preço do cadastro" + CHR(13)+ CHR(10)
		cMsg += CHR(13)+ CHR(10)
		cMsg += CHR(13)+ CHR(10)
		cMsg += "Produto       "+CHR(13)+ CHR(10)
		cMsg += "**************************************************************************"+CHR(13)+ CHR(10)
		For y := 0 to len(aUltPrc)
		
			cMsg += Alltrim(aUltPrc[y,1])+" - "+Alltrim(aUltPrc[y,2])+CHR(13)+CHR(10)
				
		Next y
			 
		U_OpenSendMail(cFrom, cTo, cCC, cSubject, cMsg, cAttach)
		
	Endif
	*/
Return()
