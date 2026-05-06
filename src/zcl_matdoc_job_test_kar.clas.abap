CLASS zcl_matdoc_job_test_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS zcl_matdoc_job_test_kar IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

*    " --------------------------------------------------
*    " 1. 실행 전 대기건 확인
*    " --------------------------------------------------
    SELECT req_id,
           status,
           goodsmovementcode,
           postingdate
      FROM zmdoc_req_h_kar
      WHERE status = '09'
      INTO TABLE @DATA(lt_pending).

    out->write( |Status 09 건수: { lines( lt_pending ) }| ).

    IF lt_pending IS INITIAL.
      out->write( '자재문서 생성 대기건이 없습니다.' ).
      RETURN.
    ENDIF.

    LOOP AT lt_pending INTO DATA(ls_pending).
      out->write(
        |대기건 -> ReqId: { ls_pending-req_id } / GM Code: { ls_pending-goodsmovementcode } / PostingDate: { ls_pending-postingdate }|
      ).
    ENDLOOP.
*
*    " --------------------------------------------------
*    " 2. 실제 잡 클래스 실행
*    " --------------------------------------------------
    TRY.
        DATA(lo_job) = NEW zcl_matdoc_job_kar( ).

        lo_job->if_apj_rt_exec_object~execute(
          it_parameters = VALUE #( )
        ).

        out->write( '자재문서 어플리케이션 잡 실행 완료' ).

      CATCH cx_apj_rt_content INTO DATA(lx_apj).
        out->write( |APJ 오류: { lx_apj->get_text( ) }| ).
        RETURN.

      CATCH cx_root INTO DATA(lx_root).
        out->write( |일반 오류: { lx_root->get_text( ) }| ).
        RETURN.
    ENDTRY.
*
*    " --------------------------------------------------
*    " 3. 실행 후 결과 재조회
*    " --------------------------------------------------
    SELECT req_id,
           status,
           matdoc,
           matdocyr,
           message_type,
           message_text
      FROM zmdoc_req_h_kar
      FOR ALL ENTRIES IN @lt_pending
      WHERE req_id = @lt_pending-req_id
      INTO TABLE @DATA(lt_result).

    IF lt_result IS INITIAL.
      out->write( '처리 결과 조회 건이 없습니다.' ).
      RETURN.
    ENDIF.

    SORT lt_result BY req_id.

    LOOP AT lt_result INTO DATA(ls_result).
      out->write(
        |결과 -> ReqId: { ls_result-req_id } / Status: { ls_result-status } / MatDoc: { ls_result-matdoc } / Year: { ls_result-matdocyr } / MsgType: { ls_result-message_type } / Msg: { ls_result-message_text }|
      ).
    ENDLOOP.

    DATA lt_messages TYPE bapirettab.

    " --------------------------------------------------
    " 1. 아이템 취소 테스트
    " 먼저 특정 아이템 취소
    " --------------------------------------------------
*    CLEAR lt_messages.
*
*    DATA(ls_item_cancel) = VALUE zcl_matdoc_comm_kar=>ts_cancel_item(
*      materialdocument     = '4900000002'
*      materialdocumentyear = '2024'
*      materialdocumentitem = '0001'
*      postingdate          = '20240215'
*    ).
*
*    out->write(
*      |아이템 취소 테스트 -> MatDoc: { ls_item_cancel-materialdocument } / Year: { ls_item_cancel-materialdocumentyear } / Item: { ls_item_cancel-materialdocumentitem }|
*    ).
*
*    TRY.
*        zcl_matdoc_comm_kar=>material_document_item_cancel(
*          EXPORTING
*            is_cancel   = ls_item_cancel
*          IMPORTING
*            et_messages = lt_messages
*        ).
*      CATCH cx_root INTO DATA(lx_item_root).
*        out->write( |아이템 취소 일반 오류: { lx_item_root->get_text( ) }| ).
*        RETURN.
*    ENDTRY.
*
*    IF lt_messages IS INITIAL.
*      out->write( '아이템 취소 반환 메시지가 없습니다.' ).
*    ELSE.
*      LOOP AT lt_messages INTO DATA(ls_item_msg).
*        out->write(
*          |아이템 취소 결과 -> Type: { ls_item_msg-type } / Message: { ls_item_msg-message }|
*        ).
*      ENDLOOP.
*    ENDIF.

    " --------------------------------------------------
    " 2. 헤더 전체 취소 테스트
    " 아이템 취소 후 별도 문서로 헤더 전체 취소
    " --------------------------------------------------
*    CLEAR lt_messages.
*
*    DATA(ls_hdr_cancel) = VALUE zcl_matdoc_comm_kar=>ts_cancel_hdr(
*      materialdocument     = '4900000003'
*      materialdocumentyear = '2024'
*      postingdate          = '20240215'
*    ).
*
*    out->write(
*      |헤더 취소 테스트 -> MatDoc: { ls_hdr_cancel-materialdocument } / Year: { ls_hdr_cancel-materialdocumentyear }|
*    ).
*
*    TRY.
*        zcl_matdoc_comm_kar=>material_document_cancel(
*          EXPORTING
*            is_cancel   = ls_hdr_cancel
*          IMPORTING
*            et_messages = lt_messages
*        ).
*      CATCH cx_root INTO DATA(lx_hdr_root).
*        out->write( |헤더 취소 일반 오류: { lx_hdr_root->get_text( ) }| ).
*        RETURN.
*    ENDTRY.
*
*    IF lt_messages IS INITIAL.
*      out->write( '헤더 취소 반환 메시지가 없습니다.' ).
*    ELSE.
*      LOOP AT lt_messages INTO DATA(ls_hdr_msg).
*        out->write(
*          |헤더 취소 결과 -> Type: { ls_hdr_msg-type } / Message: { ls_hdr_msg-message }|
*        ).
*      ENDLOOP.
*    ENDIF.

  ENDMETHOD.
ENDCLASS.
