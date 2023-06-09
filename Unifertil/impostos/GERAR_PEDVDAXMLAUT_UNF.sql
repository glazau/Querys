create or replace PROCEDURE                 "GERAR_PEDVDAXMLAUT_UNF" (P_NUARQUIVO  NUMBER := 0, P_SEMPEDORIG CHAR := 'N') 
AS
      
       P_Count         Number;
       
       v_codmodelo     tsipar.inteiro%type;
       
       v_codprod       tgfite.codprod%type;
       v_qtde          tgfite.qtdneg%type;
       v_vlrunit       tgfite.vlrunit%type;
       v_codlocalorig  tgfite.codlocalorig%type;
       
       v_mod           tgfcab%rowtype;
       v_top           tgftop%rowtype; 
       v_cab           tgfcab%rowtype;
       v_ite           tgfite%rowtype;
       v_pro           tgfpro%rowtype;
       v_din           tgfdin%rowtype;
       v_iii           tgfiii%rowtype;
       v_idi           tgfidi%rowtype;
       v_iad           tgfiad%rowtype;
         
       ---v_xml           ad_wsmicnfexml%rowtype; 
       v_xmlnfe        ad_wsmicnfe%rowtype;  
       v_xmlnfeProd    ad_wsmicnfeprod%rowtype;
       v_xmlnfeDI      ad_wsmicnfedi%rowtype; 
       v_xmlnfeTransp  ad_wsmicnfetransp%rowtype;   
       v_xmlnfeIPI     ad_wsmicnfeipi%rowtype;  
       v_xmlnfeICM     ad_wsmicnfeicm%rowtype;
       v_xmlnfePIS     ad_wsmicnfepis%rowtype;
       v_xmlnfeCOFINS  ad_wsmicnfecofins%rowtype;
       
       v_wsmicnfexml   Ad_wsmicnfexml%rowtype;
       
       v_regraCFOP     Ad_importacaomic%rowtype;
       
       v_mensagem      Varchar2(4000);
       P_Sequencial    Int;
       
       ERRMSG          VARCHAR2(4000);
       ERROR           EXCEPTION;

BEGIN
       
       ----Identifica o modelo de nota para o XML
       Begin           
           Select Nvl(Min(Inteiro),0) Into V_codmodelo 
             From Tsipar 
            Where Chave = 'CODMODNOTAXML';
       Exception
            When Others Then
                V_codmodelo := 0;
       End;
       
       --       Modelo
       --            Notas Remessa               (filhas CFOP 3949) 3248  ---CFOP: 3949        ----- 1349 - REMESSA IMPORTACAO - EMITIDA MIC
       --            Movimentação de Estoque     (CFOP 5.152) 3250        ---CFOP: 5208 - 6208 ----- 1449 - DEVOL TRANSF ENT EMP - EMITIDA MIC
       --            Movimentação de Estoque     (CFOP 5.209) 3251        ---CFOP: 5102 - 6102 ----- 2308 - FATURAMENTO DE PERMUTA - MIC
       --            Acerto Nota de Permuta      (CFOP 5.102) 3252        ---CFOP: 5151 - 6151 ----- 2347 - TRANSF ENTRE EMPRESAS - EXCLUSIVO MIC
       --            Envio para Industrialização (CFOP 5901) 3253         ---CFOP: 5901 - 6901 ----- 2349 - REM P/ IND P/ ENC - EMITIDA MIC
       
       For R_Xml In (Select * 
                       From Ad_wsmicnfexml
                      Where (Nuarquivo = P_NUARQUIVO
                        And TIPO = 'NFE')
                         Or (Nvl(P_NUARQUIVO,0) = 0 And Status = 0 And (Nuarquivo >= 1116 Or CHNFE = '43201287249561000107552030000000031170730088')) ---Status = Importado
                      Order By DhImportacao    
                    )
       Loop    
             If Nvl(R_Xml.Nunota,0) > 0 Then
                    Begin
                        Select Count(*) Into P_Count 
                          From Tgfcab
                         Where Nunota = R_Xml.Nunota;
                    Exception
                        When Others Then 
                            P_Count := 0;
                    End;
                    
                    If P_Count > 0 Then
                        V_MENSAGEM := 'ERRO - Processo cancelado. Já existe nota vinculada!!! Nunota: '||R_Xml.Nunota;
                        GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                               , P_MENSAGEM  => V_MENSAGEM);
                                           
                         ----Atualizar a origem do XML
                         Update ad_wsmicnfexml
                            Set Status       = '1' ---Processado
                          Where chnfe = R_xml.chnfe
                            And Tipo  = R_xml.Tipo;
                                                   
                        Return;
                        
                    Else  
                        ----Atualizar a origem do XML
                         Update ad_wsmicnfexml
                            Set Codemp       = Null
                              , Codparc      = Null 
                              , Nunota       = Null
                              , Numnota      = Null
                              , Status       = '0' ---Importado
                              , NUNOTAORI    = Null
                          Where chnfe = R_xml.chnfe
                            And Tipo  = R_xml.Tipo;
                    End If;   
               
             End If;
               
             ----Se não houver um modelo irá cancelar o processo de nota
             If V_codmodelo = 0 Then
                    V_MENSAGEM := 'ERRO - Processo cancelado. Não existe modelo de nota!!! Modelo: '||V_codmodelo;
                    GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                           , P_MENSAGEM  => V_MENSAGEM);
                                           
                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null 
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = Null
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                                               
                    Return;
             End If; 
              
             -- Identifica dados do modelo de Notas para XML
             Begin
                   Select * Into V_mod 
                     From Tgfcab 
                    Where Nunota = V_codmodelo;
             Exception
                   When Others Then
                        V_mod := Null;
             End;
               
             ----Verifiaca se tem Chave NFE o xml importado
             If V_mod.Nunota Is Null Then
                    v_mensagem := 'ERRO - Processo cancelado. Não existe modelo de nota!!! Modelo: '||V_codmodelo;
                    
                    GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                           , P_MENSAGEM  => V_MENSAGEM);
                                           
                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null 
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = Null
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                                                                 
                    Return;
             End If; 
               
             ----Verifiaca se tem Chave NFE o xml importado
             If R_Xml.chnfe Is Null Then
                    v_mensagem := 'Chave não foi informada, não é possivel gerar uma nota!!! Nro Arquivo: '||P_NUARQUIVO;
                    
                    GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                           , P_MENSAGEM  => V_MENSAGEM);
                                           
                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null 
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = Null
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                                                                 
                    Return;
             End If; 
               
             Begin
                    Select Count(*) Into P_Count
                      From Tgfcab cab
                     Where Cab.Chavenfe    = R_Xml.chnfe
                        Or Cab.Chavenferef = R_Xml.chnfe;
             Exception
                    When Others Then
                        P_Count := 0;
             End;
               
             ----Verifica se tem chave NFE importada
             If P_count > 0 /*And 1<>1*/ Then
                    v_mensagem := 'Chave Informada já foi integrada!!! Chave NFE: '||R_Xml.chnfe;
                    
                    GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                           , P_MENSAGEM  => V_MENSAGEM);
                                           
                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null 
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = Null
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;                                           
                    Return;
             End If;
               
               -- Identifica o registro modelo
