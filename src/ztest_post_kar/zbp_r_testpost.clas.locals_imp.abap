CLASS lhc_testpostitem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setItemCurrency FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TestPostItem~setItemCurrency.
ENDCLASS.

CLASS lhc_testpostitem IMPLEMENTATION.
  METHOD setItemCurrency.
    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPostItem
        FIELDS ( TestId Waers )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPost
        FIELDS ( Waers )
        WITH VALUE #( FOR ls IN lt_items
                      ( %is_draft   = ls-%is_draft
                        %key-TestId = ls-TestId ) )
      RESULT DATA(lt_header).

    LOOP AT lt_items INTO DATA(ls_item)
      WHERE Waers IS INITIAL.
      DATA(lv_waers) = VALUE #(
        lt_header[
          KEY draft
          %is_draft   = ls_item-%is_draft
          %key-TestId = ls_item-TestId
        ]-Waers OPTIONAL ).

      IF lv_waers IS NOT INITIAL.
        MODIFY ENTITIES OF ZR_TestPost IN LOCAL MODE
          ENTITY TestPostItem
            UPDATE FIELDS ( Waers )
            WITH VALUE #( ( %tky  = ls_item-%tky
                            Waers = lv_waers ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_TestPost DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR TestPost RESULT result.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR TestPost RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR TestPost RESULT result.
*    METHODS PostDocument FOR MODIFY
*      IMPORTING keys FOR ACTION TestPost~PostDocument RESULT result.
    METHODS PostDocument FOR MODIFY
      IMPORTING keys FOR ACTION TestPost~PostDocument.
    METHODS ReverseDocument FOR MODIFY
      IMPORTING keys FOR ACTION TestPost~ReverseDocument RESULT result.
    METHODS propagateCurrency FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TestPost~propagateCurrency.
    METHODS validateBalance FOR VALIDATE ON SAVE
      IMPORTING keys FOR TestPost~validateBalance.
    METHODS CopyPosth FOR MODIFY
      IMPORTING keys FOR ACTION TestPost~CopyPosth.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE TestPost.
    METHODS earlynumbering_cba__items FOR NUMBERING
      IMPORTING entities FOR CREATE TestPost\_Items.
ENDCLASS.

CLASS lhc_TestPost IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPost FIELDS ( Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_data).

    result = VALUE #( FOR ls IN lt_data (
    %tky                    = ls-%tky
    %action-PostDocument    = COND #(
        " Draft 모드이고 Status가 초기/00일 때만 활성화
        WHEN ls-%is_draft = if_abap_behv=>mk-on
         AND ( ls-Status = '00' OR ls-Status IS INITIAL )
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )
    %action-ReverseDocument = COND #(
        WHEN ls-%is_draft = if_abap_behv=>mk-on
         AND ls-Status = '01'
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )
  ) ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.
    LOOP AT entities INTO DATA(ls_entity).
      IF ls_entity-TestId IS INITIAL.
        TRY.
            ls_entity-TestId = cl_system_uuid=>create_uuid_c22_static( ).
          CATCH cx_uuid_error.
            APPEND VALUE #( %cid = ls_entity-%cid ) TO failed-testpost.
            CONTINUE.
        ENDTRY.
      ENDIF.
      APPEND VALUE #(
        %cid        = ls_entity-%cid
        %is_draft   = ls_entity-%is_draft
        %key-TestId = ls_entity-TestId
      ) TO mapped-testpost.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_cba__items.
    LOOP AT entities INTO DATA(ls_entity).
      READ ENTITIES OF ZR_TestPost IN LOCAL MODE
        ENTITY TestPost BY \_Items
          FIELDS ( ItemNo )
          WITH VALUE #( ( %tky = ls_entity-%tky ) )
        RESULT DATA(lt_existing).

      DATA(lv_max) = REDUCE i(
        INIT m = 0
        FOR ls IN lt_existing
        NEXT m = COND #( WHEN ls-ItemNo > m THEN ls-ItemNo ELSE m ) ).

      DATA(lv_itemno) = lv_max.

      LOOP AT ls_entity-%target INTO DATA(ls_target).
        lv_itemno = lv_itemno + 10.
        APPEND VALUE #(
          %cid        = ls_target-%cid
          %is_draft   = ls_target-%is_draft
          %key-TestId = ls_entity-TestId
          %key-ItemNo = lv_itemno
        ) TO mapped-testpostitem.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

