create or replace package body pkg_cab as

  function BuscarEmpresa(Pcnpj Number) Return Int Is
    Vcodemp Int;
        
  Begin
        Begin
            Select Min(Codemp) Into Vcodemp
              From Tsiemp
             Where CGC = Pcnpj;
        Exception
            When Others Then
                Vcodemp := 1;
        End;
        
        Return Vcodemp;
  End BuscarEmpresa;
  
  function BuscarVariacaoFCP(pCodemp Int, pCodprod Number) Return Int Is
    V_VariacaoFCP Int;
        
    Begin
            If pCodemp In ( 1, 26 ) Then

                V_VariacaoFCP := 0;
                
                Begin
                    Select Fcp.Variacao
                      Into V_VariacaoFCP
                      From Tgffcp Fcp
                     Inner Join Tprplp Plp 
                             On Plp.Codemp = pCodemp And 
                               ( Nvl(Plp.Ad_prodterc, 'N') = 'N' )
                     Where Fcp.Ad_formlista = 'S'
                       And Fcp.Codprod   = pCodprod
                       And Plp.Codemp    = pCodemp
                       And Fcp.Ad_codplp = Plp.Codplp;
                Exception
                    When Others Then
                        V_VariacaoFCP := 0;
                End;  

            Else
                
                Begin
                    Select Fcp.Variacao 
                      Into V_variacaofcp
                      From Tgffcp Fcp
                     Inner Join Tprplp Plp 
                             On Plp.Codemp = pCodemp
                     Where Fcp.Ad_formlista = 'S'
                       And Fcp.Codprod   = pCodprod
                       And Plp.Codemp    = pCodemp
                       And Fcp.Ad_codplp = Plp.Codplp;
                Exception
                    When Others Then
                        V_VariacaoFCP := 0;
                End;

            End If;

            Return Nvl(V_VariacaoFCP,0);
    End BuscarVariacaoFCP;
  
  function BuscarParceiro(Pcnpj Number) Return Int Is
    Vcodparc Int;
        
  Begin
        Begin
            Select Max(Codparc) Into Vcodparc
              From Tgfpar
             Where CGC_CPF = Pcnpj;
        Exception
            When Others Then
                Vcodparc := 0;
        End;
        
        Return Vcodparc;
  End BuscarParceiro;
  
  function BuscarUF(Puf varchar2) Return Int Is
    Vuf Int;
        
  Begin
        Begin
            Select Min(Coduf) Into Vuf
              From Tsiufs
             Where UF = Puf;
        Exception
            When Others Then
                Vuf := 0;
        End;
        
        Return Vuf;
  End BuscarUF;
  
  function BuscarFrete( Pfrete Int ) Return varchar2 Is
    Vfrete varchar2(1);
        
  Begin
        Begin
        
           Select Case When Pfrete = 0 Then 'C'  ----Contratação do Frete por conta do Remetente (CIF)
                       When Pfrete = 1 Then 'F'  ----Contratação do Frete por conta do Destinatário (FOB)
                       When Pfrete = 2 Then 'T'  ----Contratação do Frete por conta de Terceiros
                       When Pfrete = 3 Then 'R'  ----Transporte Próprio por conta do Remetente
                       When Pfrete = 4 Then 'D'  ----Transporte Próprio por conta do Destinatário
                       When Pfrete = 9 Then 'S'  ----Sem Ocorrência de Transporte
                       Else  'S' End Into Vfrete ----Sem Frete
             From Dual;
        Exception
            When Others Then
                Vfrete := 'S';
        End;
        
        Return Vfrete;
  End BuscarFrete;  
  
  function Maxdhtipoper(Pcodtop Number) Return Date Is
        Vdata Date;
        Pragma Autonomous_Transaction;
  Begin
        Select Max(Dhalter)
            Into Vdata
            From Tgftop
         Where Codtipoper = Pcodtop;
        Return Vdata;
  End Maxdhtipoper;

  function Maxdhtipvenda(Pcodtipvenda Number) Return Date Is
        Vdata Date;
        Pragma Autonomous_Transaction;
  Begin
        Select Max(Dhalter)
            Into Vdata
            From Tgftpv
         Where Codtipvenda = Pcodtipvenda;
        Return Vdata;
  End Maxdhtipvenda; 
    
  function criar_com_modelo (
    p_nunotamodelo in number,
    p_codemp       in number default null,
    p_codparc      in number default null,
    p_codtipoper   in number default null,
    p_codtipvenda  in number default null,
    p_numcontrato  in number default null,
    p_codnat       in number default null,
    p_codcencus    in number default null,
    p_codproj      in number default null) return tgfcab%rowtype is

    v_cab tgfcab%rowtype;
    v_top tgftop%rowtype;
    
    P_nunota number;
    P_count  int;
    
    begin
      
      -- Identifica o registro modelo
      select * into v_cab 
        from tgfcab 
       where nunota = 4538; ---p_nunotamodelo;

      -- carrega os dados da top
      select t.* into v_top 
        from tgftop t 
       where t.codtipoper = nvl(p_codtipoper, v_cab.codtipoper) 
         and t.dhalter = (select max(dhalter) 
                            from tgftop 
                           where codtipoper = t.codtipoper);
      
      ----Pega o ultimo numero unico da TGFCAB
      Loop
            Stp_keygen_tgfnum(P_arquivo => 'TGFCAB', 
                              P_codemp  => 1, --v_cab.Codemp, 
                              P_tabela  => 'TGFCAB', 
                              P_campo   => 'NUNOTA', 
                              P_dsync   => 0, 
                              P_ultcod  => P_nunota);
                  
            Select Count(1)
              Into P_count
              From Tgfcab
             Where Nunota = P_nunota;
                  
            Exit When P_count = 0;
      End Loop;
      
      v_cab.nunota      := P_nunota;
      v_cab.codemp      := nvl(p_codemp, v_cab.codemp);
      v_cab.serienota   := null;
      v_cab.numnota     := 0; --numero(v_top.codtipoper, v_cab.codemp, null);
      v_cab.dtneg       := sysdate;
      v_cab.dtentsai    := sysdate;
      v_cab.codempnegoc := nvl(p_codemp, v_cab.codempnegoc);
      v_cab.codparc     := 18597; --nvl(p_codparc, v_cab.codparc);
      v_cab.codtipoper  := v_top.codtipoper;
      v_cab.dhtipoper   := Maxdhtipoper(Pcodtop => v_top.codtipoper);
      v_cab.tipmov      := v_top.tipmov;
      v_cab.pendente    := v_top.pendente;
      v_cab.codtipvenda := nvl(p_codtipvenda, v_cab.codtipvenda);
      v_cab.dhtipvenda  := Maxdhtipvenda(Pcodtipvenda => v_cab.codtipvenda);
      v_cab.numcontrato := nvl(p_numcontrato, v_cab.numcontrato);
      v_cab.codproj     := nvl(p_codproj, v_cab.codproj);
      v_cab.codcencus   := nvl(p_codcencus, v_cab.codcencus);
      v_cab.codnat      := nvl(p_codnat, v_cab.codnat);
      v_cab.dtalter     := sysdate;
      v_cab.notaporpedidopdv := 'N';
      
      insert into tgfcab values v_cab;

      -- Retorna o número da nova nota criada
      return v_cab;
    end;

  function criar (
    p_codemp      in number,
    p_codparc     in number,
    p_codtipoper  in number,
    p_codtipvenda in number,
    p_numcontrato in number default 0,
    p_codnat      in number default 0,
    p_codcencus   in number default 0,
    p_codproj     in number default 0) return tgfcab%rowtype is

    v_top tgftop%rowtype;
    v_cab tgfcab%rowtype;
    
    P_nunota number;
    P_count  int;
    
    begin
      -- carrega os dados da top
      select * into v_top 
        from tgftop 
       where codtipoper = p_codtipoper 
         and dhalter = (select max(dhalter) 
                          from tgftop 
                         where codtipoper = p_codtipoper);

      ----Pega o ultimo numero unico da TGFCAB
      Loop
            Stp_keygen_tgfnum(P_arquivo => 'TGFCAB', 
                              P_codemp  => 1, --p_codemp, 
                              P_tabela  => 'TGFCAB', 
                              P_campo   => 'NUNOTA', 
                              P_dsync   => 0, 
                              P_ultcod  => P_nunota);
                  
            Select Count(1)
              Into P_count
              From Tgfcab
             Where Nunota = P_nunota;
                  
            Exit When P_count = 0;
      End Loop;
      
      v_cab.nunota                := P_nunota;
      v_cab.tipmov                := v_top.tipmov;
      v_cab.codemp                := p_codemp;
      v_cab.serienota             := null;
      v_cab.numnota               := numero(p_codtipoper, p_codemp, null);
      v_cab.dtneg                 := sysdate;
      v_cab.dtentsai              := sysdate;
      v_cab.codempnegoc           := p_codemp;
      v_cab.codparc               := p_codparc;
      v_cab.codtipoper            := v_top.codtipoper;
      v_cab.dhtipoper             := Maxdhtipoper(Pcodtop => v_top.codtipoper);
      v_cab.tipmov                := v_top.tipmov;
      v_cab.pendente              := v_top.pendente;
      v_cab.codtipvenda           := p_codtipvenda;
      v_cab.dhtipvenda            := Maxdhtipvenda(Pcodtipvenda => v_cab.codtipvenda);
      v_cab.numcontrato           := p_numcontrato;
      v_cab.codproj               := p_codproj;
      v_cab.codcencus             := p_codcencus;
      v_cab.codnat                := p_codnat;
      v_cab.rateado               := 'N';
      v_cab.codveiculo            := 0;
      v_cab.codvend               := 0;
      v_cab.comissao              := 0;
      v_cab.codmoeda              := 0;
      v_cab.codobspadrao          := 0;
      v_cab.vlrseg                := 0;
      v_cab.vlricmsseg            := 0;
      v_cab.vlrdestaque           := 0;
      v_cab.vlrjuro               := 0;
      v_cab.vlrvendor             := 0;
      v_cab.vlroutros             := 0;
      v_cab.vlremb                := 0;
      v_cab.vlricmsemb            := 0;
      v_cab.vlrdescserv           := 0;
      v_cab.ipiemb                := 0;
      v_cab.tipipiemb             := 'N';
      v_cab.vlrdesctot            := 0;
      v_cab.vlrdesctotitem        := 0;
      v_cab.vlrfrete              := 0;
      v_cab.icmsfrete             := 0;
      v_cab.baseicmsfrete         := 0;
      v_cab.tipfrete              := 'N';
      v_cab.vlrnota               := 0;
      v_cab.codparctransp         := 0;
      v_cab.qtdvol                := 1;
      v_cab.pendente              := 'S';
      v_cab.baseicms              := 0;
      v_cab.vlricms               := 0;
      v_cab.baseipi               := 0;
      v_cab.vlripi                := 0;
      v_cab.issretido             := 'N';
      v_cab.baseiss               := 0;
      v_cab.vlriss                := 0;
      v_cab.aprovado              := 'N';
      v_cab.statusnota            := 'A';
      v_cab.irfretido             := 'S';
      v_cab.vlrirf                := 0;
      v_cab.dtalter               := sysdate;
      v_cab.codparcdest           := 0;
      v_cab.vlrsubst              := 0;
      v_cab.basesubstit           := 0;
      v_cab.baseinss              := 0;
      v_cab.vlrinss               := 0;
      v_cab.vlrrepredtot          := 0;
      v_cab.percdesc              := 0;
      v_cab.codparcremetente      := 0;
      v_cab.codparcconsignatario  := 0;
      v_cab.codparcredespacho     := 0;
      v_cab.troco                 := 0;
      v_cab.codusucomprador       := 0;
      v_cab.vlrtotliqitemmoe      := 0;
      v_cab.vlrdesctotitemmoe     := 0;
      v_cab.notaporpedidopdv      := 'N';
      
      insert into tgfcab values v_cab;

      -- Retorna o número da nova nota criada
      return v_cab;
    end;