--               Select * into v_cab 
--                 From tgfcab 
--                Where nunota = 4640;
                
             ---Busca os dados da Nota Fiscal
             Begin
                Select * Into v_xmlnfe
                  From Ad_wsmicnfe
                 Where chnfe = R_Xml.chnfe;
             Exception
                When Others Then
                    v_xmlnfe := Null;
             End;
               
             If v_xmlnfe.chnfe Is Null Then
                  v_mensagem     := 'ERRO - Não existem dados da Nota!!! Nro Arquivo: '||R_Xml.Nuarquivo||' - Tabela: AD_WSMICNFE';
                  
                  GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                         , P_MENSAGEM  => V_MENSAGEM);
                                         
                  ----Atualizar a origem do XML
                  Update ad_wsmicnfexml
                     Set Codemp       = Null
                       , Codparc      = Null 
                       , Nunota       = Null
                       , Numnota      = Null
                       , Status       = '-1' ---Erro
                       , NaturezaOper = v_xmlnfe.natOp
                       , NUNOTAORI    = Null
                   Where chnfe = R_xml.chnfe
                     And Tipo  = R_xml.Tipo;
                                                            
                  Return;
             End if;     
               
               ---Alimentar dados a partir da tabela Ad_wsmicnfe
             v_mod.chavenfe    := v_xmlnfe.chnfe;
             v_mod.chavenferef := v_xmlnfe.refnfe;
             ---v_mod.STATUSNFE   := 'A';
             
             ----<ide>
             ----   <cUF>43</cUF>
             ----   <cNF>75073831</cNF>
             ----   <natOp>ENTRADA DIRETA PARA O IMPORTADOR</natOp>
             ----   <mod>55</mod>
             ----   <serie>203</serie>
             ----   <nNF>44145</nNF>
             ----   <dhEmi>2020-11-12T15:34:47-03:00</dhEmi>
             ----   <dhSaiEnt>2020-11-12T15:34:47-03:00</dhSaiEnt>
             ----   <tpNF>0</tpNF>
             ----   <idDest>3</idDest>
             ----   <cMunFG>4304606</cMunFG>
             ----   <tpImp>1</tpImp>
             ----   <tpEmis>1</tpEmis>
             ----   <cDV>3</cDV>
             ----   <tpAmb>1</tpAmb>
             ----   <finNFe>1</finNFe>
             ----   <indFinal>0</indFinal>
             ----   <indPres>9</indPres>
             ----   <procEmi>0</procEmi>
             ----   <verProc>200</verProc>
             ----   <NFref>
             ----       <refNFe>43201187249561000107552030000425001019126989</refNFe>
             ----   </NFref>
             ----</ide>
             v_mod.serienota := v_xmlnfe.serie;
             v_mod.numnota   := v_xmlnfe.nNF;
             v_mod.Dtneg     := v_xmlnfe.DhEmi;
             v_mod.DtFatur   := v_xmlnfe.DhEmi;  
             v_mod.DtEntSai  := v_xmlnfe.dhSaiEnt;
             v_mod.Hrentsai  := Trunc(v_mod.DtEntSai);---+ 2/1440; ---v_xmlnfe.dhSaiEnt;
             v_mod.codusu    := stp_get_codusulogado;
             v_mod.tipmov    := 'C';  ----Compra           
             -----</ide>
                     
             -----<emit>
             -----   <CNPJ>87249561000107</CNPJ>
             -----   <xNome>UNIFERTIL - UNIVERSAL DE FERTILIZANTES LTDA</xNome>
             -----   <xFant>UNIFERTIL - UNIVERSAL DE FERTILIZANTES LTDA</xFant>
             -----   <enderEmit>
             -----       <xLgr>RUA GRAVATAI</xLgr>
             -----       <nro>245</nro>
             -----       <xBairro>NITEROI</xBairro>
             -----       <cMun>4304606</cMun>
             -----       <xMun>CANOAS</xMun>
             -----       <UF>RS</UF>
             -----       <CEP>92130360</CEP>
             -----       <cPais>1058</cPais>
             -----       <xPais>BRASIL</xPais>
             -----       <fone>5134626250</fone>
             -----   </enderEmit>
             -----   <IE>0240043499</IE>
             -----   <CRT>3</CRT>
             -----</emit>
                                   
             v_mod.codemp  := pkg_cab.BuscarEmpresa(Pcnpj => v_xmlnfe.emit_cnpj);
                     
             If v_xmlnfe.dest_cnpj Is not Null Then
                v_mod.codparc := PKG_CAB.Buscarparceiro(Pcnpj => v_xmlnfe.dest_cnpj);
                
                Begin
                    Select Count(*) Into P_Count 
                      From Tgfpar
                     Where Codparc    = v_mod.codparc
                       And Ativo      = 'S'
                       And Fornecedor = 'S';    
                Exception
                    When Others Then
                        P_Count := 0;
                End;
                
                If P_Count = 0 Then                
                    V_MENSAGEM := 'ERRO - Processo cancelado. Não existe parceiro cadastrado ou Ativo ou não é Fornecedor!!! Parceiro: '||v_mod.codparc;
                   
                    GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                           , P_MENSAGEM  => V_MENSAGEM);                                         
                    
                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Status       = '-1' ---Erro
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                                                       
                    Return;
                End If;
             End If;   
                     
             -----<dest>
             -----   <idEstrangeiro/>
             -----   <xNome>KS MINERALS AND AGRICULTURE GMBH</xNome>
             -----   <enderDest>
             -----       <xLgr>BERTHA-VON-SUTTNER-STRASSE 7-34131</xLgr>
             -----       <nro>7</nro>
             -----       <xBairro>POSTFACH 102029 - 34111 KASSEL ALEMANHA</xBairro>
             -----       <cMun>9999999</cMun>
             -----       <xMun>EXTERIOR</xMun>
             -----       <UF>EX</UF>
             -----       <cPais>230</cPais>
             -----       <xPais>ALEMANHA</xPais>
             -----   </enderDest>
             -----   <indIEDest>9</indIEDest>
             -----</dest>
                     
             ----Escrever o codigo
                      
             -----<retirada>
             -----   <CNPJ>92808500000172</CNPJ>
             -----   <xLgr>AV MAUA</xLgr>
             -----   <nro>1050</nro>
             -----   <xBairro>CENTRO</xBairro>
             -----   <cMun>4314902</cMun>
             -----   <xMun>PORTO ALEGRE</xMun>
             -----   <UF>RS</UF>
             -----</retirada>
                     
             ---Dados Diversos
             v_mod.tipfrete      := (Case When v_xmlnfe.ModFrete in (0,3) Then 'S' Else 'N' End);
             v_mod.Cif_fob       := pkg_cab.BuscarFrete( Pfrete => v_xmlnfe.modFrete );
             v_mod.issretido     := 'N';
             v_mod.peso          := v_xmlnfe.pesoL;
             v_mod.pesobruto     := v_xmlnfe.pesoB;
             v_mod.Observacao    := v_xmlnfe.infCpl;
                     
             v_mod.Numaleatorio  := Null;
             v_mod.Numprotoc     := v_xmlnfe.Prot_NPROT;
             v_mod.DhProtoc      := v_xmlnfe.Prot_DHRECBTO;
             v_mod.NuloteNFE     := Null;
             v_mod.StatusNFE     := 'A'; --Null;
             v_mod.TpemisNFE     := Null;
                     
             v_mod.Codcidorigem  := Null;
             v_mod.Codciddestino := Null;
             v_mod.Codcidentrega := Null;
             v_mod.Coduforigem   := Null;
             v_mod.Codufdestino  := Null;
             v_mod.Codufentrega  := Null;
             v_mod.Classificms   := 'R';
             v_mod.tpambnfe      := 1;
                     
             ---Tag InfAdic
    --           <obsCont xCampo="NR_PEDIDO">
    --                <xTexto>6841</xTexto>
    --           </obsCont>
    --           <obsCont xCampo="NR_IMPORTACAO">
    --               <xTexto>25</xTexto>
    --           </obsCont>
    --           <obsCont xCampo="NR_TIQUETE">
    --               <xTexto>0212202015</xTexto>
    --           </obsCont>
    --           <obsCont xCampo="NAVIO">
    --               <xTexto>SANTA CAROLINA</xTexto>
    --           </obsCont>
    --           <obsCont xCampo="CD_TIPO_NF">
    --               <xTexto>I</xTexto>
    --           </obsCont>
    --           <obsCont xCampo="CD_OPERACAO">
    --               <xTexto>08</xTexto>
    --           </obsCont>
    --           <obsCont xCampo="CD_EMPRESA">
    --               <xTexto>132</xTexto>
    --           </obsCont>
             ----v_mod.AD_NROIMPORT := v_xmlnfe.NR_IMPORTACAO;
             
             ----Verifica se tem Nro de Importação informado
             If v_xmlnfe.NR_IMPORTACAO Is Not Null And Nvl(v_xmlnfe.NR_IMPORTACAO,0) > 0 Then
                 Begin
                    Select Count(*) Into P_count
                      From ad_tcecab                  
                     Where NUMIMP = Nvl(v_xmlnfe.NR_IMPORTACAO,0);
                 Exception
                    When Others Then
                        P_count := 0;
                 End;
               
                ----Se não houver quantidade maior que zero, coloca branco
                 If P_count > 0 Then
                    v_mod.AD_NROIMPORT := v_xmlnfe.NR_IMPORTACAO;
                 Else   
                    V_MENSAGEM     := 'ERRO - Não existe o Nro de Importação cadastrado!!! Nro Importação: '||v_xmlnfe.NR_IMPORTACAO||' - Tabela: AD_TCECAB';
                    ---Return;   
                    
                    GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                           , P_MENSAGEM  => V_MENSAGEM);
                       -----03/09/21 --LUIS  , despreza a mensagem de erro de importação, pois existe o numero do ticket no lugar da importação                
                     ----Atualizar a origem do XML
                  --   Update ad_wsmicnfexml
                  --      Set Codemp       = Null
                  --        , Codparc      = Null 
                  --        , Nunota       = Null
                  --        , Numnota      = Null
                  --        , Status       = '-1' ---Erro
                  --        , NaturezaOper = v_xmlnfe.natOp
                  --        , NUNOTAORI    = Null
                  --    Where chnfe = R_xml.chnfe
                  --      And Tipo  = R_xml.Tipo;                                         
                  --   Return;             
                 End If;   
             End if;
             
                          
             Begin
                Select * Into v_xmlnfeProd
                  From ad_wsmicnfeprod
                 Where chnfe = R_xml.chnfe;
             Exception
                When Others Then
                    v_xmlnfeProd := Null;
                    ERRMSG       := SQLERRM;
             End;
                 
             If v_xmlnfeProd.chnfe Is Null Then
                  v_mensagem     := 'ERRO - Não existem dados da Nota (Produtos)!!! Nro Arquivo: '||R_Xml.Nuarquivo||' - Chave de Acesso: '||R_xml.chnfe||' - Tabela: AD_WSMICNFEPROD.'||CHR(10)||'Error: '||ERRMSG;
                  
                  GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                         , P_MENSAGEM  => V_MENSAGEM);
                                         
                  ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null 
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = Null
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                  Return;
             End if;  
             
             ----Nro do Pedido possui em 2 tags (Tag: InfAdic-xCampo="NR_PEDIDO" ou xPed )
             -------<infAdic>
             -------   <infCpl></infCpl>
             -------   <obsCont xCampo="NR_PEDIDO">
             -------       <xTexto>2418</xTexto>
             -------   </obsCont>
             ---- ou
             -------<det nItem="1">
             -------   <prod>
             -------       <xPed>2418</xPed>
                          
             v_mod.AD_PEDRIGEM  := v_xmlnfe.NR_PEDIDO;
             v_mod.IDNAVIO      := v_xmlnfe.NAVIO; 
                                 
             -- Regras de TOPs
             --     CFOP: 3949        ----- 1349 - REMESSA IMPORTACAO - EMITIDA MIC
             --     CFOP: 5208 - 6208 ----- 1449 - DEVOL TRANSF ENT EMP - EMITIDA MIC
             --     CFOP: 5102 - 6102 ----- 2308 - FATURAMENTO DE PERMUTA - MIC
             --     CFOP: 5151 - 6151 ----- 2347 - TRANSF ENTRE EMPRESAS - EXCLUSIVO MIC
             --     CFOP: 5901 - 6901 ----- 2349 - REM P/ IND P/ ENC - EMITIDA MIC
             
             ----Verifica se tem exceção, caso não tenha, irá usar a tag v_xmlnfe.NR_PEDIDO e a top do modelo.
             Begin
                 Select * Into v_regraCFOP 
                   From Ad_importacaomic
                  Where CFOP = v_xmlnfeProd.CFOP;
             Exception
                When Others Then
                    v_regraCFOP := Null;
             End;    
             
             ----P - Pedido de Venda
             If Nvl(v_regraCFOP.PedOrigem,'X') = 'P' And Nvl(v_xmlnfeProd.xPed,0) > 0 Then
             
                v_mod.AD_PEDRIGEM := v_xmlnfeProd.xPed;
                v_mod.codtipoper  := Nvl(v_regraCFOP.CODTIPOPER,v_mod.codtipoper);
             
             ----C - Pedido de Compra
             ElsIf Nvl(v_regraCFOP.PedOrigem,'X') = 'C' And Nvl(v_xmlnfe.NR_PEDCPA,0) > 0 Then
             
                v_mod.AD_PEDRIGEM := v_xmlnfe.NR_PEDCPA;
                v_mod.codtipoper  := Nvl(v_regraCFOP.CODTIPOPER,v_mod.codtipoper);
             
             ----A - Informações Adicionais
             ElsIf Nvl(v_regraCFOP.PedOrigem,'X') = 'A' Then
               ---Não precisa fazer nada pois irá pegar os campos padrões
               -- v_mod.codtipoper => Usar a top que esta no modelo
               v_mod.AD_PEDRIGEM  := v_xmlnfe.NR_PEDIDO;
               
             Else  
               v_mod.AD_PEDRIGEM  := v_xmlnfe.NR_PEDIDO; 
             End If;
                         
                 
             ---Definir a TOP a partir do CFOP
             ----Desativado a regra abaixo no dia 28/06/2021
