CLASS zcl_testpost_job_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

ENDCLASS.



CLASS ZCL_TESTPOST_JOB_KAR IMPLEMENTATION.


  METHOD if_apj_rt_exec_object~execute.

    " 1. 전기 요청 상태인 헤더만 조회한다.
    "    사용자가 요청은 했지만 아직 실제 전표 처리가 안 된 대상이다.
    SELECT test_id,
           companycode,
           doctype,
           documentdate,
           postingdate,
           headertext,
           waers
      FROM ztest_post_h_kar
      WHERE status = '09'
      INTO TABLE @DATA(lt_headers).

    " 2. 조회된 전기 요청 건을 1건씩 처리한다.
    LOOP AT lt_headers INTO DATA(ls_header).

      " 3. 현재 헤더에 연결된 전표 라인 정보를 조회한다.
      SELECT test_id,
             glaccount,
             amount,
             itemtext,
             costcenter,
             profitcenter,
             debitcredit
        FROM ztest_post_i_kar
        WHERE test_id = @ls_header-test_id
        INTO TABLE @DATA(lt_items).

      " 4. 라인이 하나도 없으면 전표 처리 불가이므로 실패 상태로 반영한다.
      IF lt_items IS INITIAL.
        UPDATE ztest_post_h_kar
          SET status = '99'
          WHERE test_id = @ls_header-test_id.
        COMMIT WORK.
        CONTINUE.
      ENDIF.

      " 5. 공통 클래스에 넘길 라인 테이블을 준비한다.
      DATA lt_bseg TYPE zcl_testpost_comm_kar=>tt_bseg.

      " 6. 차변/대변 값을 기준으로 금액 방향을 정리한다.
      "    차변(S)은 양수, 그 외는 음수로 변환하여 표준 전표 처리 형식에 맞춘다.
      LOOP AT lt_items INTO DATA(ls_item).
        DATA(lv_amount) = COND decfloat34(
          WHEN ls_item-debitcredit = 'S'
          THEN CONV decfloat34( ls_item-amount )
          ELSE CONV decfloat34( ls_item-amount ) * -1 ).

        APPEND VALUE #(
          glaccount              = ls_item-glaccount
          journalentryitemamount = lv_amount
          documentitemtext       = ls_item-itemtext
          costcenter             = ls_item-costcenter
          profitcenter           = ls_item-profitcenter
        ) TO lt_bseg.
      ENDLOOP.

      " 7. 헤더 정보도 공통 클래스 입력 형식으로 변환한다.
      DATA(ls_bkpf) = VALUE zcl_testpost_comm_kar=>ts_bkpf(
        companycode                  = ls_header-companycode
        accountingdocumenttype       = ls_header-doctype
        documentdate                 = ls_header-documentdate
        postingdate                  = ls_header-postingdate
        accountingdocumentheadertext = ls_header-headertext
        waers                        = ls_header-waers
      ).

      DATA lv_belnr    TYPE belnr_d.
      DATA lv_gjahr    TYPE gjahr.
      DATA lt_messages TYPE bapirettab.

      " 8. 공통 클래스의 전표 전기 메서드를 호출한다.
      "    실제 표준 BO 호출과 회계전표 생성은 공통 클래스가 담당한다.
      TRY.
          zcl_testpost_comm_kar=>document_post_func(
            EXPORTING
              is_bkpf     = ls_bkpf
              it_bseg     = lt_bseg
            IMPORTING
              ev_belnr    = lv_belnr
              ev_gjahr    = lv_gjahr
              et_messages = lt_messages
          ).
        CATCH cx_root.
          " 9. 예외 발생 시 해당 요청 건은 실패 상태로 반영한다.
          UPDATE ztest_post_h_kar
            SET status = '99'
            WHERE test_id = @ls_header-test_id.
          COMMIT WORK.
          CONTINUE.
      ENDTRY.

      " 10. 전표번호가 반환되면 성공으로 판단한다.
      "     상태값과 함께 생성된 전표번호, 회계연도를 저장한다.
      IF lv_belnr IS NOT INITIAL.
        UPDATE ztest_post_h_kar
          SET status = '01',
              belnr  = @lv_belnr,
              gjahr  = @lv_gjahr
          WHERE test_id = @ls_header-test_id.
      ELSE.
        " 11. 전표번호가 없으면 실패로 보고 상태를 에러로 반영한다.
        UPDATE ztest_post_h_kar
          SET status = '99'
          WHERE test_id = @ls_header-test_id.

        " 12. 필요 시 lt_messages를 별도 로그 테이블에 저장하여
        "     실패 원인을 추적할 수 있다.
      ENDIF.

      " 13. 현재 요청 건 처리 결과를 DB에 반영한다.
      COMMIT WORK.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_apj_dt_exec_object~get_parameters.
    " 현재 이 어플리케이션 잡은 별도 입력 파라미터 없이 동작한다.
    et_parameter_def = VALUE #( ).
  ENDMETHOD.
ENDCLASS.
