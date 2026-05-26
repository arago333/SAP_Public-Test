CLASS zbpr_sd_is_log_save_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_module      TYPE c LENGTH 3.
    TYPES ty_messageguid TYPE c LENGTH 100.
    TYPES ty_inlogmsg    TYPE c LENGTH 255.
    TYPES ty_date        TYPE d.
    TYPES ty_time        TYPE c LENGTH 6.
    TYPES ty_status      TYPE c LENGTH 1.

    METHODS fetch_and_save
      IMPORTING iv_module    TYPE ty_module
                iv_statusis  TYPE ty_status OPTIONAL
                iv_date_from TYPE ty_date OPTIONAL
                iv_date_to   TYPE ty_date OPTIONAL
                iv_time_from TYPE ty_time OPTIONAL
                iv_time_to   TYPE ty_time OPTIONAL
      EXPORTING ev_ok        TYPE abap_bool
                ev_msg       TYPE string.

    METHODS update_log
      IMPORTING iv_messageguid TYPE ty_messageguid
                iv_inlog       TYPE string
                iv_inlogmsg    TYPE ty_inlogmsg.

ENDCLASS.

CLASS zbpr_sd_is_log_save_kar IMPLEMENTATION.

  METHOD fetch_and_save.

    ev_ok = abap_false.
    CLEAR ev_msg.

    " Date + Time → epoch milliseconds 변환
    DATA lv_epoch_from TYPE int8.
    DATA lv_epoch_to   TYPE int8.

    IF iv_date_from IS NOT INITIAL.
      DATA(lv_utc_from) = CONV utclong(
        |{ iv_date_from(4) }-{ iv_date_from+4(2) }-{ iv_date_from+6(2) }| &&
        |T{ COND #( WHEN iv_time_from IS NOT INITIAL THEN iv_time_from(2) ELSE '00' ) }| &&
        |:{ COND #( WHEN iv_time_from IS NOT INITIAL THEN iv_time_from+2(2) ELSE '00' ) }:00| ).
      DATA(lv_diff_from) = utclong_diff(
        high = lv_utc_from
        low  = CONV utclong( '1970-01-01 00:00:00' ) ).
      lv_epoch_from = ( CONV int8( lv_diff_from ) - 32400 ) * 1000.
    ENDIF.

    IF iv_date_to IS NOT INITIAL.
      DATA(lv_utc_to) = CONV utclong(
        |{ iv_date_to(4) }-{ iv_date_to+4(2) }-{ iv_date_to+6(2) }| &&
        |T{ COND #( WHEN iv_time_to IS NOT INITIAL THEN iv_time_to(2) ELSE '23' ) }| &&
        |:{ COND #( WHEN iv_time_to IS NOT INITIAL THEN iv_time_to+2(2) ELSE '59' ) }:59| ).
      DATA(lv_diff_to) = utclong_diff(
        high = lv_utc_to
        low  = CONV utclong( '1970-01-01 00:00:00' ) ).
      lv_epoch_to = ( CONV int8( lv_diff_to ) - 32400 ) * 1000.
    ENDIF.

    " 시간 필터
    DATA lv_time_filter TYPE string.
    IF lv_epoch_from > 0 AND lv_epoch_to > 0.
      lv_time_filter = | and LastChangeTime ge { lv_epoch_from }L and LastChangeTime le { lv_epoch_to }L|.
    ELSEIF lv_epoch_from > 0.
      lv_time_filter = | and LastChangeTime ge { lv_epoch_from }L|.
    ELSEIF lv_epoch_to > 0.
      lv_time_filter = | and LastChangeTime le { lv_epoch_to }L|.
    ENDIF.

    " StatusIS → IS API Status 필터
    DATA lv_status_filter TYPE string.
    IF iv_statusis = 'O'.
      lv_status_filter = | and Status eq 'COMPLETED'|.
    ELSEIF iv_statusis = 'X'.
      lv_status_filter = | and Status eq 'FAILED'|.
    ENDIF.

    DATA(lv_base_url) = |http/gasentec/SD0000_005| &&
                        |?$format=json| &&
                        |&$filter=substringof('{ iv_module }',IntegrationFlowName)| &&
                        | and not substringof('LOG',IntegrationFlowName)| &&
                        lv_status_filter &&
                        lv_time_filter &&
                        |&$orderby=LogStart desc|.

    TRY.
        DATA(lo_dest1) = cl_http_destination_provider=>create_by_comm_arrangement(
                           comm_scenario = 'ZCS_GAS_COMM'
                           service_id    = 'ZOB_ISLOG_REST' ).
        DATA(lo_client1) = cl_web_http_client_manager=>create_by_http_destination(
                             i_destination = lo_dest1 ).
        DATA(lo_req1) = lo_client1->get_http_request( ).
        lo_req1->set_uri_path( i_uri_path = |{ lv_base_url }&$top=100&$skip=0| ).
        DATA(lo_res1)       = lo_client1->execute( i_method = if_web_http_client=>get ).
        DATA(lv_status_005) = lo_res1->get_status( )-code.
        DATA(lv_response)   = lo_res1->get_text( ).
        lo_client1->close( ).
      CATCH cx_http_dest_provider_error
            cx_web_http_client_error INTO DATA(lx_err1).
        ev_msg = |005 ERROR: { lx_err1->get_text( ) }|.
        RETURN.
    ENDTRY.

    TYPES: BEGIN OF ty_log,
             messageguid         TYPE string,
             integrationflowname TYPE string,
             status              TYPE string,
             lastchangetime      TYPE string,
           END OF ty_log.
    TYPES: BEGIN OF ty_d,
             results TYPE STANDARD TABLE OF ty_log WITH EMPTY KEY,
           END OF ty_d.
    TYPES: BEGIN OF ty_response,
             d TYPE ty_d,
           END OF ty_response.

    DATA ls_response TYPE ty_response.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json = lv_response CHANGING data = ls_response ).
      CATCH cx_root INTO DATA(lx_json).
        ev_msg = |JSON ERROR: { lx_json->get_text( ) }|.
        RETURN.
    ENDTRY.

    IF ls_response-d-results IS INITIAL.
      ev_msg = |NO DATA TO SAVE. ROWS=0|.
      RETURN.
    ENDIF.

    " ① 내부 테이블에 전체 담기
    DATA lt_save TYPE TABLE OF zsd_is_log_kar.

    LOOP AT ls_response-d-results INTO DATA(ls_log).

      DATA(lv_seconds) = CONV decfloat34( ls_log-lastchangetime ) / 1000.
      DATA(lv_utclong) = utclong_add(
                           val     = CONV utclong( '1970-01-01 00:00:00' )
                           seconds = lv_seconds ).
      DATA lv_date TYPE d.
      DATA lv_time TYPE t.
      lv_utclong = utclong_add( val = lv_utclong seconds = 32400 ).
      CONVERT UTCLONG lv_utclong TIME ZONE 'UTC' INTO DATE lv_date TIME lv_time.

      DATA(lv_last_time) = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }| &&
                           |T{ lv_time(2) }:{ lv_time+2(2) }|.

      DATA(lv_status_is) = SWITCH #( ls_log-status
                             WHEN 'COMPLETED' THEN 'O'
                             WHEN 'FAILED'    THEN 'X'
                             ELSE ' ' ).

      APPEND VALUE zsd_is_log_kar(
        client      = sy-mandt
        messageguid = ls_log-messageguid
        statusis    = lv_status_is
        statusin    = ' '
        flowname    = ls_log-integrationflowname
        lasttime    = lv_last_time
        inlog       = ''
        inlogmsg    = ''
      ) TO lt_save.

    ENDLOOP.

    " ② DB에서 기존 건 한번에 조회
    DATA lt_existing TYPE TABLE OF zsd_is_log_kar.
    SELECT * FROM zsd_is_log_kar
      FOR ALL ENTRIES IN @lt_save
      WHERE messageguid = @lt_save-messageguid
      INTO TABLE @lt_existing.

    " ③ 신규/기존 분리
    DATA lt_new TYPE TABLE OF zsd_is_log_kar.  " 신규 건
    DATA lt_old TYPE TABLE OF zsd_is_log_kar.  " 기존 건

    LOOP AT lt_save INTO DATA(ls_save).
      READ TABLE lt_existing INTO DATA(ls_existing)
        WITH KEY messageguid = ls_save-messageguid.

      IF sy-subrc = 0.
        " 기존 건 → 기존값 유지해서 lt_old에 APPEND
        ls_save-statusin = ls_existing-statusin.
        ls_save-inlog    = ls_existing-inlog.
        ls_save-inlogmsg = ls_existing-inlogmsg.
        APPEND ls_save TO lt_old.
      ELSE.
        " 신규 건 → lt_new에 APPEND
        APPEND ls_save TO lt_new.
      ENDIF.
    ENDLOOP.

    " ④ 신규 건만 006 API 호출
    LOOP AT lt_new INTO DATA(ls_new).

      DATA lv_statusin_new  TYPE c LENGTH 1.
      DATA lv_inlog_new     TYPE string.
      DATA lv_inlogmsg_new  TYPE c LENGTH 255.

      TRY.
          DATA(lo_dest_006) = cl_http_destination_provider=>create_by_comm_arrangement(
                                comm_scenario = 'ZCS_GAS_COMM'
                                service_id    = 'ZOB_ISLOG_REST' ).
          DATA(lo_client_006) = cl_web_http_client_manager=>create_by_http_destination(
                                  i_destination = lo_dest_006 ).
          DATA(lo_req_006) = lo_client_006->get_http_request( ).
          lo_req_006->set_header_field( i_name = 'Accept' i_value = 'application/xml' ).
          lo_req_006->set_uri_path(
            i_uri_path = |http/gasentec/SD0000_006?s%28%27{ ls_new-messageguid }%27%29/Attachments| ).
          DATA(lo_res_006)  = lo_client_006->execute( i_method = if_web_http_client=>get ).
          DATA(lv_code_006) = lo_res_006->get_status( )-code.
          DATA(lv_feed_006) = lo_res_006->get_text( ).
          lo_client_006->close( ).

          IF lv_code_006 = 200.

            DATA lv_attach_id_save TYPE string.
            DATA lt_entries_006    TYPE STANDARD TABLE OF string WITH EMPTY KEY.
            DATA lv_entry_006      TYPE string.
            DATA lv_src_pos_save   TYPE i.
            DATA lv_start_save     TYPE i.
            DATA lv_end_save       TYPE i.
            DATA lv_tail_save      TYPE string.

            SPLIT lv_feed_006 AT '<entry>' INTO TABLE lt_entries_006.

            " ① 성공: Log : END - Body 또는 Log : Response
            LOOP AT lt_entries_006 INTO lv_entry_006.
              IF lv_entry_006 CS '<d:Name>Log : END - Body</d:Name>'
              OR lv_entry_006 CS '<d:Name>Log : Response</d:Name>'.
                lv_statusin_new = 'O'.
                FIND FIRST OCCURRENCE OF '<d:Id>' IN lv_entry_006 MATCH OFFSET lv_src_pos_save.
                IF sy-subrc = 0.
                  lv_start_save = lv_src_pos_save + 6.
                  lv_tail_save  = lv_entry_006+lv_start_save.
                  FIND FIRST OCCURRENCE OF '</d:Id>' IN lv_tail_save MATCH OFFSET lv_end_save.
                  IF sy-subrc = 0.
                    lv_attach_id_save = lv_tail_save(lv_end_save).
                  ENDIF.
                ENDIF.
                EXIT.
              ENDIF.
            ENDLOOP.

            " ② fallback: HTTP_Receiver_Adapter_Response_Body
            IF lv_attach_id_save IS INITIAL.
              LOOP AT lt_entries_006 INTO lv_entry_006.
                IF lv_entry_006 CS '<d:Name>HTTP_Receiver_Adapter_Response_Body</d:Name>'.
                  lv_statusin_new = 'X'.
                  FIND FIRST OCCURRENCE OF '<d:Id>' IN lv_entry_006 MATCH OFFSET lv_src_pos_save.
                  IF sy-subrc = 0.
                    lv_start_save = lv_src_pos_save + 6.
                    lv_tail_save  = lv_entry_006+lv_start_save.
                    FIND FIRST OCCURRENCE OF '</d:Id>' IN lv_tail_save MATCH OFFSET lv_end_save.
                    IF sy-subrc = 0.
                      lv_attach_id_save = lv_tail_save(lv_end_save).
                    ENDIF.
                  ENDIF.
                  EXIT.
                ENDIF.
              ENDLOOP.
            ENDIF.

            " $value 조회
            IF lv_attach_id_save IS NOT INITIAL.
              DATA(lo_dest_val) = cl_http_destination_provider=>create_by_comm_arrangement(
                                    comm_scenario = 'ZCS_GAS_COMM'
                                    service_id    = 'ZOB_ISLOG_REST' ).
              DATA(lo_client_val) = cl_web_http_client_manager=>create_by_http_destination(
                                      i_destination = lo_dest_val ).
              DATA(lo_req_val) = lo_client_val->get_http_request( ).
              lo_req_val->set_header_field( i_name = 'Accept' i_value = 'text/plain' ).
              lo_req_val->set_uri_path(
                i_uri_path = |http/gasentec/SD0000_006?Attachments%28%27{ lv_attach_id_save }%27%29/%24value| ).
              DATA(lo_res_val)  = lo_client_val->execute( i_method = if_web_http_client=>get ).
              DATA(lv_code_val) = lo_res_val->get_status( )-code.
              lv_inlog_new = lo_res_val->get_text( ).
              lo_client_val->close( ).

              IF lv_code_val = 200.
                lv_inlogmsg_new = SWITCH #( lv_statusin_new
                  WHEN 'O' THEN 'Log fetched successfully'
                  WHEN 'X' THEN 'Internal process failed'
                  ELSE 'Log fetched' ).
              ELSE.
                lv_inlogmsg_new = |HTTP Status { lv_code_val }|.
              ENDIF.
            ELSE.
              lv_statusin_new = ' '.
              lv_inlogmsg_new = 'Log : END - Body not found'.
              lv_inlog_new    = lv_feed_006.
            ENDIF.

          ELSE.
            lv_statusin_new = ' '.
            lv_inlogmsg_new = |HTTP Status { lv_code_006 }|.
            lv_inlog_new    = lv_feed_006.
          ENDIF.

        CATCH cx_http_dest_provider_error
              cx_web_http_client_error INTO DATA(lx_006).
          lv_statusin_new = ' '.
          lv_inlogmsg_new = lx_006->get_text( ).
      ENDTRY.

      ls_new-statusin = lv_statusin_new.
      ls_new-inlog    = lv_inlog_new.
      ls_new-inlogmsg = lv_inlogmsg_new.
      APPEND ls_new TO lt_old.  " ← 최종 테이블에 APPEND

    ENDLOOP.

    " ⑤ 한번에 DB 저장
    MODIFY zsd_is_log_kar FROM TABLE @lt_old.
    IF sy-subrc = 0.
      ev_ok  = abap_true.
      ev_msg = |SAVE OK. ROWS={ lines( lt_old ) }|.
    ELSE.
      ev_msg = |SAVE FAIL. SY-SUBRC={ sy-subrc }|.
    ENDIF.

  ENDMETHOD.

  METHOD update_log.
    UPDATE zsd_is_log_kar
      SET inlog    = @iv_inlog,
          inlogmsg = @iv_inlogmsg
      WHERE messageguid = @iv_messageguid.
  ENDMETHOD.

ENDCLASS.