*  METHOD PostDocument.
*    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
*      ENTITY TestPost
*        FIELDS ( TestId Status )
*        WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_header)
*      FAILED DATA(lt_read_failed).
*
*    LOOP AT lt_header USING KEY draft INTO DATA(ls_header).
*      IF ls_header-Status = '01'
*      OR ls_header-Status = '02'
*      OR ls_header-Status = '09'.
*        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-testpost.
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = new_message_with_text(
*                   severity = if_abap_behv_message=>severity-error
*                   text     = '이미 전기되었거나 처리 중인 전표입니다.' )
*        ) TO reported-testpost.
*        CONTINUE.
*      ENDIF.
*
*      MODIFY ENTITIES OF ZR_TestPost IN LOCAL MODE
*        ENTITY TestPost
*          UPDATE FIELDS ( Status )
*          WITH VALUE #( (
*            %tky   = ls_header-%tky
*            Status = '09'
*          ) ).
*    ENDLOOP.
*  ENDMETHOD.

  METHOD PostDocument.
    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPost
        FIELDS ( TestId Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_header)
      FAILED DATA(lt_read_failed).

    LOOP AT lt_header USING KEY draft INTO DATA(ls_header).
      IF ls_header-Status = '01' OR ls_header-Status = '02' OR ls_header-Status = '09'.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-testpost.
        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = '이미 전기되었거나 처리 중인 전표입니다.' )
        ) TO reported-testpost.
        CONTINUE.
*        APPEND VALUE #(
*          %is_draft   = ls_header-%is_draft
*          %key-TestId = ls_header-TestId
*        ) TO result.
*        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF ZR_TestPost IN LOCAL MODE
        ENTITY TestPost
          UPDATE FIELDS ( Status )
          WITH VALUE #( (
            %tky   = ls_header-%tky
            Status = '09'
          ) ).

      GET TIME STAMP FIELD DATA(lv_ts).
      DATA(ls_start_info) = VALUE cl_apj_rt_api=>ty_start_info( timestamp = lv_ts ).

      DATA lv_jobname  TYPE cl_apj_rt_api=>ty_jobname.
      DATA lv_jobcount TYPE cl_apj_rt_api=>ty_jobcount.

      TRY.
          cl_apj_rt_api=>schedule_job(
            EXPORTING
              iv_job_template_name = 'ZTESTPOST_JOB_TMPL_KAR'
              iv_job_text          = '전표 전기 실행'
              is_start_info        = ls_start_info
            IMPORTING
              ev_jobname           = lv_jobname
              ev_jobcount          = lv_jobcount
          ).
        CATCH cx_apj_rt INTO DATA(lx_apj).
          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = lx_apj->get_longtext( ) )
          ) TO reported-testpost.
          CONTINUE.
      ENDTRY.

