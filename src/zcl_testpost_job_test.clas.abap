CLASS zcl_testpost_job_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS ZCL_TESTPOST_JOB_TEST IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    " 1. 전기 대기건(Status = '09') 확인
    SELECT test_id,
           status,
           companycode,
           doctype
      FROM ztest_post_h_kar
      WHERE status = '09'
      INTO TABLE @DATA(lt_pending).

    out->write( |Status 09 건수: { lines( lt_pending ) }| ).

    IF lt_pending IS INITIAL.
      out->write( '전기 대기건이 없습니다.' ).
      RETURN.
    ENDIF.

    LOOP AT lt_pending INTO DATA(ls_pending).
      out->write(
        |대기건 -> TestId: { ls_pending-test_id } / CompanyCode: { ls_pending-companycode } / DocType: { ls_pending-doctype }|
      ).
    ENDLOOP.

    " 2. 잡 클래스 직접 실행
    TRY.
        DATA(lo_job) = NEW zcl_testpost_job_kar( ).

        " zcl_testpost_job_kar 가 IF_APJ_RT_EXEC_OBJECT 인 경우
        lo_job->if_apj_rt_exec_object~execute(
          it_parameters = VALUE #( )
        ).

        " zcl_testpost_job_kar 가 IF_APJ_RT_RUN 인 경우에는 위 한 줄 대신 아래 사용
        " lo_job->if_apj_rt_run~execute( ).

        out->write( '잡 실행 완료' ).

      CATCH cx_apj_rt_content INTO DATA(lx_apj).
        out->write( |APJ 오류: { lx_apj->get_text( ) }| ).
        RETURN.

      CATCH cx_root INTO DATA(lx_root).
        out->write( |일반 오류: { lx_root->get_text( ) }| ).
        RETURN.
    ENDTRY.

    " 3. 방금 조회한 대기건의 처리 결과 확인
    SELECT test_id,
           status,
           belnr,
           gjahr
      FROM ztest_post_h_kar
      FOR ALL ENTRIES IN @lt_pending
      WHERE test_id = @lt_pending-test_id
      INTO TABLE @DATA(lt_result).

    IF lt_result IS INITIAL.
      out->write( '처리 결과 조회 건이 없습니다.' ).
      RETURN.
    ENDIF.

    SORT lt_result BY test_id.

    LOOP AT lt_result INTO DATA(ls_result).
      out->write(
        |결과 -> TestId: { ls_result-test_id } / Status: { ls_result-status } / Belnr: { ls_result-belnr } / Gjahr: { ls_result-gjahr }|
      ).
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
