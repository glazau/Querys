create or replace PROCEDURE "AD_VARIACAO_CAMBIAL_CONTAB" (
           P_CODUSU NUMBER,       
           P_IDSESSAO VARCHAR2,    
           P_QTDLINHAS NUMBER,     
           P_MENSAGEM OUT VARCHAR2 
    ) AS
    
    FIELD_NUFIN 				NUMBER; 
    FIELD_SEQUENCIA				NUMBER;  
    P_TEM_REG_NAC               INT; 
    P_TEM_REG_NAC_POSTERIOR     INT; 
    V_NUNOTA                    INT;
    V_CODCENCUS                 INT;
    V_MAX_NUMLANC_D             INT;
    V_MAX_NUMLANC_C             INT;
    V_MAX_SEQUENCIA_D           INT;
    V_MAX_SEQUENCIA_C           INT;
    P_COUNT_LOTE                INT; 
    V_COUNT_TCBPLA              INT;
    CODCENCUSCTACTB2            INT;
    PARAM_DATACONT 			    DATE;  
    PARAM_DATAMOV 			    DATE;  

    BEGIN
     FOR I IN  1..P_QTDLINHAS 
     LOOP 
        FIELD_NUFIN := ACT_INT_FIELD(P_IDSESSAO, I,'NUFIN'); 
        FIELD_SEQUENCIA := ACT_INT_FIELD(P_IDSESSAO, I,'SEQUENCIA');  
        PARAM_DATACONT := ACT_DTA_PARAM(P_IDSESSAO,'PARAM_DATACONT'); 
        PARAM_DATAMOV := ACT_DTA_PARAM(P_IDSESSAO,'PARAM_DATAMOV'); 

        /*Necessário preencher o parametro com as datas.*/
        IF (PARAM_DATACONT IS NULL OR PARAM_DATAMOV IS NULL) THEN 
    	RAISE_APPLICATION_ERROR(-20101, 'Necessário preencher as datas solicitadas');
    	END IF;

        /*A Data de contabilização/referencia só pode ser no primeiro dia de cada vez, para efetuar a contabilização*/

        IF PARAM_DATACONT <> TRUNC(PARAM_DATACONT,'MONTH') THEN 
    	RAISE_APPLICATION_ERROR(-20101, 'A contabilização só pode ser efetuada no primeiro dia de cada mês.');
    	END IF; 
        
        /*
        LISTANDO OS DADOS DA VARIAÇÃO CAMBIAL
        */
     FOR CUR IN (
        SELECT 
        V.SEQUENCIA,V.NUFIN,V.DTVAR,V.VLRMOEDA,V.VLRMOEDAVAR,V.VLRMODFUN,V.VLRMODFUNATUAL,V.VLRMODUS,V.VLRVARCAMBLANC,
        CASE WHEN  V.VLRVARCAMBLANC < 0 THEN V.VLRVARCAMBLANC * -1 ELSE V.VLRVARCAMBLANC END AS "VLRVARCAMBLANC_TRATADO",
        V.VLRVARCAMB,V.TIPO,V.DTINC,FIN.CODEMP,EMP.AD_VARLOTE,FIN.CODPARC,

        EMP.AD_CODCTACTBCVPPB,EMP.AD_CODCTACTBCVAPB,EMP.AD_CODCTACTBDVAPB,EMP.AD_CODCTACTBDVPPB,

    	EMP.AD_VARCODCENCUS,EMP.AD_VARCODPROJ,HIS.HISTORICO,HIS.CODHISTCTB,FIN.NUMNOTA,EMP.AD_CODCTACTBDAN,EMP.AD_CODCTACTBDPPN,EMP.AD_CODCTACTBCPNA,EMP.AD_CODCTACTBCANA,
    	--CENTROS DE RESULTADOS TRATADOS PARA ATENDER A REGRA DE NEGOCIO DA INNEO 
    	CASE WHEN SUBSTR(REPLACE(EMP.AD_CODCTACTBDAN, '.', ''),1,1) IN (1,2)  THEN 0 ELSE EMP.AD_VARCODCENCUS END AS "CODCENCUSDAN",
    	CASE WHEN SUBSTR(REPLACE(EMP.AD_CODCTACTBDPPN, '.', ''),1,1) IN (1,2) THEN 0 ELSE EMP.AD_VARCODCENCUS END AS "CODCENCUSDPPN",  
    	CASE WHEN SUBSTR(REPLACE(EMP.AD_CODCTACTBCPNA, '.', ''),1,1) IN (1,2) THEN 0 ELSE EMP.AD_VARCODCENCUS END AS "CODCENCUSCPNA",
    	CASE WHEN SUBSTR(REPLACE(EMP.AD_CODCTACTBCANA, '.', ''),1,1) IN (1,2) THEN 0 ELSE EMP.AD_VARCODCENCUS END AS "CODCENCUSCANA",
    	CASE WHEN SUBSTR(REPLACE(EMP.AD_CODCTACTBCANA, '.', ''),1,1) IN (1,2) THEN 0 ELSE EMP.AD_VARCODCENCUS END AS "CODCENCUSCVPPB",
    	CASE WHEN SUBSTR(REPLACE(EMP.AD_CODCTACTBCANA, '.', ''),1,1) IN (1,2) THEN 0 ELSE EMP.AD_VARCODCENCUS END AS "CODCENCUSCVAPB",
    	CASE WHEN SUBSTR(REPLACE(EMP.AD_CODCTACTBCANA, '.', ''),1,1) IN (1,2) THEN 0 ELSE EMP.AD_VARCODCENCUS END AS "CODCENCUSDVAPB",
    	CASE WHEN SUBSTR(REPLACE(EMP.AD_CODCTACTBCANA, '.', ''),1,1) IN (1,2) THEN 0 ELSE EMP.AD_VARCODCENCUS END AS "CODCENCUSDVPPB",
    	PAR.CODCTACTB2,
        FIN.CODTIPOPER
        FROM AD_VARCAMB V
        INNER JOIN TGFFIN FIN ON FIN.NUFIN = V.NUFIN
        INNER JOIN TGFEMP EMP ON EMP.CODEMP = FIN.CODEMP
    	INNER JOIN TCBHIS HIS ON HIS.CODHISTCTB = EMP.AD_VARCODHISTCTB
    	INNER JOIN TGFPAR PAR ON PAR.CODPARC = FIN.CODPARC
        WHERE V.NUFIN = FIELD_NUFIN
        AND V.SEQUENCIA = FIELD_SEQUENCIA
        ) 
        LOOP

        IF CUR.VLRVARCAMBLANC_TRATADO = 0 THEN 
    	RAISE_APPLICATION_ERROR(-20101, 'A contabilização só pode ser efetuada com o valor da variação cambial evento diferente de zero.');
    	END IF;  

        /* 
        TRATANDO CONTA 2 DO PARCEIRO PARA ATENDER A REGRA PERSONALIZADA
        INICIO
        */ 
        SELECT COUNT(*)
        INTO V_COUNT_TCBPLA
        FROM TCBPLA PLA
        WHERE PLA.CODCTACTB = CUR.CODCTACTB2
        AND SUBSTR(REPLACE(PLA.CTACTB, '.', ''),1,1) IN ('1', '2');

        IF V_COUNT_TCBPLA > 0 THEN
        CODCENCUSCTACTB2 := 0;
        END IF;

		IF V_COUNT_TCBPLA = 0 THEN
        CODCENCUSCTACTB2 := CUR.CODCTACTB2;
        END IF;
        /* 
        TRATANDO CONTA 2 DO PARCEIRO PARA ATENDER A REGRA PERSONALIZADA
        FINAL
        */ 

        /*
        VERIFICANDO SE EXISTE LOTE CONTABILIZADO
        */
        SELECT COUNT(*)
    	INTO P_COUNT_LOTE
    	FROM TGFEMP EMP
    	WHERE EMP.CODEMP = CUR.CODEMP
    	AND NOT EXISTS(SELECT 1
    				   FROM TCBLOT
    				   WHERE CODEMP = CUR.CODEMP
                       AND NUMLOTE = CUR.AD_VARLOTE
                       AND REFERENCIA = TRUNC(PARAM_DATACONT, 'MONTH'));

        -- FAZ INSET NA TCBLOT DO LOTE
        IF P_COUNT_LOTE > 0 THEN
          INSERT INTO TCBLOT
            (CODEMP,
             REFERENCIA,
             NUMLOTE,
             DTMOV,
             TOTLOTE,
             COMENTARIOS,
             SITUACAO,
             ULTLANC, 
    		 CODUSU,
             CODEMPCONSOLID)
          VALUES
            (CUR.CODEMP,
             TRUNC(PARAM_DATACONT, 'MONTH'),
             CUR.AD_VARLOTE,
             SYSDATE,
             0,
             'Lote Variação Cambial',
             'A',
             '0', 
    		 STP_GET_CODUSULOGADO(),
             '');
        END IF;

        /* 
        VERIFICANDO SE EXISTE REGISTRO ANTERIOR DE NOTA DE NACIONALIZAÇÃO 
        */
        SELECT COUNT(*)
        INTO P_TEM_REG_NAC
        FROM AD_VARCAMB
    	WHERE DTVAR < CUR.DTVAR
        AND NUFIN = FIELD_NUFIN
        AND TIPO = '2';

          /* 
        VERIFICANDO SE EXISTE REGISTRO DE NACIONALIZAÇÃO APÓS BAIXA
        */
        SELECT COUNT(*)
        INTO P_TEM_REG_NAC_POSTERIOR
        FROM AD_VARCAMB
    	WHERE DTVAR < CUR.DTVAR
        AND NUFIN = FIELD_NUFIN 
        AND TIPO = '3';

    	/*
    	SALVANDO O MAIOR REGISTRO DE NUMERO DE LANÇAMENTO E A MAIOR SEQUENCIA ANTES DA INSERÇÃO DEBITO
    	*/
    	SELECT MAX(NVL(NUMLANC,0))+1 , MAX(NVL(SEQUENCIA,0))+1
    	INTO V_MAX_NUMLANC_D, V_MAX_SEQUENCIA_D
    	FROM TCBLAN 
    	WHERE 1=1 
    	AND NUMLOTE = CUR.AD_VARLOTE 
    	AND REFERENCIA = PARAM_DATACONT 
    	AND CODEMP = CUR.CODEMP
    	AND TIPLANC = 'D';

    	/*
    	SALVANDO O MAIOR REGISTRO DE NUMERO DE LANÇAMENTO E A MAIOR SEQUENCIA ANTES DA INSERÇÃO RECEITA
    	*/
    	SELECT MAX(NVL(NUMLANC,0))+1 , MAX(NVL(SEQUENCIA,0))+1
    	INTO V_MAX_NUMLANC_C,V_MAX_SEQUENCIA_C
    	FROM TCBLAN 
    	WHERE 1=1 
    	AND NUMLOTE = CUR.AD_VARLOTE 
    	AND REFERENCIA = PARAM_DATACONT 
    	AND CODEMP = CUR.CODEMP
    	AND TIPLANC = 'R';
    	/*
    	VERIFICANDO SE O REGISTO É ANTERIOR A NACIONALIZAÇÃO E SE É ATIVO
    	*/
    	IF P_TEM_REG_NAC = 0 AND CUR.VLRVARCAMBLANC < 0 AND P_TEM_REG_NAC_POSTERIOR = 0 AND CUR.CODTIPOPER = 81 THEN
    	/*
        ANTES DA NACIONALIZAÇÃO RECEITA - ATIVO
        */ 
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,
        CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_C,1),'R',CUR.AD_CODCTACTBCANA,null,
        NVL(CUR.CODCENCUSCANA,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_C,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        /*
        ANTES DA NACIONALIZAÇÃO DEBITO - ATIVO
        */ 
        INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_D,1),'D',CUR.CODCTACTB2,null,
        NVL(CODCENCUSCTACTB2,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_D,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

    	END IF; 

    	/*
    	VERIFICANDO SE O REGISTO É ANTERIOR A NACIONALIZAÇÃO E SE É PASSIVO
    	*/
        IF P_TEM_REG_NAC = 0 AND CUR.VLRVARCAMBLANC > 0  AND P_TEM_REG_NAC_POSTERIOR = 0 AND CUR.CODTIPOPER = 81 THEN

    	/*
        ANTES DA NACIONALIZAÇÃO RECEITA - PASSIVA
        */ 
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,
        CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_C,1),'R',CUR.AD_CODCTACTBDAN,null,
        NVL(CUR.CODCENCUSDAN,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_C,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        /*
        ANTES DA NACIONALIZAÇÃO DEBITO - PASSIVA
        */ 
        INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_D,1),'D',CUR.CODCTACTB2,null,
        NVL(CODCENCUSCTACTB2,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_D,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        END IF;

        /* 
        VERIFICANDO SE EXISTE REGISTRO NACIONALIZADO
        VERIFICANDO SE EXISTE REGISTRO PÓS BAIXA
        VERIFICANDO SE A VARIAÇÃO DO DOLAR FICOU MENOR
        */
        IF P_TEM_REG_NAC > 0 AND CUR.VLRVARCAMBLANC < 0  AND P_TEM_REG_NAC_POSTERIOR = 0  AND CUR.CODTIPOPER = 81 THEN
        /*
        VARIAÇÃO ATIVA RECEITA 
        */
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,
    	CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_C,1),'R',CUR.AD_CODCTACTBCPNA,null,
        NVL(CUR.CODCENCUSCPNA,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_C,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

    	/*
        VARIAÇÃO ATIVA DÉBITO 
        */  
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,
    	CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_D,1),'D',CUR.CODCTACTB2,null,
        NVL(CODCENCUSCTACTB2,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_D,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        END IF;

        /*
        VERIFICANDO SE EXISTE REGISTRO NACIONALIZADO
        VERIFICANDO SE EXISTE REGISTRO PÓS BAIXA
        VERIFICANDO SE A VARIAÇÃO DO DOLAR FICOU MAIOR 
        */ 
        IF P_TEM_REG_NAC > 0 AND CUR.VLRVARCAMBLANC > 0  AND P_TEM_REG_NAC_POSTERIOR = 0  AND CUR.CODTIPOPER = 81 THEN
        /*
        VARIAÇÃO PASSIVA RECEITA 
        */
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_C,1),'R',CUR.CODCTACTB2,null,
        NVL(CODCENCUSCTACTB2,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_C,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        /*
        VARIAÇÃO PASSIVA DÉBITO 
        */  
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_D,1),'D',CUR.AD_CODCTACTBDPPN,null,
        NVL(CUR.CODCENCUSDPPN,0) ,
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_D,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        END IF;  

        /*
        VERIFICANDO SE EXISTE REGISTRO PÓS BAIXA NACIONALIZADO
        VERIFICANDO SE A VARIAÇÃO DO DOLAR FICOU MENOR
        */
        
        IF P_TEM_REG_NAC_POSTERIOR > 0 AND CUR.VLRVARCAMBLANC < 0 AND CUR.TIPO = '2' AND CUR.CODTIPOPER = 81 THEN
        /*
        VARIAÇÃO ATIVA RECEITA PÓS BAIXA
        */
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,
    	CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_C,1),'R',CUR.AD_CODCTACTBCVAPB,null,
        NVL(CUR.CODCENCUSCVAPB,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_C,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

    	/*
        VARIAÇÃO ATIVA DÉBITO PÓS BAIXA
        */  
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,
    	CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_D,1),'D',CUR.AD_CODCTACTBDVAPB,null,
        NVL(CUR.CODCENCUSDVAPB,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_D,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        END IF;

        /*
        VERIFICANDO SE EXISTE REGISTRO POSTERIOR A BAIXA NACIONALIZADO
        VERIFICANDO SE A VARIAÇÃO DO DOLAR FICOU MAIOR 
        */ 

        IF P_TEM_REG_NAC_POSTERIOR > 0 AND CUR.VLRVARCAMBLANC > 0 AND CUR.TIPO = '2' AND CUR.CODTIPOPER = 81 THEN
        /*
        VARIAÇÃO PASSIVA RECEITA PÓS BAIXA
        */
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_C,1),'R',CUR.AD_CODCTACTBCVPPB,null,
        NVL(CUR.CODCENCUSCVPPB,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_C,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        /*
        VARIAÇÃO PASSIVA DÉBITO PÓS BAIXA
        */  
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_D,1),'D',CUR.AD_CODCTACTBDVPPB,null,
        NVL(CUR.CODCENCUSDVPPB,0) ,
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_D,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        END IF;   

        /*
        TRATANDO CONTABILIZAÇÃO DAS TOPS DIFERENTE DA TOP 81, LANÇAMENTOS DA TOP DIFERENTE DA 81
        JA ENTRA NAS CONTAS DE VARIAÇÃO, IGNORANDO A REGRA DE INSERT ANTERIOR A NACIONALIZAÇÃO.
        */

        /* 
        VERIFICANDO SE EXISTE REGISTRO NACIONALIZADO
        VERIFICANDO SE EXISTE REGISTRO PÓS BAIXA
        VERIFICANDO SE A VARIAÇÃO DO DOLAR FICOU MENOR
        */
        IF CUR.VLRVARCAMBLANC < 0   AND CUR.CODTIPOPER <> 81 THEN
        /*
        VARIAÇÃO ATIVA RECEITA 
        */
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,
    	CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_C,1),'R',CUR.AD_CODCTACTBCPNA,null,
        NVL(CUR.CODCENCUSCPNA,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_C,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

    	/*
        VARIAÇÃO ATIVA DÉBITO 
        */  
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,
    	CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_D,1),'D',CUR.CODCTACTB2,null,
        NVL(CODCENCUSCTACTB2,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_D,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        END IF;

        /*
        VERIFICANDO SE EXISTE REGISTRO NACIONALIZADO
        VERIFICANDO SE EXISTE REGISTRO PÓS BAIXA
        VERIFICANDO SE A VARIAÇÃO DO DOLAR FICOU MAIOR 
        */ 
        IF CUR.VLRVARCAMBLANC > 0 AND CUR.CODTIPOPER <> 81 THEN
        /*
        VARIAÇÃO PASSIVA RECEITA 
        */
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_C,1),'R',CUR.CODCTACTB2,null,
        NVL(CODCENCUSCTACTB2,0),
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_C,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        /*
        VARIAÇÃO PASSIVA DÉBITO 
        */  
    	INSERT INTO TCBLAN (CODEMP,REFERENCIA,NUMLOTE,NUMLANC,TIPLANC,CODCTACTB,CODCONPAR,CODCENCUS,
        DTMOV,VLRLANC,CODHISTCTB,COMPLHIST,NUMDOC,VENCIMENTO,LIBERADO,CODUSU,
        CODPROJ,PARTLALUR_A,SEQUENCIA,EXTEMPORANEO,DTEXTEMPORANEO,CODEMPORIG,AD_DTALTER,AD_NUFIN,AD_SEQUENCIA) 

        VALUES (CUR.CODEMP, PARAM_DATACONT,CUR.AD_VARLOTE,NVL(V_MAX_NUMLANC_D,1),'D',CUR.AD_CODCTACTBDPPN,null,
        NVL(CUR.CODCENCUSDPPN,0) ,
        PARAM_DATAMOV,CUR.VLRVARCAMBLANC_TRATADO,NVL(CUR.CODHISTCTB,0),CUR.HISTORICO,CUR.NUMNOTA,null,'S',STP_GET_CODUSULOGADO(),
        NVL(CUR.AD_VARCODPROJ,0),'N',NVL(V_MAX_SEQUENCIA_D,1),null,null,null,SYSDATE,CUR.NUFIN,CUR.SEQUENCIA);

        END IF;  

        END LOOP; 
     END LOOP;
    P_MENSAGEM := 'Contabilização realizada com sucesso!';
    END;