create or replace PROCEDURE "AD_PRC_IMPOSTOS_XML" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       PARAM_P_DTINI DATE;
       PARAM_P_DTFIM DATE;
       
       V_RECORD  AD_IMPOSTOSXML%ROWTYPE;
    I         INT;
    P_COUNT   INT; 
    v_id int;
       
       
BEGIN

      

       PARAM_P_DTINI := ACT_DTA_PARAM(P_IDSESSAO, 'P_DTINI');
       PARAM_P_DTFIM := ACT_DTA_PARAM(P_IDSESSAO, 'P_DTFIM');

      
   
BEGIN

if (PARAM_P_DTFIM-PARAM_P_DTINI)>15 then
RAISE_APPLICATION_ERROR(-20000, 'O Intervalo máximo permitido é de 15 dias por processamento');
end if;


 select nvl(max(to_number(id)),0)+1 into v_id
    from AD_IMPOSTOSXML;
    DELETE AD_IMPOSTOSXML where dtemi between PARAM_P_DTINI and PARAM_P_DTFIM;
    COMMIT;
   
    
    
    FOR J IN (
        SELECT
            NUARQUIVO
        FROM
            TGFIXN
        WHERE
                LENGTH(XML) > 0
            AND TGFIXN.TIPO = 'N'
            AND ( TRUNC(DHEMISS) BETWEEN  PARAM_P_DTINI and PARAM_P_DTFIM )
        ORDER BY
            DHEMISS
    ) LOOP
        FOR D IN (
            SELECT
                NUMNOTA,
                SERIEDOC,
                CHAVEACESSO,
                NUARQUIVO,
                TO_CHAR(DHEMISS, 'dd/mm/yyyy') AS DTEMI,
                NUNOTA
            FROM
                TGFIXN
            WHERE
                NUARQUIVO = J.NUARQUIVO
        ) LOOP
            V_RECORD.NUMERONF := D.NUMNOTA;
            V_RECORD.SERIE := D.SERIEDOC;
            V_RECORD.CHAVENFE := D.CHAVEACESSO;
            V_RECORD.DTEMI := D.DTEMI;
            V_RECORD.NUNOTA := D.NUNOTA;
      --      V_RECORD.CODTIPOPER := NULL;
      --      V_RECORD.DESCROPER := NULL;
            IF
                NVL(V_RECORD.NUNOTA, 0) > 0
            THEN
                BEGIN
                    SELECT
                        MAX(TGFTOP.CODTIPOPER),
                        MAX(TGFTOP.DESCROPER)
                    INTO
                        V_RECORD.CODTIPOPER,
                        V_RECORD.DESCROPER
                    FROM
                        TGFCAB,
                        TGFTOP
                    WHERE
                            TGFCAB.CODTIPOPER = TGFTOP.CODTIPOPER
                        AND TGFCAB.NUNOTA = V_RECORD.NUNOTA;

                END;
            END IF;

            I := 1;
            WHILE I <= 990 LOOP
                SELECT
                    COUNT(1)
                INTO P_COUNT
                FROM
                    TGFIXN,
                    TABLE ( XMLSEQUENCE(EXTRACT(XMLTYPE(TGFIXN.XML), '/nfeProc/NFe/infNFe/det['
                                                                     || I
                                                                     || ']/@nItem')) )
                WHERE
                    TGFIXN.NUARQUIVO = D.NUARQUIVO;

                IF
                    P_COUNT = 0
                THEN
                    EXIT;
                END IF;
                ------------------------------------------------------------------
                SELECT
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/prod/cProd'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/prod/qCom'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/prod/xProd'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/prod/NCM'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/prod/uCom'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/prod/CFOP'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS00/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS00/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS00/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS00/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS00/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS10/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS10/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS10/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS10/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS10/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS20/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS20/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS20/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS20/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS20/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS30/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS30/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS30/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS30/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS30/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS40/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS40/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS40/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS40/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS40/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS41/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS41/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS41/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS41/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS41/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS50/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS50/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS50/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS50/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS50/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS51/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS51/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS51/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS51/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS51/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS60/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS60/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS60/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS60/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS60/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS70/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS70/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS70/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS70/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS70/pICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS90/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS90/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS90/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS90/vICMS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMS90/pICMS'),
                     
                   --------------------------------------------------------------
 
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN101/CSOSN'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN101/orig'),
                                            
                                             EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSST/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSST/orig'),
                                            
                                            
                                            
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN102/CSOSN'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN102/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN201/CSOSN'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN201/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN202/CSOSN'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN202/orig'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['|| I|| ']/imposto/ICMS/ICMSSN500/CSOSN'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['|| I|| ']/imposto/ICMS/ICMSSN500/orig'),
                    EXTRACTVALUE(VALUE(F1), '/nfeProc/NFe/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN900/CSOSN'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/ICMS/ICMSSN900/orig'),
         
                     
                   -----------------------------------------------------------    
                 
               
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISAliq/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISAliq/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISAliq/pPIS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISAliq/vPIS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISOutr/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISOutr/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISOutr/pPIS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISOutr/vPIS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISQtde/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISQtde/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISQtde/pPIS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISQtde/vPIS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISNT/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISNT/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISNT/pPIS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/PIS/PISNT/vPIS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSAliq/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSAliq/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSAliq/pCOFINS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSAliq/vCOFINS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSOutr/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSOutr/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSOutr/pCOFINS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSOutr/vCOFINS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSQtde/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSQtde/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSQtde/pCOFINS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSQtde/vCOFINS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSNT/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSNT/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSNT/pCOFINS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/COFINS/COFINSNT/vCOFINS'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/IPI/IPITrib/CST'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/IPI/IPITrib/vBC'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/IPI/IPITrib/pIPI'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/IPI/IPITrib/vIPI'),
                    EXTRACTVALUE(VALUE(F1), '/infNFe/det['
                                            || I
                                            || ']/imposto/IPI/IPINT/CST') 
            
                   
                   
                   --------------------------------------------------
                INTO
                    V_RECORD.CODPRODFORN,
                    V_RECORD.QTDNEG,
                    V_RECORD.DESCRPRODFORN,
                    V_RECORD.NCM,
                    V_RECORD.UCOM,
                    V_RECORD.CFOP,
                    V_RECORD.P_CST00,
                    V_RECORD.P_ORIG00,
                    V_RECORD.P_VBC00,
                    V_RECORD.P_VICMS00,
                    V_RECORD.P_PICMS00,
                    V_RECORD.P_CST10,
                    V_RECORD.P_ORIG10,
                    V_RECORD.P_VBC10,
                    V_RECORD.P_VICMS10,
                    V_RECORD.P_PICMS10,
                    V_RECORD.P_CST20,
                    V_RECORD.P_ORIG20,
                    V_RECORD.P_VBC20,
                    V_RECORD.P_VICMS20,
                    V_RECORD.P_PICMS20,
                    V_RECORD.P_CST30,
                    V_RECORD.P_ORIG30,
                    V_RECORD.P_VBC30,
                    V_RECORD.P_VICMS30,
                    V_RECORD.P_PICMS30,
                    V_RECORD.P_CST40,
                    V_RECORD.P_ORIG40,
                    V_RECORD.P_VBC40,
                    V_RECORD.P_VICMS40,
                    V_RECORD.P_PICMS40,
                    V_RECORD.P_CST41,
                    V_RECORD.P_ORIG41,
                    V_RECORD.P_VBC41,
                    V_RECORD.P_VICMS41,
                    V_RECORD.P_PICMS41,
                    V_RECORD.P_CST50,
                    V_RECORD.P_ORIG50,
                    V_RECORD.P_VBC50,
                    V_RECORD.P_VICMS50,
                    V_RECORD.P_PICMS50,
                    V_RECORD.P_CST51,
                    V_RECORD.P_ORIG51,
                    V_RECORD.P_VBC51,
                    V_RECORD.P_VICMS51,
                    V_RECORD.P_PICMS51,
                    V_RECORD.P_CST60,
                    V_RECORD.P_ORIG60,
                    V_RECORD.P_VBC60,
                    V_RECORD.P_VICMS60,
                    V_RECORD.P_PICMS60,
                    V_RECORD.P_CST70,
                    V_RECORD.P_ORIG70,
                    V_RECORD.P_VBC70,
                    V_RECORD.P_VICMS70,
                    V_RECORD.P_PICMS70,
                    V_RECORD.P_CST90,
                    V_RECORD.P_ORIG90,
                    V_RECORD.P_VBC90,
                    V_RECORD.P_VICMS90,
                    V_RECORD.P_PICMS90,
                    V_RECORD.P_ICMSSN101CSOSN,
                    V_RECORD.P_ICMSSN101ORIG,
                    
                      V_RECORD.P_ICMSSTCST,
                      V_RECORD.P_ICMSSTorig,
                    
                    
                    V_RECORD.P_ICMSSN102CSOSN,
                    V_RECORD.P_ICMSSN102ORIG,
                    V_RECORD.P_ICMSSN201CSOSN,
                    V_RECORD.P_ICMSSN201ORIG,
                    V_RECORD.P_ICMSSN202CSOSN,
                    V_RECORD.P_ICMSSN202ORIG,
                    V_RECORD.P_ICMSSN500CSOSN,
                    V_RECORD.P_ICMSSN500ORIG,
                    V_RECORD.P_ICMSSN900CSOSN,
                    V_RECORD.P_ICMSSN900ORIG,
                   
			  
			  V_RECORD.P_PISALIQCST,
                    V_RECORD.P_PISALIQVBC,
                    V_RECORD.P_PISALIQPPIS,
                    V_RECORD.P_PISALIQVPIS,
                    V_RECORD.P_PISOUTRCST,
                    V_RECORD.P_PISOUTRVBC,
                    V_RECORD.P_PISOUTRPPIS,
                    V_RECORD.P_PISOUTRVPIS,
                    V_RECORD.P_PISQTDECST,
                    V_RECORD.P_PISQTDEVBC,
                    V_RECORD.P_PISQTDEPPIS,
                    V_RECORD.P_PISQTDEVPIS,
                    V_RECORD.P_PISNTCST,
                    V_RECORD.P_PISNTVBC,
                    V_RECORD.P_PISNTPPIS,
                    V_RECORD.P_PISNTVPIS,
                    V_RECORD.P_COFINSALIQCST,
                    V_RECORD.P_COFINSALIQVBC,
                    V_RECORD.P_COFINSALIQPCOFINS,
                    V_RECORD.P_COFINSALIQVCOFINS,
                    V_RECORD.P_COFINSOUTRCST,
                    V_RECORD.P_COFINSOUTRVBC,
                    V_RECORD.P_COFINSOUTRPCOFINS,
                    V_RECORD.P_COFINSOUTRVCOFINS,
                    V_RECORD.P_COFINSQTDECST,
                    V_RECORD.P_COFINSQTDEVBC,
                    V_RECORD.P_COFINSQTDEPCOFINS,
                    V_RECORD.P_COFINSQTDEVCOFINS,
                    V_RECORD.P_COFINSNTCST,
                    V_RECORD.P_COFINSNTVBC,
                    V_RECORD.P_COFINSNTPCOFINS,
                    V_RECORD.P_COFINSNTVCOFINS,
                    V_RECORD.P_IPITRIBCST,
                    V_RECORD.P_IPITRIBVBC,
                    V_RECORD.P_IPITRIBPIPI,
                    V_RECORD.P_IPITRIBVIPI,
                    V_RECORD.P_IPINTCST
                FROM
                    TGFIXN,
                    TABLE ( XMLSEQUENCE(EXTRACT(XMLTYPE(TGFIXN.XML), '/nfeProc/NFe/infNFe')) ) F1
                WHERE
                    TGFIXN.NUARQUIVO = D.NUARQUIVO;
                    ---------------------------------------------


                V_RECORD.SEQUENCIA := I;
                V_RECORD.CODPROD := 0;
                V_RECORD.DESCRPROD := NULL;
                BEGIN
                    SELECT
                        TGFPRO.CODPROD,
                        TGFPRO.DESCRPROD
                    INTO
                        V_RECORD.CODPROD,
                        V_RECORD.DESCRPROD
                    FROM
                        TGFITE,
                        TGFPRO
                    WHERE
                            NUNOTA = V_RECORD.NUNOTA
                        AND SEQUENCIA = V_RECORD.SEQUENCIA
                        AND TGFPRO.CODPROD = TGFITE.CODPROD;

                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;

 
-----------------------replace ---------------
                V_RECORD.QTDNEG:= REPLACE(V_RECORD.QTDNEG, '.', ',');
                V_RECORD.P_VBC00 := REPLACE(V_RECORD.P_VBC00, '.', ',');
                V_RECORD.P_VICMS00 := REPLACE(V_RECORD.P_VICMS00, '.', ',');
                V_RECORD.P_PICMS00 := REPLACE(V_RECORD.P_PICMS00, '.', ',');
                V_RECORD.P_VBC10 := REPLACE(V_RECORD.P_VBC10, '.', ',');
                V_RECORD.P_VICMS10 := REPLACE(V_RECORD.P_VICMS10, '.', ',');
                V_RECORD.P_PICMS10 := REPLACE(V_RECORD.P_PICMS10, '.', ',');
                V_RECORD.P_VBC20 := REPLACE(V_RECORD.P_VBC20, '.', ',');
                V_RECORD.P_VICMS20 := REPLACE(V_RECORD.P_VICMS20, '.', ',');
                V_RECORD.P_PICMS20 := REPLACE(V_RECORD.P_PICMS20, '.', ',');
                V_RECORD.P_VBC30 := REPLACE(V_RECORD.P_VBC30, '.', ',');
                V_RECORD.P_VICMS30 := REPLACE(V_RECORD.P_VICMS30, '.', ',');
                V_RECORD.P_PICMS30 := REPLACE(V_RECORD.P_PICMS30, '.', ',');
                V_RECORD.P_VBC40 := REPLACE(V_RECORD.P_VBC40, '.', ',');
                V_RECORD.P_VICMS40 := REPLACE(V_RECORD.P_VICMS40, '.', ',');
                V_RECORD.P_PICMS40 := REPLACE(V_RECORD.P_PICMS40, '.', ',');
                V_RECORD.P_VBC41 := REPLACE(V_RECORD.P_VBC41, '.', ',');
                V_RECORD.P_VICMS41 := REPLACE(V_RECORD.P_VICMS41, '.', ',');
                V_RECORD.P_PICMS41 := REPLACE(V_RECORD.P_PICMS41, '.', ',');
                V_RECORD.P_VBC50 := REPLACE(V_RECORD.P_VBC50, '.', ',');
                V_RECORD.P_VICMS50 := REPLACE(V_RECORD.P_VICMS50, '.', ',');
                V_RECORD.P_PICMS50 := REPLACE(V_RECORD.P_PICMS50, '.', ',');
                V_RECORD.P_VBC51 := REPLACE(V_RECORD.P_VBC51, '.', ',');
                V_RECORD.P_VICMS51 := REPLACE(V_RECORD.P_VICMS51, '.', ',');
                V_RECORD.P_PICMS51 := REPLACE(V_RECORD.P_PICMS51, '.', ',');
                V_RECORD.P_VBC60 := REPLACE(V_RECORD.P_VBC60, '.', ',');
                V_RECORD.P_VICMS60 := REPLACE(V_RECORD.P_VICMS60, '.', ',');
                V_RECORD.P_PICMS60 := REPLACE(V_RECORD.P_PICMS60, '.', ',');
                V_RECORD.P_VBC70 := REPLACE(V_RECORD.P_VBC70, '.', ',');
                V_RECORD.P_VICMS70 := REPLACE(V_RECORD.P_VICMS70, '.', ',');
                V_RECORD.P_PICMS70 := REPLACE(V_RECORD.P_PICMS70, '.', ',');
                V_RECORD.P_VBC90 := REPLACE(V_RECORD.P_VBC90, '.', ',');
                V_RECORD.P_VICMS90 := REPLACE(V_RECORD.P_VICMS90, '.', ',');
                V_RECORD.P_PICMS90 := REPLACE(V_RECORD.P_PICMS90, '.', ',');
                V_RECORD.P_PISALIQCST := REPLACE(V_RECORD.P_PISALIQCST, '.', ',');
                V_RECORD.P_PISALIQVBC := REPLACE(V_RECORD.P_PISALIQVBC, '.', ',');
                V_RECORD.P_PISALIQPPIS := REPLACE(V_RECORD.P_PISALIQPPIS, '.', ',');
                V_RECORD.P_PISALIQVPIS := REPLACE(V_RECORD.P_PISALIQVPIS, '.', ',');
                V_RECORD.P_PISOUTRCST := REPLACE(V_RECORD.P_PISOUTRCST, '.', ',');
                V_RECORD.P_PISOUTRVBC := REPLACE(V_RECORD.P_PISOUTRVBC, '.', ',');
                V_RECORD.P_PISOUTRPPIS := REPLACE(V_RECORD.P_PISOUTRPPIS, '.', ',');
                V_RECORD.P_PISOUTRVPIS := REPLACE(V_RECORD.P_PISOUTRVPIS, '.', ',');
                V_RECORD.P_PISQTDECST := REPLACE(V_RECORD.P_PISQTDECST, '.', ',');
                V_RECORD.P_PISQTDEVBC := REPLACE(V_RECORD.P_PISQTDEVBC, '.', ',');
                V_RECORD.P_PISQTDEPPIS := REPLACE(V_RECORD.P_PISQTDEPPIS, '.', ',');
                V_RECORD.P_PISQTDEVPIS := REPLACE(V_RECORD.P_PISQTDEVPIS, '.', ',');
                V_RECORD.P_PISNTVBC := REPLACE(V_RECORD.P_PISNTVBC, '.', ',');
                V_RECORD.P_PISNTPPIS := REPLACE(V_RECORD.P_PISNTPPIS, '.', ',');
                V_RECORD.P_PISNTVPIS := REPLACE(V_RECORD.P_PISNTVPIS, '.', ',');
                V_RECORD.P_COFINSALIQVBC := REPLACE(V_RECORD.P_COFINSALIQVBC, '.', ',');
                V_RECORD.P_COFINSALIQPCOFINS := REPLACE(V_RECORD.P_COFINSALIQPCOFINS, '.', ',');
                V_RECORD.P_COFINSALIQVCOFINS := REPLACE(V_RECORD.P_COFINSALIQVCOFINS, '.', ',');
                V_RECORD.P_COFINSOUTRVBC := REPLACE(V_RECORD.P_COFINSOUTRVBC, '.', ',');
                V_RECORD.P_COFINSOUTRPCOFINS := REPLACE(V_RECORD.P_COFINSOUTRPCOFINS, '.', ',');
                V_RECORD.P_COFINSOUTRVCOFINS := REPLACE(V_RECORD.P_COFINSOUTRVCOFINS, '.', ',');
                V_RECORD.P_COFINSQTDEVBC := REPLACE(V_RECORD.P_COFINSQTDEVBC, '.', ',');
                V_RECORD.P_COFINSQTDEPCOFINS := REPLACE(V_RECORD.P_COFINSQTDEPCOFINS, '.', ',');
                V_RECORD.P_COFINSQTDEVCOFINS := REPLACE(V_RECORD.P_COFINSQTDEVCOFINS, '.', ',');
                V_RECORD.P_COFINSNTVBC := REPLACE(V_RECORD.P_COFINSNTVBC, '.', ',');
                V_RECORD.P_COFINSNTPCOFINS := REPLACE(V_RECORD.P_COFINSNTPCOFINS, '.', ',');
                V_RECORD.P_COFINSNTVCOFINS := REPLACE(V_RECORD.P_COFINSNTVCOFINS, '.', ',');
                V_RECORD.P_IPITRIBVBC := REPLACE(V_RECORD.P_IPITRIBVBC, '.', ',');
                V_RECORD.P_IPITRIBPIPI := REPLACE(V_RECORD.P_IPITRIBPIPI, '.', ',');
                V_RECORD.P_IPITRIBVIPI := REPLACE(V_RECORD.P_IPITRIBVIPI, '.', ',');

--V_RECORD.id:=v_id;

                v_id:=v_id+1;
                V_RECORD.id:=v_id;
                INSERT INTO AD_IMPOSTOSXML VALUES V_RECORD;

                COMMIT;
               
                
                I := I + 1;
            END LOOP;

        END LOOP;
    END LOOP;

END;

end;