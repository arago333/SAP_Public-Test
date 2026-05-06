CLASS zcl_matdoc_comm_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ts_header,
             goodsmovementcode          TYPE c LENGTH 2,
             postingdate                TYPE budat,
             documentdate               TYPE bldat,
             materialdocumentheadertext TYPE c LENGTH 25,
             referencedocument          TYPE c LENGTH 16,
           END OF ts_header.

    TYPES: BEGIN OF ts_item,
             plant                    TYPE werks_d,
             material                 TYPE matnr,
             storagelocation          TYPE lgort_d,
             goodsmovementtype        TYPE bwart,
             quantityinentryunit      TYPE menge_d,
             entryunit                TYPE meins,
             batch                    TYPE charg_d,
             purchaseorder            TYPE ebeln,
             purchaseorderitem        TYPE ebelp,
             costcenter               TYPE kostl,
             glaccount                TYPE hkont,
             materialdocumentitemtext TYPE c LENGTH 50,
           END OF ts_item.
    TYPES tt_items TYPE TABLE OF ts_item WITH EMPTY KEY.

    TYPES: BEGIN OF ts_cancel_hdr,
             materialdocument     TYPE mblnr,
             materialdocumentyear TYPE mjahr,
             postingdate          TYPE budat,
           END OF ts_cancel_hdr.

    TYPES: BEGIN OF ts_cancel_item,
             materialdocument     TYPE mblnr,
             materialdocumentyear TYPE mjahr,
             materialdocumentitem TYPE mblpo,
             postingdate          TYPE budat,
           END OF ts_cancel_item.

    CLASS-METHODS material_document_post
      IMPORTING
        !is_header   TYPE ts_header
        !it_items    TYPE tt_items
      EXPORTING
        !ev_matdoc   TYPE mblnr
        !ev_matdocyr TYPE mjahr
        !et_messages TYPE bapirettab.

    CLASS-METHODS material_document_cancel
      IMPORTING
        !is_cancel   TYPE ts_cancel_hdr
      EXPORTING
        !et_messages TYPE bapirettab.

    CLASS-METHODS material_document_item_cancel
      IMPORTING
        !is_cancel   TYPE ts_cancel_item
      EXPORTING
        !et_messages TYPE bapirettab.

  PRIVATE SECTION.

    TYPES ty_reported_early TYPE RESPONSE FOR REPORTED EARLY i_materialdocumenttp.
    TYPES ty_reported_late  TYPE RESPONSE FOR REPORTED LATE  i_materialdocumenttp.

    CLASS-METHODS add_reported_messages_early
      IMPORTING
        !is_reported TYPE ty_reported_early
      CHANGING
        !ct_messages TYPE bapirettab.

    CLASS-METHODS add_reported_messages_late
      IMPORTING
        !is_reported TYPE ty_reported_late
      CHANGING
        !ct_messages TYPE bapirettab.

ENDCLASS.