*      APPEND VALUE #(
*        %is_draft   = ls_header-%is_draft
*        %key-TestId = ls_header-TestId
*      ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD ReverseDocument.
    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPost
        FIELDS ( CompanyCode Belnr Gjahr Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_header).

    LOOP AT lt_header INTO DATA(ls_header).
      IF ls_header-Status <> '01'.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-testpost.
        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = '전기 완료된 전표만 역전 가능합니다.' )
        ) TO reported-testpost.
        CONTINUE.
      ENDIF.

      DATA(ls_action) = VALUE #(
        keys[ %tky = ls_header-%tky ] OPTIONAL ).

      DATA(ls_reverse) = VALUE zcl_testpost_comm_kar=>ts_reverse(
        companycode        = ls_header-CompanyCode
        accountingdocument = ls_header-Belnr
        fiscalyear         = ls_header-Gjahr
        reversalreason     = ls_action-%param-ReversalReason
        postingdate        = ls_action-%param-PostingDate
      ).

      DATA: lv_rev_belnr TYPE belnr_d,
            lv_rev_gjahr TYPE gjahr,
            lt_messages  TYPE bapirettab.

      zcl_testpost_comm_kar=>document_reverse_func(
        EXPORTING is_reverse       = ls_reverse
        IMPORTING ev_reverse_belnr = lv_rev_belnr
                  ev_reverse_gjahr = lv_rev_gjahr
                  et_messages      = lt_messages
      ).

      IF lv_rev_belnr IS NOT INITIAL.
        MODIFY ENTITIES OF ZR_TestPost IN LOCAL MODE
          ENTITY TestPost
            UPDATE FIELDS ( Status RevBelnr RevGjahr )
            WITH VALUE #( (
              %tky     = ls_header-%tky
              Status   = '02'
              RevBelnr = lv_rev_belnr
              RevGjahr = lv_rev_gjahr
            ) ).
        APPEND VALUE #( %tky = ls_header-%tky ) TO result.
      ELSE.
        LOOP AT lt_messages INTO DATA(ls_msg) WHERE type = 'E'.
          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = ls_msg-message )
          ) TO reported-testpost.
        ENDLOOP.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-testpost.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateBalance.
    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPost
        FIELDS ( Waers )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_header).

    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPost BY \_Items
        FIELDS ( JournalEntryItemAmount DebitCredit Waers )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_header) = VALUE #(
        lt_header[ KEY draft %tky = ls_key-%tky ] OPTIONAL ).

      DATA(lv_currency_error) = abap_false.

      LOOP AT lt_items USING KEY entity INTO DATA(ls_item)
           WHERE %tky-TestId = ls_key-TestId.
        IF ls_item-Waers IS NOT INITIAL AND ls_item-Waers <> ls_header-Waers.
          APPEND VALUE #(
            %tky = ls_key-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = |아이템 통화({ ls_item-Waers })가 헤더 통화({ ls_header-Waers })와 다릅니다.| )
          ) TO reported-testpost.
          APPEND VALUE #( %tky = ls_key-%tky ) TO failed-testpost.
          lv_currency_error = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.

      CHECK lv_currency_error = abap_false.

      DATA(lv_debit) = REDUCE decfloat34(
        INIT s = CONV decfloat34( 0 )
        FOR ls IN lt_items USING KEY entity
          WHERE ( %tky-TestId = ls_key-TestId AND DebitCredit = 'S' )
        NEXT s = s + ls-JournalEntryItemAmount ).

      DATA(lv_credit) = REDUCE decfloat34(
        INIT s = CONV decfloat34( 0 )
        FOR ls IN lt_items USING KEY entity
          WHERE ( %tky-TestId = ls_key-TestId AND DebitCredit = 'H' )
        NEXT s = s + ls-JournalEntryItemAmount ).

      IF lv_debit <> lv_credit.
        APPEND VALUE #(
          %tky = ls_key-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |차변({ lv_debit }) ≠ 대변({ lv_credit }). 합계가 일치해야 합니다.| )
        ) TO reported-testpost.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-testpost.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.



  METHOD propagateCurrency.
    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPost
        FIELDS ( Waers )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_header).

    LOOP AT lt_header INTO DATA(ls_header).
      READ ENTITIES OF ZR_TestPost IN LOCAL MODE
        ENTITY TestPost BY \_Items
          FIELDS ( TestId ItemNo Waers )
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_items).

      MODIFY ENTITIES OF ZR_TestPost IN LOCAL MODE
        ENTITY TestPostItem
          UPDATE FIELDS ( Waers )
          WITH VALUE #( FOR ls IN lt_items
                        WHERE ( Waers IS INITIAL OR Waers <> ls_header-Waers ) (
            %tky  = ls-%tky
            Waers = ls_header-Waers
          ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD CopyPosth.
    READ ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPost
        FIELDS ( CompanyCode AccountingDocumentType DocumentDate
                 PostingDate AccountingDocumentHeaderText Waers )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_header).

    DATA lt_create TYPE TABLE FOR CREATE ZR_TestPost.
    DATA ls_create TYPE STRUCTURE FOR CREATE ZR_TestPost.

    LOOP AT lt_header USING KEY draft INTO DATA(ls_header).
      CLEAR ls_create.
      ls_create-CompanyCode                  = ls_header-CompanyCode.
      ls_create-AccountingDocumentType       = ls_header-AccountingDocumentType.
      ls_create-DocumentDate                 = ls_header-DocumentDate.
      ls_create-PostingDate                  = ls_header-PostingDate.
      ls_create-AccountingDocumentHeaderText = ls_header-AccountingDocumentHeaderText.
      ls_create-Waers                        = ls_header-Waers.
      ls_create-%control-CompanyCode                  = if_abap_behv=>mk-on.
      ls_create-%control-AccountingDocumentType       = if_abap_behv=>mk-on.
      ls_create-%control-DocumentDate                 = if_abap_behv=>mk-on.
      ls_create-%control-PostingDate                  = if_abap_behv=>mk-on.
      ls_create-%control-AccountingDocumentHeaderText = if_abap_behv=>mk-on.
      ls_create-%control-Waers                        = if_abap_behv=>mk-on.
      APPEND ls_create TO lt_create.
    ENDLOOP.

    MODIFY ENTITIES OF ZR_TestPost IN LOCAL MODE
      ENTITY TestPost
        CREATE
        AUTO FILL CID
        FIELDS ( CompanyCode AccountingDocumentType DocumentDate
                 PostingDate AccountingDocumentHeaderText Waers )
        WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    " MAPPED 에 반환
    LOOP AT lt_header USING KEY draft INTO DATA(ls_header2).
      DATA(lv_idx) = sy-tabix.
      APPEND VALUE #(
        %cid        = keys[ KEY draft %tky = ls_header2-%tky ]-%cid
        %key-TestId = ls_mapped-testpost[ lv_idx ]-%key-TestId
      ) TO mapped-testpost.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