--             if    v_xmlnfeProd.CFOP = 3949 Then
--                v_mod.codtipoper := 1349;
--                
--                If Nvl(v_xmlnfeProd.xPed,0) > 0 Then            
--                    v_mod.AD_PEDRIGEM  := v_xmlnfeProd.xPed;
--                End If; 
--             ----   
--             Elsif    v_xmlnfeProd.CFOP In (5208,6208) Then
--                v_mod.codtipoper := 1449;
--                
--                If Nvl(v_xmlnfeProd.xPed,0) > 0 Then            
--                    v_mod.AD_PEDRIGEM  := v_xmlnfeProd.xPed;
--                End If; 
--             ----   
--             Elsif    v_xmlnfeProd.CFOP In (5102, 6102) Then
--                v_mod.codtipoper := 2308;
--                
--                If Nvl(v_xmlnfe.NR_PEDCPA,0) > 0 Then            
--                    v_mod.AD_PEDRIGEM  := v_xmlnfe.NR_PEDCPA; ---v_xmlnfeProd.xPed;
--                End If;   
--             ----      
--             Elsif    v_xmlnfeProd.CFOP In ( 5151, 6151) Then
--                v_mod.codtipoper := 2347;
--                
--                If Nvl(v_xmlnfeProd.xPed,0) > 0 Then            
--                    v_mod.AD_PEDRIGEM  := v_xmlnfeProd.xPed;
--                End If;
--             ----         
--             Elsif    v_xmlnfeProd.CFOP In ( 5152, 6152) Then
--                v_mod.codtipoper := 2347;
--                
--                If Nvl(v_xmlnfe.NR_PEDCPA,0) > 0 Then            
--                    v_mod.AD_PEDRIGEM  := v_xmlnfe.NR_PEDCPA;
--                End If;             
--             ----
--             Elsif v_xmlnfeProd.CFOP in (5209, 6209) Then
--                v_mod.codtipoper := 1449;  
--                
--                If Nvl(v_xmlnfe.NR_PEDCPA,0) > 0 Then
--                    v_mod.AD_PEDRIGEM := v_xmlnfe.NR_PEDCPA;
--                End If;                
--             ----                 
--             Elsif v_xmlnfeProd.CFOP In (5901, 6901) Then
--                v_mod.codtipoper := 2349;
--                
--                If Nvl(v_xmlnfe.NR_PEDCPA,0) > 0 Then
--                    v_mod.AD_PEDRIGEM := v_xmlnfe.NR_PEDCPA;
--                End If; 
--             ----
--             ----                 
--             Elsif v_xmlnfeProd.CFOP In (5905, 6905) Then
--                v_mod.codtipoper := 2318;
--                
--                If Nvl(v_xmlnfe.NR_PEDCPA,0) > 0 Then
--                    v_mod.AD_PEDRIGEM := v_xmlnfe.NR_PEDCPA;
--                End If; 
--             ----
--             End If;
             -----Fim da inserção dos itens - ad_wsmicnfeprod
             
             ---Definir a TOP a partir do CFOP
                 
             ---Alimentar dados a partir da tabela AD_WSMICNFEDI
             ---Busca os dados da DI
             Begin
                Select * Into v_xmlnfeDI
                  From ad_wsmicnfedi
                 Where chnfe = R_xml.chnfe;
             Exception
                When Others Then
                    v_xmlnfeDI := Null;
             End;
                          
             If v_xmlnfe.dest_cnpj Is Null Then
                v_mod.codparc := v_xmlnfeDI.cExportador;
                
                Begin
                    Select Count(*) Into P_Count 
                      From Tgfpar
                     Where Codparc    = v_mod.codparc
                       And Ativo      = 'S'
                       And Fornecedor = 'S';    
                Exception
                    When Others Then
                        P_Count := 0;
                End;
                
                If P_Count = 0 Then                
                    V_MENSAGEM := 'ERRO - Processo cancelado. Não existe parceiro cadastrado ou Ativo ou não é Fornecedor!!! Parceiro: '||v_mod.codparc;
                    
                    GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                           , P_MENSAGEM  => V_MENSAGEM);                                         
                     
                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Status       = '-1' ---Erro
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                                                       
                    Return;
                End If;
             End If; 
                 
             ---Alimentar dados a partir da tabela AD_WSMICNFEIPI
             ---Busca os dados do IPI
             Begin
                Select * Into v_xmlnfeIPI
                  From ad_wsmicnfeipi
                 Where chnfe = R_xml.chnfe;
             Exception
                When Others Then
                    v_xmlnfeIPI := Null;
             End;
                 
             If v_xmlnfeIPI.chnfe Is Null Then
                  v_mensagem     := 'ERRO - Não existem dados da Nota (Imposto IPI)!!! Nro Arquivo: '||R_Xml.Nuarquivo||' - Tabela: AD_WSMICNFEIPI';
                  
                  GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                         , P_MENSAGEM    => V_MENSAGEM);
                     
                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null 
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = Null
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;                                       
                  Return;
             End if;
                 
             ---Alimentar dados a partir da tabela AD_WSMICNFEICM
             ---Busca os dados do ICM
             Begin
                Select * Into v_xmlnfeICM
                  From ad_wsmicnfeicm
                 Where chnfe = R_xml.chnfe;
             Exception
                When Others Then
                    v_xmlnfeICM := Null;
             End;
                 
             If v_xmlnfeICM.chnfe Is Null Then
                  v_mensagem     := 'ERRO - Não existem dados da Nota (Imposto ICMS)!!! Nro Arquivo: '||R_Xml.Nuarquivo||' - Tabela: AD_WSMICNFEICM';
                  
                  GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                       , P_MENSAGEM    => V_MENSAGEM);
                                       
                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null 
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = Null
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                                                             
                  Return;
             End if;
                              
             ---Alimentar dados a partir da tabela AD_WSMICNFETRANSP
             ---Busca os dados da Nota Fiscal
             Begin
                Select * Into v_xmlnfeTransp
                  From ad_wsmicnfetransp
                 Where chnfe = R_xml.chnfe;
             Exception
                When Others Then
                    v_xmlnfeTransp := Null;
             End;
                 
             If v_xmlnfeTransp.chnfe Is Null Then
                  v_mensagem     := 'ERRO - Não existem dados da Nota (Transportes)!!! Nro Arquivo: '||R_Xml.Nuarquivo||' - Tabela: AD_WSMICNFETRANSP';
                  
                  GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                       , P_MENSAGEM    => V_MENSAGEM);

                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null 
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = Null
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;                                       
                  Return;
             End if;             
                 
             If  v_mod.tipfrete = 'S' Then
             
                v_mod.codparctransp := pkg_cab.BuscarParceiro(Pcnpj => v_xmlnfeTransp.transporta_cnpj);  
                Begin
                    Select Count(*) Into P_Count 
                      From Tgfpar
                     Where Codparc = v_mod.codparctransp;    
                Exception
                    When Others Then
                        P_Count := 0;
                End;
                    
                If P_Count = 0 Then                
                    V_MENSAGEM := 'ERRO - Processo cancelado. Não existe parceiro transportador cadastrado ou ativo!!! Parceiro: '||Nvl(v_mod.codparctransp,0)||' - Cnpj: '||v_xmlnfeTransp.transporta_cnpj;
                    
                    GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                           , P_MENSAGEM  => V_MENSAGEM);
                                                                                    
                     ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Status       = '-1' ---Erro
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                                                           
                    Return;
                End If;
             End If;                   
                             
             v_mod.qtdvol        := v_xmlnfeTransp.vol_qvol;
             v_mod.volume        := v_xmlnfeTransp.vol_esp;
             v_mod.placa         := v_xmlnfeTransp.VeicTransp_Placa;
             v_mod.ufveiculo     := pkg_cab.BuscarUF(v_xmlnfeTransp.VeicTransp_UF);

              ---luis 11/09
              if v_mod.codtipoper=2308 then
                  v_mod.codnat:=1010101;
                  v_mod.codcencus:=10209;
              end if;

             ---Criar a CAB
             Begin
                v_cab               :=  pkg_cab.criarCAB (v_mod); 
             Exception
                When Others Then
                    V_MENSAGEM := 'ERRO - Processo cancelado. Nota não criada!!! '||chr(13)||
                                   SQLERRM;
                    
                    GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                           , P_MENSAGEM  => V_MENSAGEM);
                                           
                    ----Atualizar a origem do XML
                    Update ad_wsmicnfexml
                       Set Status       = '-1' ---Erro
                     Where chnfe = R_xml.chnfe
                       And Tipo  = R_xml.Tipo;
                                                 
                    Return;
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
                 
             Begin
                 -- Identifica o produto
                  Select * Into v_pro 
                    From tgfpro 
                   Where codprod = v_xmlnfeProd.cProd;
             Exception
                When Others Then
                    v_pro := null;
             End;   
             
             If Nvl(v_pro.Codprod,0) = 0 Then
                  v_mensagem     := 'ERRO - Não existem o produto ('||v_xmlnfeProd.cProd||') especifico!!! Nro Arquivo: '||R_Xml.Nuarquivo||' - Chave de Acesso: '||R_xml.chnfe||' - Tabela: AD_WSMICNFEPROD.';
                  
                  GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                         , P_MENSAGEM  => V_MENSAGEM);
                                         
                  ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null 
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = Null
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                  Return;
             
             End If;
                 
             v_ite.nunota       := v_cab.nunota;
             v_ite.codemp       := v_cab.codemp;
             v_ite.sequencia    := v_xmlnfeProd.nitem;
             v_ite.codprod      := v_xmlnfeProd.cProd;
             v_ite.qtdneg       := v_xmlnfeProd.qCom;
             v_ite.vlrunit      := v_xmlnfeProd.vUnCom;
             v_ite.vlrtot       := v_xmlnfeProd.vProd;
             v_ite.codcfo       := v_xmlnfeProd.CFOP;
             v_ite.usoprod      := v_pro.usoprod; 
            -- v_ite.codlocalorig := 14100000;
            
             v_ite.codlocalorig := AD_FNC_RET_LOCAL(v_ite.codprod, v_ite.codemp);
                        
             
             v_ite.codVol       := v_xmlnfeProd.UCom; 
             v_ite.atualestoque := Case When v_top.atualest = 'B' And v_top.adiaratualest = 'N' Then -1 When v_top.atualest = 'E' And v_top.adiaratualest = 'N' Then 1 Else 0 End;   
             v_ite.reserva      := Case When v_top.atualest = 'R' Then 'S' Else 'N' End;     
             v_ite.statusnota   := v_cab.statusnota; 
             v_ite.codbenefnauf := v_xmlnfeProd.CBenef; 
             v_ite.qtdvol       := 1;
             v_ite.origprod     := v_xmlnfeICM.orig;  
             v_ite.codtrib      := v_xmlnfeICM.CST;
             
             /*
             Alteração Glaycon
             Adicionar os dados dos impostos.
             */  
             v_ite.baseicms     := v_xmlnfeICM.vbc;    
             v_ite.aliqicms     := v_xmlnfeICM.picms;
             v_ite.vlricms      := v_xmlnfeICM.VICMSOP;
             
            /*Fim alteração*/
            
             v_ite.CODENQIPI    := v_xmlnfeIPI.cEnq;
             v_ite.CSTIPI       := (Case When v_top.tipmov = 'C' And v_xmlnfeIPI.CST > 49 Then v_xmlnfeIPI.CST - 50 Else v_xmlnfeIPI.CST End);    
                              
             ---Inserir a regra de lote
             -----Data de Fabricação
             -----Data de Validação =>>>>> SYSDATE + PRAZOVAL (do cadastro de Produto)
             -----Lote ( TGFITE>CONTROLE ) = Nro do DI  =>>>>> O LOTE dessas MP's = Número da DI da nota mãe, ou seja. Se teve 1.000 remessas, todas terão como lote o número da DI.
             v_ite.controle      := To_Char(v_xmlnfeDI.ndi);
                 
             ---Inserir itens
             v_ite               := pkg_cab.criarITE (v_ite);
                 
             ---Inserir impostos
             ---Alimentar dados a partir da tabela AD_WSMICNFEPIS
             ---Busca os dados do PIS
             Begin
                Select * Into v_xmlnfePIS
                  From ad_wsmicnfepis
                 Where chnfe = R_xml.chnfe;
             Exception
                When Others Then
                    v_xmlnfePIS := Null;
             End;
                 
             If v_xmlnfePIS.chnfe Is Not Null Then
                 v_din.nunota    := v_cab.nunota;
                 v_din.sequencia := v_xmlnfePIS.nitem;
                 v_din.codimp    := 6; ----PIS
                 v_din.CST       := v_xmlnfePIS.CST;
                 v_din.Base      := v_xmlnfePIS.vBC;
                 v_din.BaseRed   := v_xmlnfePIS.vBC;
                 v_din.aliquota  := v_xmlnfePIS.pPis;
                 v_din.valor     := v_xmlnfePIS.vPis;
                 
                 v_din.ad_flag   := 0;
                 v_din.ad_XML    := 'S';
                     
                 v_din           := pkg_cab.criarDIN (v_din); 
             End if;
                 
             ---Alimentar dados a partir da tabela AD_WSMICNFECOFINS
             ---Busca os dados do COFINS
             Begin
                Select * Into v_xmlnfeCOFINS
                  From ad_wsmicnfecofins
                 Where chnfe = R_xml.chnfe;
             Exception
                When Others Then
                    v_xmlnfeCOFINS := Null;
             End;
                 
             If v_xmlnfeCOFINS.chnfe Is Not Null Then

                 v_din.nunota    := v_cab.nunota;
                 v_din.sequencia := v_xmlnfeCOFINS.nitem;
                 v_din.codimp    := 7; ----COFINS
                 v_din.CST       := v_xmlnfeCOFINS.CST;
                 v_din.Base      := v_xmlnfeCOFINS.vBC;
                 v_din.BaseRed   := v_xmlnfeCOFINS.vBC;
                 v_din.aliquota  := v_xmlnfeCOFINS.pCOFINS;
                 v_din.valor     := v_xmlnfeCOFINS.vCOFINS;
                 
                 v_din.ad_flag   := 0;
                 v_din.ad_XML    := 'S';
                     
                 v_din           := pkg_cab.criarDIN (v_din);
                     
             End if;                                      

             ----Inserção da DI
             If v_xmlnfeDI.chnfe Is Not Null Then

                 -----Inserir na tabela TGFIII
                 v_iii.nunota          := v_cab.nunota;
                 v_iii.sequencia       := v_xmlnfeDI.nitem;
                 v_iii.baseimposto     := 0;
                 v_iii.vlrdespadua     := 0;
                 v_iii.vlrimposto      := 0;
                 v_iii.vlriof          := 0;             
                 v_iii.codusu          := 0;
                 v_iii.dhalter         := Sysdate;
                 v_iii.imptagexcnotnac := 'N';
                     
                 v_iii           := pkg_cab.criarIII (v_iii);
                     
                 -----Inserir na tabela Edit TGFIDI
                 v_idi.nunota         := v_cab.nunota;
                 v_idi.sequencia      := v_xmlnfeDI.nitem;
                 v_idi.seqdi          := 1; 
                 v_idi.nroDocumento   := v_xmlnfeDI.nDI;
                 v_idi.dtRegistro     := v_xmlnfeDI.dDI;             
                 v_idi.locDesembaraco := v_xmlnfeDI.xLocDesemb;
                 v_idi.codufdesemb    := pkg_cab.BuscarUF(Puf => v_xmlnfeDI.ufDesemb); ----Buscar a UF, trazer o codigo
                 v_idi.dtdesembaraco  := v_xmlnfeDI.dDesemb;
                 v_idi.viatransp      := lpad(v_xmlnfeDI.tpViaTransp, 2, '0') ;
                 v_idi.vlrafrmm       := v_xmlnfeDI.vaFrmm;
                 ---v_xmlnfeDI.tpIntermedio
                 v_idi.codexportador  := v_xmlnfeDI.cExportador;             
                 v_idi.codusu         := 0;
                 v_idi.dhalter        := Sysdate;
                 v_idi.tipprocimp     := (Case When v_xmlnfeDI.tpIntermedio = 1 Then 'C' When v_xmlnfeDI.tpIntermedio = 2 Then 'O' When v_xmlnfeDI.tpIntermedio = 3 Then 'E' Else 'C' End);
                 v_idi.cnpjadquirente := v_xmlnfe.emit_cnpj;
                 v_idi.ufadquirente   := v_xmlnfe.emit_UF;
                                  
    --             v_idi.docimp         := 
    --             v_idi.vlrpisimp      := ;
    --             v_idi.vlrcofinsimp   := 
    --             v_idi.numacdraw      := v_xmlnfeDI.cFabricante;
    --             v_idi.dtpagpis       := v_xmlnfeDI. ;
    --             v_idi.dtpagcofins    := v_xmlnfeDI.;
                     
                 v_idi := pkg_cab.criarIDI  ( v_idi );
                                                   
                 -----Inserir na tabela TGFIAD             
                 v_iad.nunota        := v_cab.nunota;
                 v_iad.sequencia     := v_xmlnfeDI.nitem;
                 v_iad.seqdi         := 1;
                 v_iad.seqad         := v_xmlnfeDI.nSeqAdic;    
                 v_iad.nroadicao     := v_xmlnfeDI.nAdicao;                  
                 v_iad.codfabricante := v_xmlnfeDI.cFabricante;
                 -- vip
                 --if v_xmlnfeDI.cFabricante is null
                 --and v_xmlnfeProd.cProd = 1210
                 --then v_iad.codfabricante := 16072;
                 --else v_iad.codfabricante := v_xmlnfeDI.cFabricante;
                 --end if;                  
                 v_iad.vlrdesc       := 0;
                 v_iad.codusu        := 0;
                 v_iad.dhalter       := Sysdate;
                     
                 v_iad := pkg_cab.criarIAD  ( v_iad ); 

             End if;   
             
            --             Stp_confirmanota2 (P_nunota   => v_cab.Nunota,
            --                                P_provisao => 'N',
            --                                P_recdesp  => -1);
             
