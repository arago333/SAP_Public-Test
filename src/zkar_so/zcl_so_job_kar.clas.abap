CLASS zcl_so_job_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " if_apj_dt_exec_object : 잡 파라미터 정의 (Design Time)
    " if_apj_rt_exec_object : 잡 실제 실행 로직 (Run Time)
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
ENDCLASS.




CLASS zcl_so_job_kar IMPLEMENTATION.
  METHOD if_apj_rt_exec_object~execute.

    CONSTANTS:
      lc_status_wait    TYPE c LENGTH 2 VALUE '09',
      lc_status_success TYPE c LENGTH 2 VALUE '01',
      lc_status_check   TYPE c LENGTH 2 VALUE '05',
      lc_status_error   TYPE c LENGTH 2 VALUE '99'.

    DATA lt_headers   TYPE TABLE OF zsso_req_h_kar WITH EMPTY KEY.
    DATA lt_all_items TYPE TABLE OF zsso_req_i_kar WITH EMPTY KEY.

    "--------------------------------------------------------------------
    " ① 대기건 헤더 SELECT — UP TO 1 ROWS
    "    I_SalesOrderTP 는 한 세션에 1건만 처리 가능
    "    스케줄러에서 짧은 주기로 반복 실행하는 구조로 운영
    "--------------------------------------------------------------------
    SELECT req_id,
           salesordertype,
           salesorganization,
           distributionchannel,
           organizationdivision,
           soldtoparty,
           purchaseorderbycustomer,
           requesteddeliverydate
      FROM zsso_req_h_kar
      WHERE status = @lc_status_wait
      ORDER BY created_at ASCENDING  " 오래된 건 먼저 처리
      INTO CORRESPONDING FIELDS OF TABLE @lt_headers
      UP TO 1 ROWS.                  " ← 1건만

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    SELECT req_id,
           req_item_no,
           salesorderitem,
           product,
           requestedquantity,
           requestedquantityunit,
           plant,
           salesorderitemtext
      FROM zsso_req_i_kar
      FOR ALL ENTRIES IN @lt_headers
      WHERE req_id = @lt_headers-req_id
      INTO CORRESPONDING FIELDS OF TABLE @lt_all_items.

    DATA ls_header    TYPE zcl_so_comm_kar=>ts_so_header.
    DATA lt_items     TYPE zcl_so_comm_kar=>tt_so_item.
    DATA ls_result    TYPE zcl_so_comm_kar=>ts_result.
    DATA lv_timestamp TYPE timestampl.
    DATA lv_status    TYPE c LENGTH 2.
    DATA lv_msg_type  TYPE c LENGTH 1.
    DATA lv_msg_text  TYPE c LENGTH 255.

    "--------------------------------------------------------------------
    " ② 단건 처리 (LOOP지만 실제로 1건만 실행됨)
    "--------------------------------------------------------------------
    LOOP AT lt_headers INTO DATA(ls_req_header).

      CLEAR: ls_header, lt_items, ls_result,
             lv_timestamp, lv_status, lv_msg_type, lv_msg_text.

      GET TIME STAMP FIELD lv_timestamp.

      " 처리 시작 즉시 05로 변경 시도
      UPDATE zsso_req_h_kar
        SET status          = '05',
            last_changed_by = @sy-uname,
            last_changed_at = @lv_timestamp
        WHERE req_id = @ls_req_header-req_id
        AND status = @lc_status_wait.  " ← status가 09일 때만 UPDATE

      " UPDATE 된 행이 없으면 이미 다른 프로세스가 가져간 것
      IF sy-dbcnt = 0.
        CONTINUE.
      ENDIF.

      COMMIT WORK.

      lt_items = VALUE #(
        FOR ls_req_item IN lt_all_items
        WHERE ( req_id = ls_req_header-req_id )
        (
          salesorderitem        = ls_req_item-salesorderitem
          product               = ls_req_item-product
          requestedquantity     = ls_req_item-requestedquantity
          requestedquantityunit = ls_req_item-requestedquantityunit
          plant                 = ls_req_item-plant
          salesorderitemtext    = ls_req_item-salesorderitemtext
        )
      ).

      IF lt_items IS INITIAL.
        UPDATE zsso_req_h_kar
          SET status          = @lc_status_error,
              message_type    = 'E',
              message_text    = '아이템 데이터가 없습니다.',
              last_changed_by = @sy-uname,
              last_changed_at = @lv_timestamp
          WHERE req_id = @ls_req_header-req_id.
        CONTINUE.
      ENDIF.

      ls_header = VALUE #(
        salesordertype          = ls_req_header-salesordertype
        salesorganization       = ls_req_header-salesorganization
        distributionchannel     = ls_req_header-distributionchannel
        organizationdivision    = ls_req_header-organizationdivision
        soldtoparty             = ls_req_header-soldtoparty
        purchaseorderbycustomer = ls_req_header-purchaseorderbycustomer
        requesteddeliverydate   = ls_req_header-requesteddeliverydate
      ).

      ls_result = zcl_so_comm_kar=>create_sales_order(
        is_header = ls_header
        it_item   = lt_items
      ).

      IF line_exists( ls_result-messages[ type = 'E' ] ).
        lv_status = lc_status_error.
      ELSEIF ls_result-vbeln IS NOT INITIAL.
        lv_status = lc_status_success.
      ELSE.
        lv_status = lc_status_check.
      ENDIF.

      IF ls_result-messages IS NOT INITIAL.
        DATA(lv_full_msg) = concat_lines_of(
          table = VALUE string_table(
            FOR ls_msg IN ls_result-messages ( CONV string( ls_msg-message ) )
          )
          sep = ' | '
        ).
        IF strlen( lv_full_msg ) > 255.
          lv_msg_text = lv_full_msg+0(255).
        ELSE.
          lv_msg_text = lv_full_msg.
        ENDIF.
      ENDIF.

      lv_msg_type = SWITCH #( lv_status
        WHEN lc_status_success THEN 'S'
        WHEN lc_status_error   THEN 'E'
        ELSE                        'W' ).

      IF lv_status = lc_status_success.
        UPDATE zsso_req_h_kar
          SET status          = @lc_status_success,
              vbeln           = @ls_result-vbeln,
              message_type    = @lv_msg_type,
              message_text    = @lv_msg_text,
              last_changed_by = @sy-uname,
              last_changed_at = @lv_timestamp
          WHERE req_id = @ls_req_header-req_id.
      ELSEIF lv_status = lc_status_check.
        UPDATE zsso_req_h_kar
          SET status          = @lc_status_check,
              message_type    = @lv_msg_type,
              message_text    = @lv_msg_text,
              last_changed_by = @sy-uname,
              last_changed_at = @lv_timestamp
          WHERE req_id = @ls_req_header-req_id.
      ELSE.
        UPDATE zsso_req_h_kar
          SET status          = @lc_status_error,
              message_type    = @lv_msg_type,
              message_text    = @lv_msg_text,
              last_changed_by = @sy-uname,
              last_changed_at = @lv_timestamp
          WHERE req_id = @ls_req_header-req_id.
      ENDIF.

    ENDLOOP.

    COMMIT WORK.

  ENDMETHOD.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( ).
  ENDMETHOD.

ENDCLASS.