function criarCAB (v_cab tgfcab%rowtype) 
    return tgfcab%rowtype is

    v_top tgftop%rowtype;
    v_cab2 tgfcab%rowtype;
    
    P_nunota number;
    P_count  int;
    
    begin
          -- carrega os dados da top
          select * into v_top 
            from tgftop 
           where codtipoper = v_cab.codtipoper 
             and dhalter = (select max(dhalter) 
                              from tgftop 
                             where codtipoper = v_cab.codtipoper);

          ----Pega o ultimo numero unico da TGFCAB
          Loop
                Stp_keygen_tgfnum(P_arquivo => 'TGFCAB', 
                                  P_codemp  => 1, ---v_cab.codemp, 
                                  P_tabela  => 'TGFCAB', 
                                  P_campo   => 'NUNOTA', 
                                  P_dsync   => 0, 
                                  P_ultcod  => P_nunota);
                      
                Select Count(1)
                  Into P_count
                  From Tgfcab
                 Where Nunota = P_nunota;
                      
                Exit When P_count = 0;
          End Loop;

      v_cab2.nunota                := P_nunota;
      v_cab2.chavenfe              := V_cab.chavenfe;
      v_cab2.chavenferef           := V_cab.chavenferef;
      v_cab2.codemp                := V_cab.codemp;
      v_cab2.serienota             := V_cab.serienota;
      v_cab2.numnota               := V_cab.numnota; ---numero(p_codtipoper, p_codemp, null);
      v_cab2.dtneg                 := Trunc(Nvl(V_cab.dtneg,Sysdate));
      v_cab2.dtentsai              := Trunc(Nvl(V_cab.dtentsai,Sysdate));
      v_cab2.Hrentsai              := Nvl(V_cab.Hrentsai,Sysdate);
      v_cab2.dtfatur               := Trunc(Nvl(V_cab.dtfatur, V_cab2.dtneg));
      v_cab2.dtmov                 := Trunc(Sysdate);
      v_cab2.codempnegoc           := V_cab.codemp;
      v_cab2.codparc               := V_cab.codparc;
      v_cab2.codtipoper            := Nvl(v_top.codtipoper, V_cab.codtipoper);
      v_cab2.dhtipoper             := Nvl(v_top.dhalter, Maxdhtipoper(Pcodtop => V_cab.codtipoper));
      v_cab2.tipmov                := Nvl(v_top.tipmov, V_cab.tipmov);
      v_cab2.pendente              := V_cab.pendente;
      v_cab2.codtipvenda           := V_cab.codtipvenda;
      v_cab2.dhtipvenda            := Maxdhtipvenda(Pcodtipvenda => V_cab.codtipvenda);
      v_cab2.numcontrato           := V_cab.numcontrato;
      v_cab2.codproj               := V_cab.codproj;
      v_cab2.codcencus             := V_cab.codcencus;
      v_cab2.codnat                := V_cab.codnat;
      v_cab2.rateado               := Nvl(V_cab.rateado,'N');
      v_cab2.codveiculo            := Nvl(V_cab.codveiculo, 0);
      v_cab2.codvend               := Nvl(V_cab.codvend, 0);
      v_cab2.comissao              := Nvl(V_cab.comissao, 0);
      v_cab2.codmoeda              := Nvl(V_cab.codmoeda, 0);
      v_cab2.codobspadrao          := Nvl(V_cab.codobspadrao, 0);
      v_cab2.vlrseg                := Nvl(V_cab.vlrseg, 0);
      v_cab2.vlricmsseg            := Nvl(V_cab.vlricmsseg, 0);
      v_cab2.vlrdestaque           := Nvl(V_cab.vlrdestaque, 0);
      v_cab2.vlrjuro               := Nvl(V_cab.vlrjuro, 0);
      v_cab2.vlrvendor             := Nvl(V_cab.vlrvendor, 0);
      v_cab2.vlroutros             := Nvl(V_cab.vlroutros, 0);
      v_cab2.vlremb                := Nvl(V_cab.vlremb, 0);
      v_cab2.vlricmsemb            := Nvl(V_cab.vlricmsemb, 0);
      v_cab2.vlrdescserv           := Nvl(V_cab.vlrdescserv, 0);
      v_cab2.ipiemb                := Nvl(V_cab.ipiemb, 0);
      v_cab2.tipipiemb             := Nvl(V_cab.tipipiemb, 'N');
      v_cab2.vlrdesctot            := Nvl(V_cab.vlrdesctot, 0);
      v_cab2.vlrdesctotitem        := Nvl(V_cab.vlrdesctotitem, 0);
      v_cab2.vlrfrete              := Nvl(V_cab.vlrfrete, 0);
      v_cab2.icmsfrete             := Nvl(V_cab.icmsfrete, 0);
      v_cab2.baseicmsfrete         := Nvl(V_cab.baseicmsfrete, 0);
      v_cab2.tipfrete              := Nvl(V_cab.tipfrete, 'N');
      v_cab2.cif_fob               := Nvl(V_cab.cif_fob, 'F');
      v_cab2.vlrnota               := Nvl(V_cab.vlrnota, 0);
      v_cab2.codparctransp         := Nvl(V_cab.codparctransp, 0);
      v_cab2.qtdvol                := Nvl(V_cab.qtdvol, 1);
      v_cab2.volume                := Nvl(V_cab.volume, '');  
      v_cab2.pendente              := Nvl(V_cab.pendente, 'S');
      v_cab2.baseicms              := Nvl(V_cab.baseicms, 0);
      v_cab2.vlricms               := Nvl(V_cab.vlricms, 0);
      v_cab2.baseipi               := Nvl(V_cab.baseipi, 0);
      v_cab2.vlripi                := Nvl(V_cab.vlripi, 0);
      v_cab2.issretido             := Nvl(V_cab.issretido, 'N');
      v_cab2.baseiss               := Nvl(V_cab.baseiss, 0);
      v_cab2.vlriss                := Nvl(V_cab.vlriss, 0);
      v_cab2.aprovado              := Nvl(V_cab.aprovado, 'N');
      v_cab2.statusnota            := Nvl(V_cab.statusnota, 'A');
      v_cab2.irfretido             := Nvl(V_cab.irfretido, 'S');
      v_cab2.vlrirf                := Nvl(V_cab.vlrirf, 0);
      v_cab2.dtalter               := sysdate;
      v_cab2.codparcdest           := Nvl(V_cab.codparcdest, 0);
      v_cab2.vlrsubst              := Nvl(V_cab.vlrsubst, 0);
      v_cab2.basesubstit           := Nvl(V_cab.basesubstit, 0);
      v_cab2.baseinss              := Nvl(V_cab.baseinss, 0);
      v_cab2.vlrinss               := Nvl(V_cab.vlrinss, 0);
      v_cab2.vlrrepredtot          := Nvl(V_cab.vlrrepredtot, 0);
      v_cab2.percdesc              := Nvl(V_cab.percdesc, 0);
      v_cab2.codparcremetente      := Nvl(V_cab.codparcremetente, 0);
      v_cab2.codparcconsignatario  := Nvl(V_cab.codparcconsignatario, 0);
      v_cab2.codparcredespacho     := Nvl(V_cab.codparcredespacho, 0);
      v_cab2.troco                 := Nvl(V_cab.troco, 0);
      v_cab2.codusucomprador       := Nvl(V_cab.codusucomprador, 0);
      v_cab2.vlrtotliqitemmoe      := Nvl(V_cab.vlrtotliqitemmoe, 0);
      v_cab2.vlrdesctotitemmoe     := Nvl(V_cab.vlrdesctotitemmoe, 0);
      v_cab2.codusu                := Nvl(V_cab.codusu, 0);      
      v_cab2.peso                  := v_cab.peso;
      v_cab2.pesobruto             := v_cab.pesobruto;
      v_cab2.observacao            := v_cab.observacao;
      v_cab2.notaporpedidopdv      := Nvl(v_cab.NOTAPORPEDIDOPDV,'N');
      
      v_cab2.Numaleatorio          := v_cab.Numaleatorio;
      v_cab2.Numprotoc             := v_cab.Numprotoc;
      v_cab2.DhProtoc              := v_cab.DhProtoc;
      v_cab2.NuloteNFE             := v_cab.NuloteNFE;
      v_cab2.StatusNFE             := v_cab.StatusNFE;
      v_cab2.TpemisNFE             := v_cab.TpemisNFE;
             
      v_cab2.Codcidorigem          := v_cab.Codcidorigem;
      v_cab2.Codciddestino         := v_cab.Codciddestino;
      v_cab2.Codcidentrega         := v_cab.Codcidentrega;
      v_cab2.Coduforigem           := v_cab.Coduforigem;
      v_cab2.Codufdestino          := v_cab.Codufdestino;
      v_cab2.Codufentrega          := v_cab.Codufentrega;
      v_cab2.Classificms           := Nvl(v_cab.Classificms,'R');
      
      v_cab2.tpambnfe              := v_cab.tpambnfe; 
      v_cab2.placa                 := v_cab.placa;
      v_cab2.ufveiculo             := v_cab.ufveiculo;
      
      ---Informações Adicionais
      v_cab2.AD_NROIMPORT          := v_cab.AD_NROIMPORT;
      v_cab2.AD_PEDRIGEM           := v_cab.AD_PEDRIGEM;
      v_cab2.IDNAVIO               := v_cab.IDNAVIO;
      
      insert into tgfcab values v_cab2;
      
      -- Retorna o número da nova nota criada
      return v_cab2;
    end;
    
  function adicionar (
    p_nunota   in number,
    p_codprod  in number,
    p_qtdneg   in number,
    p_vlrunit  in number default null,
    p_codlocal in number default null,
    p_vlrcus   in number default null,
    p_baseicms in number default null,
    p_vlricms  in number default null,
    p_baseiss  in number default null,
    p_vlriss   in number default null) return tgfite%rowtype is

    v_cab tgfcab%rowtype;
    v_top tgftop%rowtype;
    v_pro tgfpro%rowtype;
    v_ite tgfite%rowtype;
    
    v_sequencia number;
    
    begin
      -- Identifica a nota
      select * into v_cab 
        from tgfcab 
       where nunota = p_nunota;

      -- Identifica a top
      select * into v_top 
        from tgftop 
       where codtipoper = v_cab.codtipoper 
         and dhalter = v_cab.dhtipoper;

      -- Identifica o produto
      select * into v_pro 
        from tgfpro 
       where codprod = p_codprod;

      -- Identifica a sequencia do item na nota
      select nvl(max(sequencia), 0) + 1 into v_sequencia 
        from tgfite 
       where nunota = v_cab.nunota;

      --Preenche os dados do item
      v_ite.nunota       := v_cab.nunota;
      v_ite.numcontrato  := v_cab.numcontrato;
      v_ite.sequencia    := v_sequencia;
      v_ite.codemp       := v_cab.codemp;
      v_ite.codprod      := v_pro.codprod;
      v_ite.usoprod      := v_pro.usoprod;
      v_ite.codlocalorig := nvl(p_codlocal, 0);
      v_ite.codvol       := v_pro.codvol;
      v_ite.pendente     := v_cab.pendente;
      v_ite.statusnota   := v_cab.statusnota;

      v_ite.qtdneg       := p_qtdneg;
      v_ite.vlrunit      := nvl(p_vlrunit, preco(v_pro.codprod, v_cab.codemp, null));
      v_ite.vlrtot       := nvl(v_ite.vlrunit * v_ite.qtdneg, 0);
      v_ite.vlrcus       := nvl(p_vlrcus, 0);
      v_ite.baseicms     := nvl(p_baseicms, 0);
      v_ite.vlricms      := nvl(p_vlricms, 0);
      v_ite.baseiss      := nvl(p_baseiss, 0);
      v_ite.vlriss       := nvl(p_vlriss, 0);

      v_ite.percdesc     := 0;
      v_ite.vlrdesc      := 0;
      v_ite.controle     := 1; ---' ';
      v_ite.codcfo       := 0;
      v_ite.qtdentregue  := 0;
      v_ite.qtdconferida := 0;
      v_ite.baseipi      := 0;
      v_ite.vlripi       := 0;
      v_ite.basesubstit  := 0;
      v_ite.vlrsubst     := 0;
      v_ite.atualestoque := case when v_top.atualest = 'B' then -1 when v_top.atualest = 'E' then 1 else 0 end;
      v_ite.reserva      := case when v_top.atualest = 'R' then 'S' else 'N' end;
      v_ite.codvend      := 0;
      v_ite.codexec      := 0;
      v_ite.faturar      := 0;
      v_ite.vlrrepred    := 0;
      v_ite.vlrdescbonif := 0;
      v_ite.vlrunitmoe   := 0;
      v_ite.vlrdescmoe   := 0;
      v_ite.vlrtotmoe    := 0;
      v_ite.geraproducao := 'N';

      -- Insere o item no pedido
      insert into tgfite values v_ite;

      -- Atualiza o valor total do pedido
      update tgfcab
         set (vlrnota, baseicms, vlricms, baseiss, vlriss) = (select sum(vlrtot), sum(baseicms), sum(vlricms), sum(baseiss), sum(vlriss) from tgfite where nunota = v_cab.nunota)
       where nunota = v_cab.nunota;

      return v_ite;
    end;
    
  function criarITE (v_ite tgfite%rowtype) 
     return tgfite%rowtype is

    v_cab  tgfcab%rowtype;
    v_top  tgftop%rowtype;
    v_pro  tgfpro%rowtype;
    v_ite2 tgfite%rowtype;
    
    v_sequencia number;
    
    begin

      --Preenche os dados do item
      v_ite2.nunota       := v_ite.nunota;
      v_ite2.numcontrato  := v_ite.numcontrato;
      v_ite2.sequencia    := v_ite.sequencia;
      v_ite2.codemp       := v_ite.codemp;
      v_ite2.codprod      := v_ite.codprod;
      v_ite2.usoprod      := v_ite.usoprod;
      v_ite2.controle     := Nvl(v_ite.controle, 1); ---' ';
      v_ite2.codlocalorig := v_ite.codlocalorig; ---  nvl(p_codlocal, 0);
      v_ite2.codvol       := v_ite.codvol;
      v_ite2.pendente     := v_ite.pendente;
      v_ite2.statusnota   := v_ite.statusnota;
      v_ite2.qtdneg       := v_ite.qtdneg;
      v_ite2.vlrunit      := Nvl(v_ite.vlrunit,0); ---nvl(p_vlrunit, preco(v_pro.codprod, v_cab.codemp, null));
      v_ite2.vlrtot       := Nvl(v_ite.vlrtot,0); ---nvl(v_ite.vlrunit * v_ite.qtdneg, 0);
      v_ite2.vlrcus       := Nvl(v_ite.vlrcus,0); ---nvl(p_vlrcus, 0);
      v_ite2.baseicms     := Nvl(v_ite.baseicms,0); ---nvl(p_baseicms, 0);
      v_ite2.vlricms      := Nvl(v_ite.vlricms,0); ---nvl(p_vlricms, 0);
      /*
      Atualização para pegar a aliqicms de acordo com a tabela MIC de ICMS
      Glaycon 09/06/2023
      */
      v_ite2.aliqicms     := Nvl(v_ite.aliqicms,0); 
      /*Fim alteração*/
      v_ite2.baseiss      := Nvl(v_ite.baseiss,0); ---nvl(p_baseiss, 0);
      v_ite2.vlriss       := Nvl(v_ite.vlriss,0); ---- nvl(p_vlriss, 0);
      v_ite2.percdesc     := Nvl(v_ite.percdesc, 0);
      v_ite2.vlrdesc      := Nvl(v_ite.vlrdesc, 0);
      v_ite2.codcfo       := Nvl(v_ite.codcfo, 0);
      v_ite2.qtdentregue  := Nvl(v_ite.qtdentregue, 0);
      v_ite2.qtdconferida := Nvl(v_ite.qtdconferida, 0);
      v_ite2.baseipi      := Nvl(v_ite.baseipi, 0);
      v_ite2.vlripi       := Nvl(v_ite.vlripi, 0);
      v_ite2.basesubstit  := Nvl(v_ite.basesubstit, 0);
      v_ite2.vlrsubst     := Nvl(v_ite.vlrsubst, 0);
      v_ite2.atualestoque := Nvl(v_ite.atualestoque, 0); ---case when v_top.atualest = 'B' then -1 when v_top.atualest = 'E' then 1 else 0 end;
      v_ite2.reserva      := Nvl(v_ite.reserva, 0); ---case when v_top.atualest = 'R' then 'S' else 'N' end;
      v_ite2.codvend      := Nvl(v_ite.codvend, 0);
      v_ite2.codexec      := Nvl(v_ite.codexec, 0);
      v_ite2.faturar      := Nvl(v_ite.faturar, 0);
      v_ite2.vlrrepred    := Nvl(v_ite.vlrrepred, 0);
      v_ite2.vlrdescbonif := Nvl(v_ite.vlrdescbonif, 0);
      v_ite2.vlrunitmoe   := Nvl(v_ite.vlrunitmoe, 0);
      v_ite2.vlrdescmoe   := Nvl(v_ite.vlrdescmoe, 0);
      v_ite2.vlrtotmoe    := Nvl(v_ite.vlrtotmoe, 0);
      v_ite2.geraproducao := Nvl(v_ite.geraproducao, 'N');
      v_ite2.codbenefnauf := v_ite.codbenefnauf;
      v_ite2.CODENQIPI    := v_ite.CODENQIPI;
      v_ite2.CSTIPI       := v_ite.CSTIPI;
      v_ite2.origprod     := v_ite.origprod;
      v_ite2.codtrib      := v_ite.codtrib;
      v_ite2.codusu       := Nvl(v_ite.codusu,0);
      v_ite2.dtalter      := Nvl(v_ite.dtalter,sysdate);
      v_ite2.solcompra    := Nvl(v_ite.solcompra,'N');
      v_ite2.atualestterc := Nvl(v_ite.atualestterc,'N');
      v_ite2.terceiros    := Nvl(v_ite.terceiros,'N');
      v_ite2.qtdvol       := Nvl(v_ite.qtdvol,0);
      v_ite2.faturar      := Nvl(v_ite.faturar,'N');
      v_ite2.statuslote   := Nvl(v_ite.statuslote,'N');
      v_ite2.geraproducao := Nvl(v_ite.geraproducao,'N');
      v_ite2.qtdwms       := Nvl(v_ite.qtdwms,0);
      
      -- Insere o item no pedido
      insert into tgfite values v_ite2;

      -- Atualiza o valor total do pedido
      update tgfcab
         set (vlrnota, baseicms, vlricms, baseiss, vlriss) = (select sum(vlrtot), sum(baseicms), sum(vlricms), sum(baseiss), sum(vlriss) from tgfite where nunota = v_ite2.nunota)
       where nunota = v_ite2.nunota;

      return v_ite2;
    end;  
    
  function criarDIN (v_din tgfdin%rowtype) 
     return tgfdin%rowtype is

    v_din2 tgfdin%rowtype;
    
