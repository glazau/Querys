create or replace NONEDITIONABLE TRIGGER AD_TRG_INS_UPD_TGFITE_LOTE 
    BEFORE INSERT OR UPDATE ON TGFITE 
    FOR EACH ROW
    
    DECLARE 
    
    V_NUMNOTA           INT; 
    V_CODPROD           INT;
    V_CODPARC           INT;

    BEGIN
    /*
    Glaycon Henrique - 27/02/2023
    Processo: Automatizar numeração do lote de acordo com o numero da nota fiscal
    Este objeto trabalha em conjunto com o objeto na TGFCAB, cujo nome: AD_TRG_UPD_TGFCAB_LOTE 
    */       
        IF (UPDATING('QTDNEG') OR UPDATING ('VLRUNIT')) THEN
        /*
        PEGANDO O NRO DA NOTA, QUANDO O ITEM FOR CONTROLADO POR LOTE, TIPO DE MOVIMENTO FOR COMPRA E O NRO DA NOTA MAIOR QUE 0
        */
        SELECT CAB.NUMNOTA,PRO.CODPROD,CAB.CODPARC
        INTO V_NUMNOTA,V_CODPROD,V_CODPARC
        FROM TGFCAB CAB
        LEFT JOIN TGFPRO PRO ON PRO.CODPROD = :NEW.CODPROD AND PRO.TIPCONTEST = 'L'
        WHERE 1=1
        AND CAB.NUNOTA = :NEW.NUNOTA
        AND CAB.TIPMOV = 'C'; 

        /*
        QUANDO A TABELA TGFITE SOFRER ALTERAÇÃO, É FEITO O UPDATE NO CONTROLE DE ACORDO COM O NRO DA NOTA
        */  
        
        IF :OLD.CODPROD = :NEW.CODPROD AND V_CODPARC = 61 AND V_NUMNOTA > 0 AND :OLD.SEQUENCIA = :NEW.SEQUENCIA AND :OLD.CONTROLE = '' THEN
            :NEW.CONTROLE := V_NUMNOTA;
            END IF;
        END IF; 

        /*
        QUANDO A TABELA SOFRE INSERT, ALTERA O CONTROLE DE ACORDO COM O NRO DA NOTA
        */ 
        /*
        IF INSERTING  THEN
        :NEW.CONTROLE := V_NUMNOTA;
        END IF; 
        */
    END; 