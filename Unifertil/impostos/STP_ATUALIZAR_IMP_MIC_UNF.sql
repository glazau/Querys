create or replace PROCEDURE         "STP_ATUALIZAR_IMP_MIC_UNF" ( P_NUARQUIVO NUMBER
                                                        , P_TPOIMP  VARCHAR2
                                                        , P_MENSAGEM OUT VARCHAR2) AS
    v_nfexml    Ad_wsmicnfexml%Rowtype;

    v_cab       tgfcab%rowtype;
    v_ite       tgfite%rowtype;
    v_top       tgftop%rowtype;
    v_din       tgfdin%rowtype;

    v_xmlnfeDI      ad_wsmicnfedi%rowtype; 
    v_xmlnfeIPI     ad_wsmicnfeipi%rowtype;  
    v_xmlnfeICM     ad_wsmicnfeicm%rowtype;
    v_xmlnfePIS     ad_wsmicnfepis%rowtype;
    v_xmlnfeCOFINS  ad_wsmicnfecofins%rowtype;

BEGIN
    P_MENSAGEM := '';

    Begin
        Select * into v_nfexml
          From Ad_wsmicnfexml
         Where Nuarquivo = P_NUARQUIVO;
    Exception
        When Others Then
            v_nfexml := Null;
    End; 

    Begin 
        Select * into v_cab 
          From tgfcab 
         Where nunota = v_nfexml.Nunota;
           ----and dtneg >= '01/11/2021';
    Exception
        When Others Then
            v_cab := Null;
    End;

    -- Identifica a top
     Begin
         Select * into v_top 
           From tgftop 
          Where codtipoper = v_cab.codtipoper 
            And dhalter    = v_cab.dhtipoper;
     Exception
        When Others Then
            v_top := null;
     End;  

    ----P - Pis 
    -----Atualizar os valores do PIS
    If P_TPOIMP = 'P' Or P_TPOIMP = 'T' Then

         ---Atualizar o imposto PIS
         ---Alimentar dados a partir da tabela AD_WSMICNFEPIS
         ---Busca os dados do PIS
         For R_pis in (Select chnfe, nItem, v_nfexml.Nunota 
                         From ad_wsmicnfepis 
                        Where chnfe = v_nfexml.chnfe)
         Loop

           Begin
                Select * Into v_xmlnfePIS
                  From ad_wsmicnfepis
                 Where chnfe = R_pis.chnfe
                   And nItem = R_pis.nItem;
           Exception
                When Others Then
                    v_xmlnfePIS := Null;
           End;

           If v_xmlnfePIS.chnfe Is Not Null Then

                Begin
                    Select * Into v_din
                      From Tgfdin din
                     Where din.nunota    = R_pis.nunota
                       And din.sequencia = R_pis.nitem
                       And din.codimp    = 6; ----PIS
                Exception
                    When Others Then
                        v_din := Null;
                End;    

                If Nvl(v_din.nunota,0) > 0 Then 
                    v_din.CST       := v_xmlnfePIS.CST;
                    v_din.Base      := v_xmlnfePIS.vBC;
                    v_din.BaseRed   := v_xmlnfePIS.vBC;
                    v_din.aliquota  := v_xmlnfePIS.pPis;
                    v_din.valor     := v_xmlnfePIS.vPis;

                     Begin
                         -- Insere o item no pedido
                         update Tgfdin 
                            set row       = v_din 
                          where nunota    = v_din.nunota 
                            and sequencia = v_din.sequencia
                            and codimp    = v_din.codimp;
                     Exception
                        When Others Then
                            P_Mensagem := 'ERROR'; 
                           -- Return;
                     End;                         
                Else
                    v_din.nunota    := v_cab.nunota;
                    v_din.sequencia := v_xmlnfePIS.nitem;
                    v_din.codimp    := 6; ----PIS
                    v_din.CST       := v_xmlnfePIS.CST;
                    v_din.Base      := v_xmlnfePIS.vBC;
                    v_din.BaseRed   := v_xmlnfePIS.vBC;
                    v_din.aliquota  := v_xmlnfePIS.pPis;
                    v_din.valor     := v_xmlnfePIS.vPis;

                    if Nvl(v_din.nunota,0) > 0 Then
                      v_din := pkg_cab.criarDIN (v_din);
                    End If;
                End If;  
                ----P_MENSAGEM := P_MENSAGEM || ' PIS (OK) ';
           End if;

           Commit;

         End Loop;

         If P_TPOIMP = 'P' Then
            Return;
         End If;

    ---C - Cofins
    -----Atualizar os valores do COFINS
    ElsIf P_TPOIMP = 'C' Or P_TPOIMP = 'T' Then

        ---Alimentar dados a partir da tabela AD_WSMICNFECOFINS
        ---Busca os dados do COFINS

        For R_cofins in (Select chnfe, nItem, v_nfexml.Nunota 
                           From ad_wsmicnfecofins 
                          Where chnfe = v_nfexml.chnfe)
        Loop

            Begin
                Select * Into v_xmlnfeCOFINS
                  From ad_wsmicnfecofins
                 Where chnfe = R_cofins.chnfe
                   And nItem = R_cofins.nItem;
            Exception
                When Others Then
                    v_xmlnfeCOFINS := Null;
            End;

            If v_xmlnfeCOFINS.chnfe Is Not Null Then

                Begin
                    Select * Into v_din
                      From Tgfdin din
                     Where din.nunota    = R_cofins.nunota
                       And din.sequencia = R_cofins.nItem
                       And din.codimp    = 7; ----COFINS
                Exception
                    When Others Then
                        v_din := Null;
                End;   

                If Nvl(v_din.nunota,0) > 0 Then 
                    v_din.CST       := v_xmlnfeCOFINS.CST;
                    v_din.Base      := v_xmlnfeCOFINS.vBC;
                    v_din.BaseRed   := v_xmlnfeCOFINS.vBC;
                    v_din.aliquota  := v_xmlnfeCOFINS.pCOFINS;
                    v_din.valor     := v_xmlnfeCOFINS.vCOFINS;

                     -- Insere o item no pedido
                     Begin
                         update Tgfdin 
                            set row       = v_din 
                          where nunota    = v_din.nunota 
                            and sequencia = v_din.sequencia
                            and codimp    = v_din.codimp;
                     Exception
                        When Others Then
                            P_Mensagem := 'ERROR'; 
                            Return;
                     End; 
                Else
                    v_din.nunota    := v_cab.nunota;
                    v_din.sequencia := v_xmlnfeCOFINS.nitem;
                    v_din.codimp    := 7; ----COFINS
                    v_din.CST       := v_xmlnfeCOFINS.CST;
                    v_din.Base      := v_xmlnfeCOFINS.vBC;
                    v_din.BaseRed   := v_xmlnfeCOFINS.vBC;
                    v_din.aliquota  := v_xmlnfeCOFINS.pCOFINS;
                    v_din.valor     := v_xmlnfeCOFINS.vCOFINS;

                    ----v_din           := pkg_cab.criarDIN (v_din);
                    if Nvl(v_din.nunota,0) > 0 Then
                      v_din := pkg_cab.criarDIN (v_din);
                    End If;
                End If; 
            End If;
            ----P_MENSAGEM := P_MENSAGEM || ' COFINS (OK) ';
            Commit;

        End Loop;

        If P_TPOIMP = 'C' Then
            Return;
        End If;

    ---I - IPI
    -----Atualizar os valores do IPI
    ElsIf P_TPOIMP = 'I' Or P_TPOIMP = 'T' Then
         ---Atualizar o imposto IPI
         ---Alimentar dados a partir da tabela AD_WSMICNFEIPI

         For R_ipi in (Select chnfe, nItem, v_nfexml.Nunota 
                         From ad_wsmicnfeipi 
                        Where chnfe = v_nfexml.chnfe)
         Loop

             ---Busca os dados do IPI
             Begin
                Select * Into v_xmlnfeIPI
                  From ad_wsmicnfeipi
                 Where chnfe = R_ipi.chnfe
                   And nItem = R_ipi.nItem;
             Exception
                When Others Then
                    v_xmlnfeIPI := Null;
             End;

             Begin 
                Select * Into v_ite 
                  From tgfite 
                 Where Nunota    = R_ipi.Nunota
                   And Sequencia = R_ipi.nitem;
             Exception
                When Others Then
                    v_ite := Null;
             End;

             v_ite.CODENQIPI := v_xmlnfeIPI.cEnq;
             v_ite.CSTIPI    := (Case When v_top.tipmov = 'C' And v_xmlnfeIPI.CST > 49 Then v_xmlnfeIPI.CST - 50 Else v_xmlnfeIPI.CST End);  

             -- Insere/Altera o item no pedido
             Update Tgfite 
                Set Row       = V_ite 
              Where Nunota    = V_ite.Nunota 
                And Sequencia = V_ite.Sequencia;               

            ----P_MENSAGEM := P_MENSAGEM || ' IPI (OK) ';
            Commit;

         End Loop; 

         If P_TPOIMP = 'I' Then
            Return;
         End If;

    ---M - ICMS
    -----Atualizar os valores do ICMS
    ElsIf P_TPOIMP = 'M' Or P_TPOIMP = 'T' Then

        ---Alimentar dados a partir da tabela AD_WSMICNFEICM
        ---Busca os dados do ICM
        For R_icm in (Select chnfe, nItem, v_nfexml.Nunota 
                        From ad_wsmicnfeicm 
                       Where chnfe = v_nfexml.chnfe)
        Loop

             ---Busca os dados do ICMS
            Begin
                Select * Into v_xmlnfeICM
                  From ad_wsmicnfeicm
                 Where chnfe = v_nfexml.chnfe;
            Exception
                When Others Then
                    v_xmlnfeICM := Null;
            End;

            Begin 
                Select * Into v_ite 
                  From tgfite 
                 Where Nunota    = R_icm.Nunota
                   And Sequencia = R_icm.nitem;
            Exception
                When Others Then
                    v_ite := Null;
            End;

            v_ite.origprod     := v_xmlnfeICM.orig;  
            v_ite.codtrib      := v_xmlnfeICM.CST;  
            /*
            Nome: Glaycon Pereira
            Inserido para pegar os dados que faltavam relacionado ao icms.
            */
            v_ite.baseicms     := v_xmlnfeICM.vbc;    
            v_ite.aliqicms     := v_xmlnfeICM.picms;
            v_ite.vlricms      := v_xmlnfeICM.VICMS;
            /*
            Fim da alteração
            */

             -- Insere/Altera o item no pedido
             Update Tgfite 
                Set Row       = V_ite 
              Where Nunota    = V_ite.Nunota 
                And Sequencia = V_ite.Sequencia;  

            Commit; 
        End Loop;

        -- Atualiza o valor total do pedido
        Update tgfcab
           Set (vlrnota, baseicms, vlricms, baseiss, vlriss) = (select sum(vlrtot), sum(baseicms), sum(vlricms), sum(baseiss), sum(vlriss) from tgfite where nunota = V_cab.nunota)
         Where nunota = V_cab.nunota;   

        ----P_MENSAGEM := P_MENSAGEM || ' ICMS (OK) ';
        Commit;

        If P_TPOIMP = 'M' Then
            Return;
        End If;   
    End If; 

    --P_MENSAGEM := ' TESTE ';
    Return;

END;