---    v_sequencia number;
    
    begin

      --Preenche os dados do item
      v_din2.nunota           := v_din.nunota;
      v_din2.sequencia        := v_din.sequencia;
      v_din2.codimp           := v_din.codimp;
      v_din2.codinc           := Nvl(v_din.codinc,0);
      v_din2.base             := Nvl(v_din.base,0);
      v_din2.basered          := Nvl(v_din.basered,0);
      v_din2.vlrrepred        := Nvl(v_din.vlrrepred,0);
      v_din2.pauta            := Nvl(v_din.pauta,0); 
      v_din2.aliquota         := Nvl(v_din.aliquota,0); 
      v_din2.valor            := Nvl(v_din.valor,0); 
      v_din2.tipo             := Nvl(v_din.tipo,0);
      v_din2.vlrcred          := Nvl(v_din.vlrcred,0);
      v_din2.cst              := v_din.cst; 
      v_din2.retemfin         := Nvl(v_din.retemfin,'N'); 
      v_din2.percvlr          := Nvl(v_din.percvlr,'P'); 
      v_din2.comiva           := Nvl(v_din.comiva,'N');
      v_din2.iva              := Nvl(v_din.iva,0); 
      v_din2.codusu           := Nvl(v_din.codusu,0); 
      v_din2.dhalter          := Nvl(v_din.dhalter,Sysdate); 
      v_din2.digitado         := Nvl(v_din.digitado,'N'); 
      v_din2.percredbase      := Nvl(v_din.percredbase,0);
      v_din2.aliquotanormal   := Nvl(v_din.aliquotanormal,0);
      v_din2.aliqintdest      := Nvl(v_din.aliqintdest,0);
      v_din2.percpartdifal    := Nvl(v_din.percpartdifal,0);
      v_din2.vlrdifaldest     := Nvl(v_din.vlrdifaldest,0); 
      v_din2.vlrdifalrem      := Nvl(v_din.vlrdifalrem,0); 
      v_din2.percfcp          := Nvl(v_din.percfcp,0);
      v_din2.vlrfcp           := Nvl(v_din.vlrfcp,0);
      v_din2.tipcalcdifal     := Nvl(v_din.tipcalcdifal,0);
      v_din2.basedifal        := Nvl(v_din.basedifal,0); 
      v_din2.basefcp          := Nvl(v_din.basefcp,0);
      v_din2.basefcpint       := Nvl(v_din.basefcpint,0); 
      v_din2.percfcpint       := Nvl(v_din.percfcpint,0);
      v_din2.vlrfcpint        := Nvl(v_din.vlrfcpint,0);
      v_din2.aliqparadifal    := Nvl(v_din.aliqparadifal,0); 
      v_din2.vlricmsparadifal := Nvl(v_din.vlricmsparadifal,0); 
      v_din2.percinssespecial := Nvl(v_din.percinssespecial,0); 
      v_din2.vlrinssespecial  := Nvl(v_din.vlrinssespecial,0);
      v_din2.vlrrepdifalfcp   := Nvl(v_din.vlrrepdifalfcp,0);
      v_din2.percredbaseefet  := Nvl(v_din.percredbaseefet,0); 
      v_din2.aliquotaefet     := Nvl(v_din.aliquotaefet,0);
      v_din2.baseredefet      := Nvl(v_din.baseredefet,0);
      v_din2.valorefet        := Nvl(v_din.valorefet,0); 
      v_din2.vlrrepredsemdesc := Nvl(v_din.vlrrepredsemdesc,0); 
      v_din2.basenormdificms  := Nvl(v_din.basenormdificms,0); 
      v_din2.aliqdespacess    := Nvl(v_din.aliqdespacess,0); 
      v_din2.percredvlripi    := Nvl(v_din.percredvlripi,0);
            
      v_din2.ad_flag          := Nvl(v_din.ad_flag,0);
      v_din2.ad_XML           := Nvl(v_din.ad_XML,'N');
      
      -- Insere o itens dos impostos
      insert into tgfdin values v_din2;

      return v_din2;
    end; 
    
    function criarIII (v_iii tgfiii%rowtype) 
     return tgfiii%rowtype is

    v_iii2 tgfiii%rowtype;
    
    begin

      --Preenche os dados do item
      v_iii2.nunota          := v_iii.nunota;
      v_iii2.sequencia       := v_iii.sequencia;
      v_iii2.baseimposto     := v_iii.baseimposto;
      v_iii2.vlrdespadua     := v_iii.vlrdespadua;
      v_iii2.vlrimposto      := v_iii.vlrimposto;
      v_iii2.vlriof          := v_iii.vlriof;      
      v_iii2.codusu          := Nvl(v_iii.codusu,0);
      v_iii2.dhalter         := Nvl(v_iii.dhalter,Sysdate);
      v_iii2.imptagexcnotnac := v_iii.imptagexcnotnac;
      
      -- Insere o itens da DI
      insert into tgfiii values v_iii2;
      
      return v_iii2;
    end;      
    
  function criarIDI (v_idi tgfidi%rowtype) 
     return tgfidi%rowtype is

    v_idi2 tgfidi%rowtype;
    
    begin

      --Preenche os dados do item
      v_idi2.nunota          := v_idi.nunota;
      v_idi2.sequencia       := v_idi.sequencia;
      v_idi2.seqDI           := v_idi.seqDI;
      v_idi2.nrodocumento    := v_idi.nrodocumento;
      v_idi2.dtregistro      := v_idi.dtregistro;
      v_idi2.locdesembaraco  := v_idi.locdesembaraco;
      v_idi2.codufdesemb     := v_idi.codufdesemb;
      v_idi2.dtdesembaraco   := v_idi.dtdesembaraco;
      v_idi2.codexportador   := v_idi.codexportador;
      v_idi2.codusu          := Nvl(v_idi.codusu,0);
      v_idi2.dhalter         := Nvl(v_idi.dhalter,Sysdate);
      v_idi2.docimp          := Nvl(v_idi.docimp,0);
      v_idi2.vlrpisimp       := Nvl(v_idi.vlrpisimp,0);
      v_idi2.vlrcofinsimp    := Nvl(v_idi.vlrcofinsimp,0);
      v_idi2.numacdraw       := v_idi.numacdraw;
      v_idi2.dtpagpis        := v_idi.dtpagpis;
      v_idi2.dtpagcofins     := v_idi.dtpagcofins;
      v_idi2.viatransp       := v_idi.viatransp;
      v_idi2.tipprocimp      := v_idi.tipprocimp;
      v_idi2.cnpjadquirente  := v_idi.cnpjadquirente;
      v_idi2.ufadquirente    := v_idi.ufadquirente;
      v_idi2.vlrafrmm        := v_idi.vlrafrmm;
      
      -- Insere o itens da DI
      insert into tgfidi values v_idi2;
      
      return v_idi2;
    end;   
    
    function criarIAD (v_iad tgfiad%rowtype) 
     return tgfiad%rowtype is

    v_iad2 tgfiad%rowtype;
    
    begin

      --Preenche os dados do item
      v_iad2.nunota          := v_iad.nunota;
      v_iad2.sequencia       := v_iad.sequencia;
      v_iad2.seqDI           := v_iad.seqDI;
      v_iad2.seqAD           := v_iad.seqAD;
      v_iad2.nroadicao       := v_iad.nroadicao;
      v_iad2.codfabricante   := v_iad.codfabricante;      
      v_iad2.vlrdesc         := v_iad.vlrdesc;
      v_iad2.codusu          := Nvl(v_iad.codusu,0);
      v_iad2.dhalter         := Nvl(v_iad.dhalter,Sysdate);
      
      -- Insere o itens da DI
      insert into tgfiad values v_iad2;
      
      return v_iad2;
    end;       

  function identificar (
    p_nunota   in number,
    p_codprod  in number) return tgfite%rowtype is

    v_ite tgfite%rowtype;
    begin
      select * into v_ite 
        from tgfite 
       where nunota = p_nunota 
         and codprod = p_codprod;
         
      return v_ite;
    exception
      when no_data_found then
        return null;
    end;

  function alterar (
    p_nunota   in number,
    p_codprod  in number,
    p_qtdneg   in number,
    p_vlrunit  in number default null,
    p_codlocal in number default null,
    p_vlrcus   in number default null,
    p_baseicms in number default null,
    p_vlricms  in number default null,
    p_baseiss  in number default null,
    p_vlriss   in number default null) return tgfite%rowtype is

    v_ite tgfite%rowtype;
    begin

      -- identifica o item
      v_ite := identificar(p_nunota, p_codprod);
      ---pkg_erro.testar(v_ite.nunota is null, 'Operação não realizada', 'O produto informado não pertence a nota.');

      --Preenche os dados do item
      v_ite.codlocalorig := nvl(p_codlocal, 0);

      v_ite.qtdneg       := v_ite.qtdneg + p_qtdneg;
      v_ite.vlrunit      := nvl(p_vlrunit, preco(v_ite.codprod, v_ite.codemp, null));
      v_ite.vlrtot       := nvl(v_ite.vlrunit * v_ite.qtdneg, 0);
      v_ite.vlrcus       := nvl(p_vlrcus, 0);
      v_ite.baseicms     := nvl(p_baseicms, 0);
      v_ite.vlricms      := nvl(p_vlricms, 0);
      v_ite.baseiss      := nvl(p_baseiss, 0);
      v_ite.vlriss       := nvl(p_vlriss, 0);

      -- Insere o item no pedido
      update tgfite 
         set row = v_ite 
       where nunota = v_ite.nunota 
         and sequencia = v_ite.sequencia;

      -- Atualiza o valor total do pedido
      update tgfcab
         set (vlrnota, baseicms, vlricms, baseiss, vlriss) = (select sum(vlrtot), sum(baseicms), sum(vlricms), sum(baseiss), sum(vlriss) from tgfite where nunota = v_ite.nunota)
      where nunota = v_ite.nunota;

      return v_ite;
    end;

  -- Identifica o preco de um produto pela empresa ou pela tabela de preçco
  function preco (
    p_codprod  in number,
    p_codemp   in number,
    p_codtab   in number,
    p_codlocal in number default null,
    p_controle in varchar2 default null) return number is

    v_preco  number;
    v_codtab number := p_codtab;
    v_nutab  number;
    
    begin
      if v_codtab is null then
        select nvl(codtabcalc, 0) into v_codtab 
          from tgfemp 
         where codemp = p_codemp;
      end if;
      select nvl(max(nutab), 0) into v_nutab from tgftab where codtab = v_codtab and dtvigor = (select max(dtvigor) from tgftab where codtab = v_codtab and dtvigor <= sysdate);

      stp_obtem_preco3(v_nutab, p_codprod, p_codlocal, p_controle, sysdate, v_preco);

      return v_preco;
    end;

  function numero(
    p_codtipoper in number,
    p_codemp     in number,
    p_serie      in varchar2) return number is

    v_top    tgftop%rowtype;
    v_ultcod number;
    begin
      -- Identifica a top utilizada.
      select * into v_top 
        from tgftop 
       where codtipoper = p_codtipoper 
         and dhalter = (select max(dhalter) 
                          from tgftop 
                         where codtipoper = p_codtipoper);

      -- Atualiza o valor do ultcod
      update tgfnum 
         set ultcod = ultcod + 1
       where arquivo = decode(v_top.basenumeracao, 'V', 'VENDA', 'T', 'TOP-' || v_top.codtipoper, 'P', 'PEDVEN', 'O', 'PEDCOM', 'L', 'LOTEPRODUC', '----')
         and codemp = decode(v_top.tiponumeracao, 'F', p_codemp, 'S', p_codemp, 'U', 1)
         and trim(nvl(serie, ' ') || '.') = decode(v_top.tiponumeracao, 'F', '.', 'U', '.', 'S', trim(nvl(p_serie, ' ') || '.'))
        returning ultcod into v_ultcod;

      -- Se não teve efeito em algum registro, retorna erro
      if sql%rowcount = 0 then
        raise no_data_found;
      end if;

      -- Retorna o ultimo código utilizado
      return v_ultcod;

    --exception
    ---  when no_data_found then
            ----pkg_erro.lancar('Operação não permitida!', 'Numeração não disponível para os parâmetros informados (' || p_codtipoper || ', ' || nvl(p_codemp, 0) || ', ''' || nvl(p_serie, '') || ')', 'Cadastre uma numeração para a top ' || p_codtipoper);
    ----  when too_many_rows then
            ----pkg_erro.lancar('Operação não permitida!', 'Inconsistência na numeração para os parâmetros informados (' || p_codtipoper || ', ' || nvl(p_codemp, 0) || ', ''' || nvl(p_serie, '') || ')', '');
    end;

  -- Funções de inicialização do package vão aqui
begin
  null;
end;