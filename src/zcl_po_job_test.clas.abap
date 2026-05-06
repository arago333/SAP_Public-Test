CLASS zcl_po_job_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS ZCL_PO_JOB_TEST IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    " --------------------------------------------------
    " 1. 실행 전 대기건 확인
    " --------------------------------------------------
    SELECT req_id,
           status,
           supplier,
           purchaseordertype
      FROM zpo_req_h_kar
      WHERE status = '09'
      INTO TABLE @DATA(lt_pending).

    out->write( |Status 09 건수: { lines( lt_pending ) }| ).

    IF lt_pending IS INITIAL.
      out->write( '구매오더 생성 대기건이 없습니다.' ).
      RETURN.
    ENDIF.

    LOOP AT lt_pending INTO DATA(ls_pending).
      out->write(
        |대기건 -> ReqId: { ls_pending-req_id } / Supplier: { ls_pending-supplier } / PO Type: { ls_pending-purchaseordertype }|
      ).
    ENDLOOP.

    " --------------------------------------------------
    " 2. 실제 잡 클래스 실행
    " --------------------------------------------------
    TRY.
        DATA(lo_job) = NEW zcl_po_job_kar( ).

        lo_job->if_apj_rt_exec_object~execute(
          it_parameters = VALUE #( )
        ).

        out->write( '구매오더 어플리케이션 잡 실행 완료' ).

      CATCH cx_apj_rt_content INTO DATA(lx_apj).
        out->write( |APJ 오류: { lx_apj->get_text( ) }| ).
        RETURN.

      CATCH cx_root INTO DATA(lx_root).
        out->write( |일반 오류: { lx_root->get_text( ) }| ).
        RETURN.
    ENDTRY.

    " --------------------------------------------------
    " 3. 실행 후 결과 재조회
    " --------------------------------------------------
    SELECT req_id,
           status,
           ebeln,
           message_type,
           message_text
      FROM zpo_req_h_kar
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
        |결과 -> ReqId: { ls_result-req_id } / Status: { ls_result-status } / Ebeln: { ls_result-ebeln } / MsgType: { ls_result-message_type } / Msg: { ls_result-message_text }|
      ).
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
