CLASS zcl_so_job_test_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS ZCL_SO_JOB_TEST_KAR IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    " 테스트 데이터 INSERT 먼저 확인
    SELECT req_id, status, salesordertype, soldtoparty
      FROM zsso_req_h_kar
      WHERE status = '09'
      INTO TABLE @DATA(lt_pending).

    out->write( |대기건 수: { lines( lt_pending ) }| ).

    IF lt_pending IS INITIAL.
      out->write( '판매오더 생성 대기건이 없습니다.' ).
      RETURN.
    ENDIF.

    LOOP AT lt_pending INTO DATA(ls_pending).
      out->write( |대기건 → ReqId: { ls_pending-req_id } / OrderType: { ls_pending-salesordertype }| ).
    ENDLOOP.

    " Job 실행
    TRY.
        DATA(lo_job) = NEW zcl_so_job_kar( ).
        lo_job->if_apj_rt_exec_object~execute(
          it_parameters = VALUE #( )
        ).
        out->write( '판매오더 Application Job 실행 완료' ).
      CATCH cx_apj_rt_content INTO DATA(lx_apj).
        out->write( |APJ 오류: { lx_apj->get_text( ) }| ).
        RETURN.
      CATCH cx_root INTO DATA(lx_root).
        out->write( |일반 오류: { lx_root->get_text( ) }| ).
        RETURN.
    ENDTRY.

    " 결과 재조회
    SELECT req_id, status, vbeln, message_type, message_text
      FROM zsso_req_h_kar
      FOR ALL ENTRIES IN @lt_pending
      WHERE req_id = @lt_pending-req_id
      INTO TABLE @DATA(lt_result).

    LOOP AT lt_result INTO DATA(ls_result).
      out->write(
        |결과 → ReqId: { ls_result-req_id } / Status: { ls_result-status } / Vbeln: { ls_result-vbeln } / Msg: { ls_result-message_text }|
      ).
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
