create or replace PROCEDURE "AD_VALBAIXAVARCAMB" (
       P_TIPOEVENTO     INT,  
       P_IDSESSAO       VARCHAR2, 
       P_CODUSU         INT    
) AS
       BEFORE_INSERT    INT;
       AFTER_INSERT     INT;
       BEFORE_DELETE    INT;
       AFTER_DELETE     INT;
       BEFORE_UPDATE    INT;
       AFTER_UPDATE     INT;
       BEFORE_COMMIT    INT;

       P_CODTIPOPER         INT;
       P_CODTIPOPERBAIXA    INT;
       P_NUFIN              INT;  



BEGIN
       BEFORE_INSERT := 0;
       AFTER_INSERT  := 1;
       BEFORE_DELETE := 2;
       AFTER_DELETE  := 3;
       BEFORE_UPDATE := 4;
       AFTER_UPDATE  := 5;
       BEFORE_COMMIT := 10; 

        IF P_TIPOEVENTO = BEFORE_UPDATE THEN 

        P_CODTIPOPERBAIXA := EVP_GET_CAMPO_INT(P_IDSESSAO, 'CODTIPOPERBAIXA');
        P_CODTIPOPER := EVP_GET_CAMPO_INT(P_IDSESSAO, 'CODTIPOPER');
        P_NUFIN := EVP_GET_CAMPO_INT(P_IDSESSAO, 'NUFIN'); 
 


        IF P_TEM_TOPPERMITIDA = 0 AND NVL(P_CODTIPOPERBAIXA,0) <> 0 THEN
        
        RAISE_APPLICATION_ERROR(-20101, 'Necessário preencher a data de referência');

        END IF; 

        END IF; 
        
END;