--            If R_xml.chnfe = '43210787249561000107552030000578701058566453' Then
--             Commit;
--            End If; 
              
            Begin
              -----Vincular a nota fiscal com o pedido de Origem
              ---------Tem que ter o Nro Unico da Nota (v_cab.Nunota), ter o Pedido Origem (v_cab.AD_PEDRIGEM) e o flag Pedido Sem Origem = N 
              If Nvl(v_cab.Nunota,0) > 0 And Nvl(v_cab.AD_PEDRIGEM,0) > 0 And Nvl(P_SEMPEDORIG,'N') = 'N'  Then
                  
                    Begin
                        Select Count(*) Into P_Count 
                          From Tgfcab cab
                         Where cab.NUNOTA = Nvl(v_cab.AD_PEDRIGEM,0)
                           And cab.TipMov In ('O','P'); ---O - Pedido de Compra e/ou P - Pedido de Venda
                    Exception
                        When Others Then
                            P_Count := 0;
                    End;
                    
                    If P_Count > 0 Then
                        ----Vincular a Nota de Compra com o Pedido de Compra
                        P_Count := 0;
                         
                        For R_Ite In (Select itn.nunota, itn.sequencia, ito.nunota as nunotaorig, ito.sequencia as sequenciaorig, itn.qtdneg as qtdatendida, cab.statusnota 
                                        From Tgfite itn
                                       Inner Join Tgfcab cab
                                               On itn.nunota = cab.Nunota
                                       Inner Join Tgfite ito
                                               on ito.nunota = cab.AD_PEDRIGEM And
                                                  ito.codprod = itn.codprod        
                                       Where itn.nunota = v_cab.Nunota) 
                        Loop
                        
                            Select Count(*) Into P_Count 
                              From Tgfvar var                          
                             Where Var.Nunotaorig = R_Ite.nunotaorig 
                               And VAR.Nunota     = R_Ite.Nunota
                               And Var.Sequencia  = R_Ite.Sequencia;
                               
                            If P_Count = 0 Then
                                Insert into TGFVAR
                                (nunota, sequencia, nunotaorig, sequenciaorig, qtdatendida, statusnota)
                                Values
                                (R_Ite.Nunota, R_Ite.Sequencia, R_Ite.nunotaorig, R_Ite.sequenciaorig, R_Ite.qtdatendida, R_Ite.statusnota);    
                            Else
                                Update Tgfvar
                                   Set qtdatendida = qtdatendida + R_Ite.qtdatendida
                                 Where Nunotaorig = R_Ite.nunotaorig 
                                   And Nunota     = R_Ite.Nunota
                                   And Sequencia  = R_Ite.Sequencia;                           
                            End If;                        
                        
                        End Loop;                  
                            
                    End If;
                  
              End If;
            Exception
                When Others Then
                  Delete From Tgfcab
                        Where Nunota = v_cab.nunota;
                  
                  ERRMSG      := SQLERRM;
                  v_mensagem  := 'ERRO - Ao vincular com Pedido Origem ('||Nvl(v_cab.AD_PEDRIGEM,0)||') especifico!!! Nro Arquivo: '||R_Xml.Nuarquivo||' - Chave de Acesso: '||R_xml.chnfe||' - Tabela: AD_WSMICNFEPROD.'||'/'||ERRMSG;
                  
                  GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                         , P_MENSAGEM  => V_MENSAGEM);
                                         
                  ----Atualizar a origem do XML
                     Update ad_wsmicnfexml
                        Set Codemp       = Null
                          , Codparc      = Null  
                          , Nunota       = Null
                          , Numnota      = Null
                          , Status       = '-1' ---Erro
                          , NaturezaOper = v_xmlnfe.natOp
                          , NUNOTAORI    = v_cab.AD_PEDRIGEM 
                      Where chnfe = R_xml.chnfe
                        And Tipo  = R_xml.Tipo;
                  Return;
            End;  
              
              v_mensagem := 'Processo concluido com Sucesso!!! Nro Unico: '||v_cab.nunota||'.';
                    
              GERAR_PEDVDAXMLLOG_UNF ( P_NUARQUIVO => R_Xml.Nuarquivo
                                     , P_MENSAGEM  => V_MENSAGEM);
                                 
              ----Atualizar a origem do XML
              Update ad_wsmicnfexml
                 Set Codemp       = v_cab.codemp
                   , Codparc      = v_cab.codparc 
                   , Nunota       = v_cab.nunota
                   , Numnota      = v_cab.numnota
                   , Status       = '1' ---Processado
                   , NaturezaOper = v_xmlnfe.natOp
                   , NUNOTAORI    = v_cab.AD_PEDRIGEM 
               Where chnfe = R_xml.chnfe
                 And Tipo  = R_xml.Tipo;                                                                    
       
       End Loop;   
END;