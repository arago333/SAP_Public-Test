CLASS zcl_po_job_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
ENDCLASS.


CLASS zcl_po_job_kar IMPLEMENTATION.

  METHOD if_apj_rt_exec_object~execute.

    " 책임: 09(대기) 건을 정확히 한 번 처리
    " 03(처리중) stale 복구는 zcl_po_recovery_job_kar 에서 담당

    CONSTANTS: lc_status_wait       TYPE c LENGTH 2 VALUE '09',
               lc_status_processing TYPE c LENGTH 2 VALUE '03',
               lc_status_success    TYPE c LENGTH 2 VALUE '01',
               lc_status_check      TYPE c LENGTH 2 VALUE '05',
               lc_status_error      TYPE c LENGTH 2 VALUE '99'.

    TYPES: BEGIN OF ts_header,
             req_id                  TYPE sysuuid_c22,
             companycode             TYPE bukrs,
             supplier                TYPE lifnr,
             purchasingorganization  TYPE ekorg,
             purchasinggroup         TYPE ekgrp,
             purchaseordertype       TYPE c LENGTH 4,
             documentcurrency        TYPE waers,
             purchaseorderdate       TYPE datum,
             paymentterms            TYPE dzterm,
             incotermsclassification TYPE c LENGTH 3,
             incotermslocation1      TYPE c LENGTH 70,
           END OF ts_header.

    DATA lt_headers TYPE TABLE OF ts_header WITH EMPTY KEY.

    SELECT req_id,
           companycode,
           supplier,
           purchasingorganization,
           purchasinggroup,
           purchaseordertype,
           documentcurrency,
           purchaseorderdate,
           paymentterms,
           incotermsclassification,
           incotermslocation1
      FROM zpo_req_h_kar
      WHERE status = @lc_status_wait
      INTO TABLE @lt_headers.

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ts_item,
             req_id                    TYPE sysuuid_c22,
             purchaseorderitem         TYPE ebelp,
             material                  TYPE matnr,
             plant                     TYPE werks_d,
             storagelocation           TYPE lgort_d,
             orderquantity             TYPE p LENGTH 8 DECIMALS 3,
             purchaseorderquantityunit TYPE c LENGTH 3,
             netpriceamount            TYPE p LENGTH 8 DECIMALS 2,
             taxcode                   TYPE mwskz,
             purchaseorderitemtext     TYPE txz01,
           END OF ts_item.

    DATA lt_all_items TYPE TABLE OF ts_item WITH EMPTY KEY.

    SELECT req_id,
           purchaseorderitem,
           material,
           plant,
           storagelocation,
           orderquantity,
           purchaseorderquantityunit,
           netpriceamount,
           taxcode,
           purchaseorderitemtext
      FROM zpo_req_i_kar
      FOR ALL ENTRIES IN @lt_headers
      WHERE req_id = @lt_headers-req_id
      INTO TABLE @lt_all_items.

    DATA lt_po_item       TYPE zcl_po_comm_kar=>tt_po_item.
    DATA ls_result        TYPE zcl_po_comm_kar=>ts_result.
    DATA lv_msg_type      TYPE c LENGTH 1.
    DATA lv_msg_text      TYPE c LENGTH 255.
    DATA lv_timestamp     TYPE abp_lastchange_tstmpl.
    DATA lv_full_msg      TYPE string.
    DATA lv_fail_msg      TYPE string.
    DATA lv_fail_msg_chk  TYPE string.
    DATA lv_exception_msg TYPE string.

    LOOP AT lt_headers INTO DATA(ls_header).

      CLEAR: lt_po_item,
             ls_result,
             lv_msg_type,
             lv_msg_text,
             lv_timestamp,
             lv_full_msg,
             lv_fail_msg,
             lv_fail_msg_chk,
             lv_exception_msg.

      GET TIME STAMP FIELD lv_timestamp.

      " ① 선점: 다른 잡이 이미 집었으면 CONTINUE
      UPDATE zpo_req_h_kar
        SET status          = @lc_status_processing,
            last_changed_by = @sy-uname,
            last_changed_at = @lv_timestamp
        WHERE req_id = @ls_header-req_id
          AND status = @lc_status_wait.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      COMMIT WORK.  " 선점 즉시 확정

      " ② 건별 TRY...CATCH: 예상 못 한 런타임 예외만 담당
      " 상태 반영 실패는 비즈니스/운영 오류로 직접 처리
      TRY.

          " ③ 아이템 필터링
          " netpriceamount_is_supplied: DB 값이 0이 아니면 명시 전송으로 간주
          " 0원을 의도적으로 보내야 하는 케이스가 생기면 DB에 supplied 컬럼 추가 필요
          lt_po_item = VALUE #(
            FOR ls_item IN lt_all_items
            WHERE ( req_id = ls_header-req_id )
            ( purchaseorderitem          = ls_item-purchaseorderitem
              material                   = ls_item-material
              plant                      = ls_item-plant
              storagelocation            = ls_item-storagelocation
              orderquantity              = ls_item-orderquantity
              purchaseorderquantityunit  = ls_item-purchaseorderquantityunit
              netpriceamount             = ls_item-netpriceamount
              netpriceamount_is_supplied = xsdbool( ls_item-netpriceamount <> 0 )
              taxcode                    = ls_item-taxcode
              purchaseorderitemtext      = ls_item-purchaseorderitemtext )
          ).

          " ④ 아이템 없으면 즉시 실패 처리
          IF lt_po_item IS INITIAL.
            GET TIME STAMP FIELD lv_timestamp.
            UPDATE zpo_req_h_kar
              SET status          = @lc_status_error,
                  message_type    = 'E',
                  message_text    = '아이템 데이터가 없습니다.',
                  last_changed_by = @sy-uname,
                  last_changed_at = @lv_timestamp
              WHERE req_id = @ls_header-req_id.

            COMMIT WORK.
            CONTINUE.
          ENDIF.

          " ⑤ 헤더 구조 세팅
          DATA(ls_po_header) = VALUE zcl_po_comm_kar=>ts_po_header(
            companycode             = ls_header-companycode
            supplier                = ls_header-supplier
            purchasingorganization  = ls_header-purchasingorganization
            purchasinggroup         = ls_header-purchasinggroup
            purchaseordertype       = ls_header-purchaseordertype
            documentcurrency        = ls_header-documentcurrency
            purchaseorderdate       = ls_header-purchaseorderdate
            paymentterms            = ls_header-paymentterms
            incotermsclassification = ls_header-incotermsclassification
            incotermslocation1      = ls_header-incotermslocation1
          ).

          " ⑥ PO 생성 실행
          ls_result = zcl_po_comm_kar=>create_purchase_order(
            is_header = ls_po_header
            it_item   = lt_po_item
          ).

          " ⑦ 메시지 타입 우선순위 결정 (E/A/X > W > S > I)
          IF line_exists( ls_result-messages[ type = 'E' ] )
          OR line_exists( ls_result-messages[ type = 'A' ] )
          OR line_exists( ls_result-messages[ type = 'X' ] ).
            lv_msg_type = 'E'.
          ELSEIF line_exists( ls_result-messages[ type = 'W' ] ).
            lv_msg_type = 'W'.
          ELSEIF line_exists( ls_result-messages[ type = 'S' ] ).
            lv_msg_type = 'S'.
          ELSE.
            lv_msg_type = 'I'.
          ENDIF.

          " ⑧ 메시지 텍스트 이어붙이기 (255자 명시적 자르기)
          IF ls_result-messages IS NOT INITIAL.
            lv_full_msg = concat_lines_of(
              table = VALUE string_table(
                FOR ls_msg IN ls_result-messages ( ls_msg-message )
              )
              sep = ' | '
            ).

            IF strlen( lv_full_msg ) > 255.
              lv_msg_text = lv_full_msg+0(255).
            ELSE.
              lv_msg_text = lv_full_msg.
            ENDIF.
          ENDIF.

          " ⑨ 결과 기준 상태 분기
          " 01: success = true AND ebeln 확보
          " 05: committed = true + ebeln 미확보 (success=true + ebeln 미확보 포함)
          " 99: MODIFY 또는 COMMIT 실패
          GET TIME STAMP FIELD lv_timestamp.

          IF ls_result-success = abap_true AND ls_result-ebeln IS NOT INITIAL.

            UPDATE zpo_req_h_kar
              SET status          = @lc_status_success,
                  ebeln           = @ls_result-ebeln,
                  message_type    = @lv_msg_type,
                  message_text    = @lv_msg_text,
                  last_changed_by = @sy-uname,
                  last_changed_at = @lv_timestamp
              WHERE req_id = @ls_header-req_id.

            IF sy-subrc <> 0.
              lv_fail_msg = |PO { ls_result-ebeln } 생성 후 상태 반영 실패 (req_id: { ls_header-req_id })|.

              UPDATE zpo_req_h_kar
                SET status          = @lc_status_error,
                    message_type    = 'E',
                    message_text    = @lv_fail_msg,
                    last_changed_by = @sy-uname,
                    last_changed_at = @lv_timestamp
                WHERE req_id = @ls_header-req_id.
            ENDIF.

          ELSEIF ls_result-committed = abap_true.

            UPDATE zpo_req_h_kar
              SET status          = @lc_status_check,
                  message_type    = @lv_msg_type,
                  message_text    = @lv_msg_text,
                  last_changed_by = @sy-uname,
                  last_changed_at = @lv_timestamp
              WHERE req_id = @ls_header-req_id.

            IF sy-subrc <> 0.
              lv_fail_msg_chk = |PO 생성(번호 미확보) 후 상태 반영 실패 (req_id: { ls_header-req_id })|.

              UPDATE zpo_req_h_kar
                SET status          = @lc_status_error,
                    message_type    = 'E',
                    message_text    = @lv_fail_msg_chk,
                    last_changed_by = @sy-uname,
                    last_changed_at = @lv_timestamp
                WHERE req_id = @ls_header-req_id.
            ENDIF.

          ELSE.

            UPDATE zpo_req_h_kar
              SET status          = @lc_status_error,
                  message_type    = @lv_msg_type,
                  message_text    = @lv_msg_text,
                  last_changed_by = @sy-uname,
                  last_changed_at = @lv_timestamp
              WHERE req_id = @ls_header-req_id.

          ENDIF.

          COMMIT WORK.  " 건별 확정

        CATCH cx_root INTO DATA(lx_err).
          " 예상 못 한 런타임 예외: 03 → 99 강등, 영구 걸림 방지
          GET TIME STAMP FIELD lv_timestamp.
          lv_exception_msg = |예외 발생: { lx_err->get_text( ) }|.

          UPDATE zpo_req_h_kar
            SET status          = @lc_status_error,
                message_type    = 'E',
                message_text    = @lv_exception_msg,
                last_changed_by = @sy-uname,
                last_changed_at = @lv_timestamp
            WHERE req_id = @ls_header-req_id.

          COMMIT WORK.
      ENDTRY.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( ).
  ENDMETHOD.

ENDCLASS.

