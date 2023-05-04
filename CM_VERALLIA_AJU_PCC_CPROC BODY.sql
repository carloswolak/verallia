--------------------------------------------------------
--  Arquivo criado - Terça-feira-Maio-02-2023   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Package Body CM_VERALLIA_AJU_PCC_CPROC
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "USER_TAXONE_VERALLIA"."CM_VERALLIA_AJU_PCC_CPROC" IS
  --variáveis de status

  mcod_estab   estabelecimento.cod_estab%TYPE;
  mcod_empresa empresa.cod_empresa%TYPE;
  mcod_usuario usuario_estab.cod_usuario%TYPE;
  mcod_cfo     x2012_cod_fiscal.cod_cfo%TYPE;

 mproc_id INTEGER;

  mLinha varchar2(4000);

  FUNCTION Parametros RETURN VARCHAR2 IS
    pstr VARCHAR2(5000);
  BEGIN

    mcod_empresa := LIB_PARAMETROS.RECUPERAR('EMPRESA');
    mcod_estab   := NVL(LIB_PARAMETROS.RECUPERAR('ESTABELECIMENTO'), '');
    mcod_usuario := LIB_PARAMETROS.Recuperar('Usuario');

    LIB_PROC.add_param(pstr,
                       'Estabelecimento',
                       'Varchar2',
                       'Combobox',
                       'S',
                       null,
                       NULL,
                       'SELECT DISTINCT cod_estab, cod_estab||'' - ''||razao_social ' ||
                       'FROM estabelecimento WHERE COD_EMPRESA = ''' ||
                       mcod_empresa || ''' and cod_estab = nvl(''' ||
                       mcod_estab || ''', cod_estab) ORDER BY 1');
    LIB_PROC.add_param(pstr,
                       'Data Inicial',
                       'Date',
                       'textbox',
                       'S',
                       NULL,
                       'DD/MM/YYYY');
    LIB_PROC.add_param(pstr,
                       'Data Final',
                       'Date',
                       'textbox',
                       'S',
                       NULL,
                       'DD/MM/YYYY');

    RETURN pstr;
  END;

  FUNCTION Nome RETURN VARCHAR2 IS
  BEGIN
    RETURN 'TAXONE - Ajusta Valor dO PIS/COFINS das notas de importação 2';
  END;

  FUNCTION Tipo RETURN VARCHAR2 IS
  BEGIN
    RETURN 'FISCAL';
  END;

  FUNCTION Versao RETURN VARCHAR2 IS
  BEGIN
    RETURN '2.0';
  END;

  FUNCTION Descricao RETURN VARCHAR2 IS
  BEGIN
    RETURN 'TAXONE - Ajusta Valor dO PIS/COFINS das notas de importação 2';
  END;

  FUNCTION Modulo RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Customizados';
  END;

  FUNCTION Classificacao RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Customizados';
  END;

  FUNCTION orientacao RETURN VARCHAR2 IS
  BEGIN
    /* Orientação do Papel. */
    RETURN 'LANDSCAPE';
  END;

  FUNCTION Executar(PCod_Estab varchar2, pDataIni Date, PDataFim Date)
    return INTEGER is

    p_cod_empresa empresa.cod_empresa%TYPE;

    v_aliq_pis_par    x176_prt_cta_custo_f100.vlr_aliq_pis%type;
    v_aliq_cofins_par x176_prt_cta_custo_f100.vlr_aliq_cofins%type;
    v_ind_tp_oper     x176_prt_cta_custo_f100.ind_tp_oper%type;

  BEGIN

    -- Cria Processo
  mproc_id := LIB_PROC.new('CM_VERALLIA_AJU_PCC_CPROC', 48, 150);


   Lib_Proc.Add_Tipo(pproc_id  => mproc_id,
                      ptipo     => 1,
                      ptitulo   => 'LOG',
                      ptipo_arq => 1);

    p_cod_empresa := LIB_PARAMETROS.RECUPERAR('EMPRESA');

  --  execute immediate 'alter session set nls_language=''BRAZILIAN PORTUGUESE''';

    FOR AJUSTE_PC IN (select distinct X8.COD_EMPRESA     EMPRESA,
                                      X8.COD_ESTAB       ESTABELECIMENTO,
                                      X8.MOVTO_E_S       E_S,
                                      X8.DATA_FISCAL     DATA,
                                      X8.COD_FIS_JUR     PF_PJ,
                                      X8.NUM_DOCFIS      NF,
                                      X8.SERIE_DOCFIS    SERIE,
                                      x8.num_item        NUM_ITEM,
                                      X8.VLR_CONTAB_ITEM VLR_CONTABIL,
                                      x8.VLR_BASE_PIS    VLR_BASE_PIS,
                                      x8.VLR_BASE_COFINS VLR_BASE_COFINS,
                                      X8.VLR_ALIQ_PIS    ALIQ_PIS,

                                      (CASE
                                        WHEN X8.VLR_ALIQ_COFINS / 100 >
                                             '9.65' THEN
                                         '0096500'
                                        ELSE
                                         X8.VLR_ALIQ_COFINS
                                      END) ALIQ_COFINS
                        FROM SAFX08 X8
                       WHERE X8.cod_cfo LIKE '3%'
                            --AND X8.DATA_FISCAL BETWEEN '01/12/2014' AND '31/12/2014'
                         AND TO_DATE(X8.DATA_FISCAL, 'YYYYMMDD') BETWEEN
                             PDATAINI AND PDATAFIM
                         AND X8.COD_EMPRESA = P_COD_EMPRESA
                         AND X8.COD_ESTAB = PCOD_ESTAB
                         AND X8.COD_SITUACAO_PIS NOT IN (3, 4)
                       ORDER BY X8.NUM_DOCFIS, X8.NUM_ITEM)

     LOOP

      UPDATE SAFX08 MD
         SET MD.VLR_CONTAB_ITEM = AJUSTE_PC.VLR_CONTABIL,
             MD.VLR_BASE_PIS    = AJUSTE_PC.VLR_BASE_PIS,
             MD.VLR_BASE_COFINS = AJUSTE_PC.VLR_BASE_COFINS,
             MD.VLR_PIS         = trunc((AJUSTE_PC.VLR_BASE_PIS / 100) *
                                        (AJUSTE_PC.ALIQ_PIS / 10000),
                                        0),
             --  AJUSTE_PC.VLR_BASE_PIS *                         (AJUSTE_PC.ALIQ_PIS / 100),
             MD.VLR_COFINS = trunc((AJUSTE_PC.VLR_BASE_COFINS / 100) *
                                   (AJUSTE_PC.ALIQ_COFINS / 10000),
                                   0),
             -- AJUSTE_PC.VLR_BASE_COFINS *  (AJUSTE_PC.ALIQ_COFINS / 100),
             MD.DAT_LANC_PIS_COFINS = AJUSTE_PC.DATA,
             MD.VLR_ALIQ_PIS        = AJUSTE_PC.ALIQ_PIS,
             MD.VLR_ALIQ_COFINS     = AJUSTE_PC.ALIQ_COFINS
       WHERE MD.COD_EMPRESA = AJUSTE_PC.EMPRESA
         AND MD.COD_ESTAB = AJUSTE_PC.ESTABELECIMENTO
         AND MD.DATA_FISCAL = AJUSTE_PC.DATA
         AND MD.MOVTO_E_S = AJUSTE_PC.E_S
         AND MD.NUM_ITEM = AJUSTE_PC.NUM_ITEM
         AND MD.NUM_DOCFIS = AJUSTE_PC.NF
         AND MD.SERIE_DOCFIS = AJUSTE_PC.SERIE
         AND MD.COD_FIS_JUR = AJUSTE_PC.PF_PJ
         AND MD.COD_SITUACAO_PIS NOT IN (3, 4);

    /*UPDATE X08_ITENS_MERC MD SET MD.VLR_CONTAB_ITEM = AJUSTE_PC.VLR_CONTABIL
                                          ,MD.VLR_BASE_PIS    = AJUSTE_PC.VLR_BASE_PIS
                                          ,MD.VLR_BASE_COFINS = AJUSTE_PC.VLR_BASE_COFINS
                                          ,MD.VLR_PIS         = AJUSTE_PC.VLR_BASE_PIS * (AJUSTE_PC.ALIQ_PIS/100)
                                          ,MD.VLR_COFINS      = AJUSTE_PC.VLR_BASE_COFINS * (AJUSTE_PC.ALIQ_COFINS/100)
                                          ,MD.DAT_LANC_PIS_COFINS = AJUSTE_PC.DATA
                                          ,MD.VLR_ALIQ_PIS        = AJUSTE_PC.ALIQ_PIS
                                          ,MD.VLR_ALIQ_COFINS     = AJUSTE_PC.ALIQ_COFINS
              WHERE MD.COD_EMPRESA        = AJUSTE_PC.EMPRESA
                AND MD.COD_ESTAB          = AJUSTE_PC.ESTABELECIMENTO
                AND MD.DATA_FISCAL        = AJUSTE_PC.DATA
                AND MD.MOVTO_E_S          = AJUSTE_PC.E_S
                AND MD.NUM_ITEM           = AJUSTE_PC.NUM_ITEM
                AND MD.NUM_DOCFIS         = AJUSTE_PC.NF
                AND MD.SERIE_DOCFIS       = AJUSTE_PC.SERIE
                AND MD.IDENT_FIS_JUR      = AJUSTE_PC.PF_PJ
                AND MD.COD_SITUACAO_PIS NOT IN (3,4);*/

    /* UPDATE DWT_ITENS_MERC DWT SET DWT.VLR_CONTAB_ITEM = AJUSTE_PC.VLR_CONTABIL
                                          ,DWT.VLR_BASE_PIS    = AJUSTE_PC.VLR_BASE_PIS
                                          ,DWT.VLR_BASE_COFINS = AJUSTE_PC.VLR_BASE_COFINS
                                          ,DWT.VLR_PIS         = AJUSTE_PC.VLR_BASE_PIS * (AJUSTE_PC.ALIQ_PIS/100)
                                          ,DWT.VLR_COFINS      = AJUSTE_PC.VLR_BASE_COFINS * (AJUSTE_PC.ALIQ_COFINS/100)
                                          ,DWT.DAT_LANC_PIS_COFINS = AJUSTE_PC.DATA
                                          ,DWT.VLR_ALIQ_PIS        = AJUSTE_PC.ALIQ_PIS
                                          ,DWT.VLR_ALIQ_COFINS     = AJUSTE_PC.ALIQ_COFINS
              WHERE DWT.COD_EMPRESA        = AJUSTE_PC.EMPRESA
                AND DWT.COD_ESTAB          = AJUSTE_PC.ESTABELECIMENTO
                AND DWT.DATA_FISCAL        = AJUSTE_PC.DATA
                AND DWT.MOVTO_E_S          = AJUSTE_PC.E_S
                AND DWT.NUM_ITEM           = AJUSTE_PC.NUM_ITEM
                AND DWT.NUM_DOCFIS         = AJUSTE_PC.NF
                AND DWT.SERIE_DOCFIS       = AJUSTE_PC.SERIE
                AND DWT.IDENT_FIS_JUR      = AJUSTE_PC.PF_PJ
                AND DWT.COD_SITUACAO_PIS NOT IN (3,4);*/

    END LOOP;
    COMMIT;

    update SAFX147
       set ind_origem_cred = 0
     where COD_CONTA in ('0000613210', '0000624860')
       and cod_empresa = P_COD_EMPRESA
       and cod_estab = PCOD_ESTAB
       AND TO_DATE(data_oper, 'YYYYMMDD') BETWEEN PDATAINI AND PDATAFIM;

    /*  update x147_oper_cred set ind_origem_cred = 0 where ident_conta in
    (select ident_conta from x2002_plano_contas where cod_conta in ('0000613210','0000624860'))
     and cod_empresa = P_COD_EMPRESA
     and cod_estab = PCOD_ESTAB
     AND data_oper BETWEEN PDATAINI AND PDATAFIM;*/

    /*update x147_oper_cred set vlr_aliq_pis=null, vlr_aliq_cofins=null, vlr_base_pis=vlr_oper, vlr_base_cofins=vlr_oper
    where vlr_aliq_pis=0 and vlr_aliq_cofins=0
     and cod_empresa = PCOD_EMPRESA
     and cod_estab = PCOD_ESTAB
     AND data_oper BETWEEN PDATAINI AND PDATAFIM; */

    for c_x147_ajuste in (select *
                            from SAFX147
                           where vlr_aliq_pis = 0
                             and vlr_aliq_cofins = 0
                             and cod_empresa = P_COD_EMPRESA
                             and cod_estab = PCOD_ESTAB
                             AND TO_DATE(data_oper, 'YYYYMMDD') BETWEEN
                                 PDATAINI AND PDATAFIM) LOOP
      begin

        select vlr_aliq_pis, vlr_aliq_cofins, ind_tp_oper
          into v_aliq_pis_par, v_aliq_cofins_par, v_ind_tp_oper

          from SAFX176
         where cod_Conta = c_x147_ajuste.cod_conta;

        /*  select vlr_aliq_pis, vlr_aliq_cofins, ind_tp_oper
            into v_aliq_pis_par,v_aliq_cofins_par,v_ind_tp_oper

        from x176_prt_cta_custo_f100
         where ident_conta = c_x147_ajuste.ident_conta;*/
      exception
        when no_data_found then
          v_ind_tp_oper := null;
      end;
      if v_ind_tp_oper is not null then

        if v_ind_tp_oper <> 2 then

          update SAFX147
             set vlr_aliq_pis    = null,
                 vlr_aliq_cofins = null,
                 vlr_base_pis    = vlr_oper,
                 vlr_base_cofins = vlr_oper,
                 vlr_pis        =
                 (vlr_oper * (v_aliq_pis_par / 100)),
                 vlr_cofins     =
                 (vlr_oper * (v_aliq_cofins_par / 100))
           where vlr_aliq_pis = 0
             and vlr_aliq_cofins = 0
             and COD_EMPRESA = c_x147_ajuste.COD_EMPRESA
             and COD_ESTAB = c_x147_ajuste.COD_ESTAB
             and COD_DOCTO = c_x147_ajuste.COD_DOCTO
             and DATA_OPER = c_x147_ajuste.DATA_OPER
                --  and DISCRI_OPER = c_x147_ajuste.DISCRI_OPER
             and NUM_DOCTO = c_x147_ajuste.NUM_DOCTO
             and SERIE = c_x147_ajuste.SERIE
             and SUB_SERIE = c_x147_ajuste.SUB_SERIE
             and NUM_LANCTO = c_x147_ajuste.NUM_LANCTO;

          /* update x147_oper_cred set vlr_aliq_pis=null, vlr_aliq_cofins=null, vlr_base_pis=vlr_oper, vlr_base_cofins=vlr_oper,
           vlr_pis = (vlr_oper * (v_aliq_pis_par/100)), vlr_cofins = (vlr_oper * (v_aliq_cofins_par/100))
          where vlr_aliq_pis=0 and vlr_aliq_cofins=0
           and COD_EMPRESA = c_x147_ajuste.COD_EMPRESA
           and COD_ESTAB = c_x147_ajuste.COD_ESTAB
           and IDENT_DOCTO = c_x147_ajuste.IDENT_DOCTO
           and DATA_OPER = c_x147_ajuste.DATA_OPER
           and DISCRI_OPER = c_x147_ajuste.DISCRI_OPER
           and NUM_DOCTO = c_x147_ajuste.NUM_DOCTO
           and SERIE = c_x147_ajuste.SERIE
           and SUB_SERIE = c_x147_ajuste.SUB_SERIE
           and NUM_LANCTO =c_x147_ajuste.NUM_LANCTO;*/

        end if;

      end if;

    END LOOP;

    COMMIT;

    LIB_PROC.add('CONCLUIDO COM SUCESSO');


    LIB_PROC.close();
    commit;

    return mproc_id;

  EXCEPTION
    WHEN OTHERS THEN
      LIB_PROC.add_log('CONCLUIDO COM ERROS', 2);

      LIB_PROC.close();
      ROLLBACK;
       return mproc_id;


  END;

END CM_VERALLIA_AJU_PCC_CPROC;

/