CLASS zcl_matdoc_comm_kar IMPLEMENTATION.

  METHOD material_document_post.

    CLEAR: ev_matdoc, ev_matdocyr, et_messages.

    IF is_header-goodsmovementcode IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'GoodsMovementCode(입고코드)는 필수 항목입니다.' ) TO et_messages.
    ENDIF.
    IF is_header-postingdate IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'PostingDate(전기일자)는 필수 항목입니다.' ) TO et_messages.
    ENDIF.
    IF it_items IS INITIAL.
      APPEND VALUE #( type = 'E' message = '아이템이 최소 1개 이상 필요합니다.' ) TO et_messages.
    ENDIF.

    LOOP AT it_items INTO DATA(ls_item_chk).
      DATA(lv_idx) = sy-tabix.

      IF ls_item_chk-plant IS INITIAL.
        APPEND VALUE #( type = 'E' message = |아이템 { lv_idx }: Plant(플랜트)는 필수 항목입니다.| ) TO et_messages.
      ENDIF.
      IF ls_item_chk-material IS INITIAL.
        APPEND VALUE #( type = 'E' message = |아이템 { lv_idx }: Material(자재번호)는 필수 항목입니다.| ) TO et_messages.
      ENDIF.
      IF ls_item_chk-goodsmovementtype IS INITIAL.
        APPEND VALUE #( type = 'E' message = |아이템 { lv_idx }: GoodsMovementType(이동유형)는 필수 항목입니다.| ) TO et_messages.
      ENDIF.
      IF ls_item_chk-quantityinentryunit IS INITIAL.
        APPEND VALUE #( type = 'E' message = |아이템 { lv_idx }: QuantityInEntryUnit(수량)는 필수 항목입니다.| ) TO et_messages.
      ENDIF.
      IF ls_item_chk-entryunit IS INITIAL.
        APPEND VALUE #( type = 'E' message = |아이템 { lv_idx }: EntryUnit(단위)는 필수 항목입니다.| ) TO et_messages.
      ENDIF.
    ENDLOOP.

    IF line_exists( et_messages[ type = 'E' ] ).
      RETURN.
    ENDIF.

    DATA: lt_header_create TYPE TABLE FOR CREATE i_materialdocumenttp\\materialdocument,
          ls_header_create LIKE LINE OF lt_header_create,
          lt_item_create   TYPE TABLE FOR CREATE i_materialdocumenttp\\materialdocument\_materialdocumentitem,
          ls_item_create   LIKE LINE OF lt_item_create.

    TRY.
        ls_header_create-%cid = cl_system_uuid=>create_uuid_c22_static( ).
      CATCH cx_uuid_error.
        ls_header_create-%cid = |MATDOC_HDR_{ cl_abap_context_info=>get_system_date( ) }{ cl_abap_context_info=>get_system_time( ) }|.
    ENDTRY.

    ls_header_create-goodsmovementcode = is_header-goodsmovementcode.
    ls_header_create-postingdate       = is_header-postingdate.
    ls_header_create-documentdate      = COND #(
      WHEN is_header-documentdate IS INITIAL
      THEN is_header-postingdate
      ELSE is_header-documentdate ).

    ls_header_create-%control-goodsmovementcode = cl_abap_behv=>flag_changed.
    ls_header_create-%control-postingdate       = cl_abap_behv=>flag_changed.
    ls_header_create-%control-documentdate      = cl_abap_behv=>flag_changed.

    IF is_header-materialdocumentheadertext IS NOT INITIAL.
      ls_header_create-materialdocumentheadertext          = is_header-materialdocumentheadertext.
      ls_header_create-%control-materialdocumentheadertext = cl_abap_behv=>flag_changed.
    ENDIF.

    IF is_header-referencedocument IS NOT INITIAL.
      ls_header_create-referencedocument          = is_header-referencedocument.
      ls_header_create-%control-referencedocument = cl_abap_behv=>flag_changed.
    ENDIF.

    APPEND ls_header_create TO lt_header_create.

    CLEAR ls_item_create.
    ls_item_create-%cid_ref = ls_header_create-%cid.

    LOOP AT it_items INTO DATA(ls_item).
      APPEND INITIAL LINE TO ls_item_create-%target ASSIGNING FIELD-SYMBOL(<ls_target>).

      <ls_target>-%cid                         = |ITEM_{ sy-tabix }|.
      <ls_target>-plant                        = ls_item-plant.
      <ls_target>-material                     = ls_item-material.
      <ls_target>-goodsmovementtype            = ls_item-goodsmovementtype.
      <ls_target>-quantityinentryunit          = ls_item-quantityinentryunit.
      <ls_target>-entryunit                    = ls_item-entryunit.
      <ls_target>-%control-plant               = cl_abap_behv=>flag_changed.
      <ls_target>-%control-material            = cl_abap_behv=>flag_changed.
      <ls_target>-%control-goodsmovementtype   = cl_abap_behv=>flag_changed.
      <ls_target>-%control-quantityinentryunit = cl_abap_behv=>flag_changed.
      <ls_target>-%control-entryunit           = cl_abap_behv=>flag_changed.

      IF ls_item-storagelocation IS NOT INITIAL.
        <ls_target>-storagelocation          = ls_item-storagelocation.
        <ls_target>-%control-storagelocation = cl_abap_behv=>flag_changed.
      ENDIF.
      IF ls_item-batch IS NOT INITIAL.
        <ls_target>-batch          = ls_item-batch.
        <ls_target>-%control-batch = cl_abap_behv=>flag_changed.
      ENDIF.
      IF ls_item-purchaseorder IS NOT INITIAL.
        <ls_target>-purchaseorder          = ls_item-purchaseorder.
        <ls_target>-%control-purchaseorder = cl_abap_behv=>flag_changed.
      ENDIF.
      IF ls_item-purchaseorderitem IS NOT INITIAL.
        <ls_target>-purchaseorderitem          = ls_item-purchaseorderitem.
        <ls_target>-%control-purchaseorderitem = cl_abap_behv=>flag_changed.
      ENDIF.
      IF ls_item-costcenter IS NOT INITIAL.
        <ls_target>-costcenter          = ls_item-costcenter.
        <ls_target>-%control-costcenter = cl_abap_behv=>flag_changed.
      ENDIF.
      IF ls_item-glaccount IS NOT INITIAL.
        <ls_target>-glaccount          = ls_item-glaccount.
        <ls_target>-%control-glaccount = cl_abap_behv=>flag_changed.
      ENDIF.
      IF ls_item-materialdocumentitemtext IS NOT INITIAL.
        <ls_target>-materialdocumentitemtext          = ls_item-materialdocumentitemtext.
        <ls_target>-%control-materialdocumentitemtext = cl_abap_behv=>flag_changed.
      ENDIF.
    ENDLOOP.

    APPEND ls_item_create TO lt_item_create.

    TRY.
        MODIFY ENTITIES OF i_materialdocumenttp
          ENTITY materialdocument
            CREATE FROM lt_header_create
          ENTITY materialdocument
            CREATE BY \_materialdocumentitem FROM lt_item_create
          MAPPED   DATA(ls_mapped)
          FAILED   DATA(ls_failed)
          REPORTED DATA(ls_reported).
      CATCH cx_root INTO DATA(lx_root).
        APPEND VALUE #( type = 'E' message = lx_root->get_text( ) ) TO et_messages.
        RETURN.
    ENDTRY.

    IF ls_failed IS NOT INITIAL.
      add_reported_messages_early(
        EXPORTING is_reported = ls_reported
        CHANGING  ct_messages = et_messages ).
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '자재문서 생성 요청 실패' ) TO et_messages.
      ENDIF.
      ROLLBACK ENTITIES.  " MODIFY 실패: transactional buffer 명시적 정리
      RETURN.
    ENDIF.

    " I_MaterialDocumentTP = Late Numbering BO
    " - MODIFY 시점: %pid(preliminary ID)만 존재, 확정 키(mblnr/mjahr) 없음
    " - 확정 키: adjust_numbers에서 부여 → COMMIT BEGIN...END 구간 내 CONVERT KEY OF 로만 취득 가능
    " - lv_commit_error 플래그 패턴: BEGIN...END 안에서 RETURN 방지, END 항상 실행 보장
    " - ls_commit_failed 는 BEGIN...END 안에서, sy-subrc 는 END 이후에 판정
    DATA(lv_commit_error) = abap_false.

    COMMIT ENTITIES BEGIN
      RESPONSE OF i_materialdocumenttp
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    IF ls_commit_failed IS INITIAL.
      " late save 성공: %pid -> 확정 키(mblnr/mjahr) 변환
      " CONVERT KEY OF 는 반드시 BEGIN...END 구간 안에서만 유효
      LOOP AT ls_mapped-materialdocument ASSIGNING FIELD-SYMBOL(<ls_mapped_hdr>).
        CONVERT KEY OF i_materialdocumenttp\\materialdocument
          FROM <ls_mapped_hdr>-%pid
          TO DATA(ls_final_key).

        ev_matdoc   = ls_final_key-materialdocument.
        ev_matdocyr = ls_final_key-materialdocumentyear.
        EXIT.  " 단건 헤더이므로 첫 번째 항목만 취득
      ENDLOOP.
    ELSE.
      lv_commit_error = abap_true.
    ENDIF.



    COMMIT ENTITIES END.

    " sy-subrc 판정은 END 이후에: 시스템별 애매함 방지
    IF sy-subrc <> 0.
      lv_commit_error = abap_true.
    ENDIF.

    " COMMIT 실패 후 ROLLBACK ENTITIES 제거:
    " sy-subrc=8(late phase 실패) 시 내부 롤백 이미 발생
    " 이후 추가 EML 없이 바로 RETURN하는 구조이므로 명시 불필요
    IF lv_commit_error = abap_true.
      add_reported_messages_late(
        EXPORTING is_reported = ls_commit_reported
        CHANGING  ct_messages = et_messages ).
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '자재문서 COMMIT 실패' ) TO et_messages.
      ENDIF.
      RETURN.
    ENDIF.

    IF ev_matdoc IS INITIAL OR ev_matdocyr IS INITIAL.
      APPEND VALUE #(
        type    = 'E'
        message = '자재문서 생성 후 문서번호를 확인하지 못했습니다.'
      ) TO et_messages.
      RETURN.
    ENDIF.

    APPEND VALUE #(
      type    = 'S'
      message = |자재문서 생성 성공: { ev_matdoc } / { ev_matdocyr }|
    ) TO et_messages.

  ENDMETHOD.


  METHOD material_document_cancel.

    CLEAR et_messages.

    IF is_cancel-materialdocument IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'MaterialDocument(자재문서번호)는 필수 항목입니다.' ) TO et_messages.
    ENDIF.
    IF is_cancel-materialdocumentyear IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'MaterialDocumentYear(자재문서연도)는 필수 항목입니다.' ) TO et_messages.
    ENDIF.
    IF line_exists( et_messages[ type = 'E' ] ).
      RETURN.
    ENDIF.

    DATA(lv_postingdate) = COND budat(
      WHEN is_cancel-postingdate IS INITIAL
      THEN cl_abap_context_info=>get_system_date( )
      ELSE is_cancel-postingdate ).

    DATA lt_cancel TYPE TABLE FOR ACTION IMPORT i_materialdocumenttp\\materialdocument~cancel.
    lt_cancel = VALUE #( (
      %key-materialdocument     = is_cancel-materialdocument
      %key-materialdocumentyear = is_cancel-materialdocumentyear
      %param-postingdate        = lv_postingdate
    ) ).

    TRY.
        MODIFY ENTITY i_materialdocumenttp\\materialdocument
          EXECUTE cancel FROM lt_cancel
          FAILED   DATA(ls_failed)
          REPORTED DATA(ls_reported).
      CATCH cx_root INTO DATA(lx_root).
        APPEND VALUE #( type = 'E' message = lx_root->get_text( ) ) TO et_messages.
        RETURN.
    ENDTRY.

    IF ls_failed IS NOT INITIAL.
      add_reported_messages_early(
        EXPORTING is_reported = ls_reported
        CHANGING  ct_messages = et_messages ).
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '자재문서 취소 요청 실패' ) TO et_messages.
      ENDIF.
      ROLLBACK ENTITIES.  " MODIFY 실패: transactional buffer 명시적 정리
      RETURN.
    ENDIF.

    DATA(lv_commit_error) = abap_false.

    COMMIT ENTITIES BEGIN
      RESPONSE OF i_materialdocumenttp
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    IF ls_commit_failed IS NOT INITIAL.
      lv_commit_error = abap_true.
    ENDIF.

    COMMIT ENTITIES END.

    IF sy-subrc <> 0.
      lv_commit_error = abap_true.
    ENDIF.

    IF lv_commit_error = abap_true.
      add_reported_messages_late(
        EXPORTING is_reported = ls_commit_reported
        CHANGING  ct_messages = et_messages ).
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '자재문서 취소 COMMIT 실패' ) TO et_messages.
      ENDIF.
      RETURN.  " COMMIT 실패 후 ROLLBACK ENTITIES 불필요
    ENDIF.

    APPEND VALUE #(
      type    = 'S'
      message = |자재문서 { is_cancel-materialdocument } ({ is_cancel-materialdocumentyear }) 취소 완료|
    ) TO et_messages.

  ENDMETHOD.


  METHOD material_document_item_cancel.

    CLEAR et_messages.

    IF is_cancel-materialdocument IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'MaterialDocument(자재문서번호)는 필수 항목입니다.' ) TO et_messages.
    ENDIF.
    IF is_cancel-materialdocumentyear IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'MaterialDocumentYear(자재문서연도)는 필수 항목입니다.' ) TO et_messages.
    ENDIF.
    IF is_cancel-materialdocumentitem IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'MaterialDocumentItem(자재문서아이템)는 필수 항목입니다.' ) TO et_messages.
    ENDIF.
    IF line_exists( et_messages[ type = 'E' ] ).
      RETURN.
    ENDIF.

    DATA(lv_postingdate) = COND budat(
      WHEN is_cancel-postingdate IS INITIAL
      THEN cl_abap_context_info=>get_system_date( )
      ELSE is_cancel-postingdate ).

    DATA lt_cancel TYPE TABLE FOR ACTION IMPORT i_materialdocumenttp\\materialdocumentitem~cancel.
    lt_cancel = VALUE #( (
      %key-materialdocument     = is_cancel-materialdocument
      %key-materialdocumentyear = is_cancel-materialdocumentyear
      %key-materialdocumentitem = is_cancel-materialdocumentitem
      %param-postingdate        = lv_postingdate
    ) ).

    TRY.
        MODIFY ENTITY i_materialdocumenttp\\materialdocumentitem
          EXECUTE cancel FROM lt_cancel
          FAILED   DATA(ls_failed)
          REPORTED DATA(ls_reported).
      CATCH cx_root INTO DATA(lx_root).
        APPEND VALUE #( type = 'E' message = lx_root->get_text( ) ) TO et_messages.
        RETURN.
    ENDTRY.

    IF ls_failed IS NOT INITIAL.
      add_reported_messages_early(
        EXPORTING is_reported = ls_reported
        CHANGING  ct_messages = et_messages ).
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '자재문서 아이템 취소 요청 실패' ) TO et_messages.
      ENDIF.
      ROLLBACK ENTITIES.  " MODIFY 실패: transactional buffer 명시적 정리
      RETURN.
    ENDIF.

    DATA(lv_commit_error) = abap_false.

    COMMIT ENTITIES BEGIN
      RESPONSE OF i_materialdocumenttp
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    IF ls_commit_failed IS NOT INITIAL.
      lv_commit_error = abap_true.
    ENDIF.

    COMMIT ENTITIES END.

    IF sy-subrc <> 0.
      lv_commit_error = abap_true.
    ENDIF.

    IF lv_commit_error = abap_true.
      add_reported_messages_late(
        EXPORTING is_reported = ls_commit_reported
        CHANGING  ct_messages = et_messages ).
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '자재문서 아이템 취소 COMMIT 실패' ) TO et_messages.
      ENDIF.
      RETURN.  " COMMIT 실패 후 ROLLBACK ENTITIES 불필요
    ENDIF.

    APPEND VALUE #(
      type    = 'S'
      message = |자재문서 { is_cancel-materialdocument } 아이템 { is_cancel-materialdocumentitem } 취소 완료|
    ) TO et_messages.

  ENDMETHOD.


  METHOD add_reported_messages_early.

    LOOP AT is_reported-materialdocument INTO DATA(ls_hdr).
      IF ls_hdr-%msg IS BOUND.
        APPEND VALUE #(
          type    = ls_hdr-%msg->m_severity
          message = ls_hdr-%msg->if_message~get_text( )
        ) TO ct_messages.
      ENDIF.
    ENDLOOP.

    LOOP AT is_reported-materialdocumentitem INTO DATA(ls_itm).
      IF ls_itm-%msg IS BOUND.
        APPEND VALUE #(
          type    = ls_itm-%msg->m_severity
          message = ls_itm-%msg->if_message~get_text( )
        ) TO ct_messages.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD add_reported_messages_late.

    LOOP AT is_reported-materialdocument INTO DATA(ls_hdr).
      IF ls_hdr-%msg IS BOUND.
        APPEND VALUE #(
          type    = ls_hdr-%msg->m_severity
          message = ls_hdr-%msg->if_message~get_text( )
        ) TO ct_messages.
      ENDIF.
    ENDLOOP.

    LOOP AT is_reported-materialdocumentitem INTO DATA(ls_itm).
      IF ls_itm-%msg IS BOUND.
        APPEND VALUE #(
          type    = ls_itm-%msg->m_severity
          message = ls_itm-%msg->if_message~get_text( )
        ) TO ct_messages.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

