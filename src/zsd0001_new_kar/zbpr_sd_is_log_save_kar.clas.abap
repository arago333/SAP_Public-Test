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
                iv_date_from TYPE ty_date   OPTIONAL
                iv_date_to   TYPE ty_date   OPTIONAL
                iv_time_from TYPE ty_time   OPTIONAL
                iv_time_to   TYPE ty_time   OPTIONAL
      EXPORTING ev_ok        TYPE abap_bool
                ev_msg       TYPE string.

    METHODS update_log
      IMPORTING iv_messageguid TYPE ty_messageguid
                iv_inlog       TYPE string
                iv_inlogmsg    TYPE ty_inlogmsg.

    METHODS get_attach_id
      IMPORTING iv_messageguid TYPE ty_messageguid
      EXPORTING ev_attach_id   TYPE string
                ev_statusin    TYPE ty_status.

  PRIVATE SECTION.

ENDCLASS.



CLASS ZBPR_SD_IS_LOG_SAVE_KAR IMPLEMENTATION.


  METHOD fetch_and_save.

    ev_ok = abap_false.

    " ── epoch 변환 (KST → UTC milliseconds) ──────────────────
    DATA lv_epoch_from TYPE int8.
    DATA lv_epoch_to   TYPE int8.

    IF iv_date_from IS NOT INITIAL.
      DATA(lv_utc_from) = CONV utclong(
        |{ iv_date_from(4) }-{ iv_date_from+4(2) }-{ iv_date_from+6(2) }| &&
        |T{ COND #( WHEN iv_time_from IS NOT INITIAL THEN iv_time_from(2)   ELSE '00' ) }| &&
        |:{ COND #( WHEN iv_time_from IS NOT INITIAL THEN iv_time_from+2(2) ELSE '00' ) }:00| ).
      lv_epoch_from = CONV int8( utclong_diff(
        high = lv_utc_from
        low  = CONV utclong( '1970-01-01 00:00:00' ) ) ) * 1000.
    ENDIF.

    IF iv_date_to IS NOT INITIAL.
      DATA(lv_utc_to) = CONV utclong(
        |{ iv_date_to(4) }-{ iv_date_to+4(2) }-{ iv_date_to+6(2) }| &&
        |T{ COND #( WHEN iv_time_to IS NOT INITIAL THEN iv_time_to(2)   ELSE '23' ) }| &&
        |:{ COND #( WHEN iv_time_to IS NOT INITIAL THEN iv_time_to+2(2) ELSE '59' ) }:59| ).
      lv_epoch_to = CONV int8( utclong_diff(
        high = lv_utc_to
        low  = CONV utclong( '1970-01-01 00:00:00' ) ) ) * 1000.
    ENDIF.

    " ── IS API 005 필터 URL 조립 ──────────────────────────────
    DATA(lv_time_filter) = COND string(
      WHEN lv_epoch_from > 0 AND lv_epoch_to > 0
        THEN | and LastChangeTime ge { lv_epoch_from }L and LastChangeTime le { lv_epoch_to }L|
      WHEN lv_epoch_from > 0
        THEN | and LastChangeTime ge { lv_epoch_from }L|
      WHEN lv_epoch_to > 0
        THEN | and LastChangeTime le { lv_epoch_to }L|
      ELSE `` ).

    DATA(lv_status_filter) = COND string(
      WHEN iv_statusis = 'O' THEN | and Status eq 'COMPLETED'|
      WHEN iv_statusis = 'X' THEN | and Status eq 'FAILED'|
      ELSE `` ).

    DATA(lv_base_url) = |http/gasentec/SD0000_005| &&
                        |?$format=json| &&
                        |&$inlinecount=allpages| &&
                        |&$filter=substringof('{ iv_module }',IntegrationFlowName)| &&
                        | and not substringof('LOG',IntegrationFlowName)| &&
                        lv_status_filter &&
                        lv_time_filter &&
                        |&$orderby=LogStart desc|.

    " ── 005 페이징 루프 ───────────────────────────────────────
    TYPES: BEGIN OF ty_log,
             messageguid         TYPE string,
             integrationflowname TYPE string,
             status              TYPE string,
             lastchangetime      TYPE string,
           END OF ty_log.
    TYPES: BEGIN OF ty_d,
             results TYPE STANDARD TABLE OF ty_log WITH EMPTY KEY,
             __count TYPE string,
           END OF ty_d.
    TYPES: BEGIN OF ty_response,
             d TYPE ty_d,
           END OF ty_response.

    DATA ls_response    TYPE ty_response.
    DATA lt_save_page   TYPE TABLE OF zsd_is_log_kar.
    DATA lv_skip        TYPE i VALUE 0.
    DATA lv_top         TYPE i VALUE 100.
    DATA lv_total_count TYPE i VALUE 0.
    DATA lv_page        TYPE i VALUE 1.

    DO.
      CLEAR ls_response.
      CLEAR lt_save_page.

      " ── 005 API 호출 ──────────────────────────────────────
      TRY.
          DATA(lo_dest1)    = cl_http_destination_provider=>create_by_comm_arrangement(
                                comm_scenario = 'ZCS_GAS_COMM'
                                service_id    = 'ZOB_ISLOG_REST' ).
          DATA(lo_client1)  = cl_web_http_client_manager=>create_by_http_destination(
                                i_destination = lo_dest1 ).
          DATA(lo_req1)     = lo_client1->get_http_request( ).
          lo_req1->set_uri_path(
            i_uri_path = |{ lv_base_url }&$top={ lv_top }&$skip={ lv_skip }| ).
          DATA(lo_res1)     = lo_client1->execute( i_method = if_web_http_client=>get ).
          DATA(lv_response) = lo_res1->get_text( ).
          lo_client1->close( ).
        CATCH cx_http_dest_provider_error
              cx_web_http_client_error INTO DATA(lx_005).
          ev_msg = |005 ERROR: { lx_005->get_text( ) }|.
          RETURN.
      ENDTRY.

      TRY.
          /ui2/cl_json=>deserialize( EXPORTING json = lv_response CHANGING data = ls_response ).
        CATCH cx_root INTO DATA(lx_json).
          ev_msg = |JSON ERROR: { lx_json->get_text( ) }|.
          RETURN.
      ENDTRY.

      " 첫 페이지에서 전체 건수 파악
      IF lv_page = 1.
        lv_total_count = ls_response-d-__count.
      ENDIF.

      " 결과 없으면 루프 종료
      IF ls_response-d-results IS INITIAL.
        EXIT.
      ENDIF.

      " ── 005 결과 → lt_save_page 변환 ─────────────────────
      LOOP AT ls_response-d-results INTO DATA(ls_log).
        DATA(lv_seconds) = CONV decfloat34( ls_log-lastchangetime ) / 1000.
        DATA(lv_utclong) = utclong_add(
                             val     = CONV utclong( '1970-01-01 00:00:00' )
                             seconds = lv_seconds ).
        lv_utclong = utclong_add( val = lv_utclong seconds = 32400 ).
        CONVERT UTCLONG lv_utclong TIME ZONE 'UTC'
                INTO DATE DATA(lv_date) TIME DATA(lv_time).

        APPEND VALUE zsd_is_log_kar(
          client      = sy-mandt
          messageguid = ls_log-messageguid
          statusis    = SWITCH #( ls_log-status
                          WHEN 'COMPLETED' THEN 'O'
                          WHEN 'FAILED'    THEN 'X'
                          ELSE ' ' )
          statusin    = ' '
          flowname    = ls_log-integrationflowname
          lasttime    = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }T{ lv_time(2) }:{ lv_time+2(2) }|
          inlog       = ``
          inlogmsg    = COND #( WHEN ls_log-status = 'FAILED' THEN 'IS process failed'
                                ELSE                               'Pending' )
        ) TO lt_save_page.
      ENDLOOP.

      " ── 신규 건만 INSERT (기존 건 키 중복 시 자동 스킵) ───
      INSERT zsd_is_log_kar FROM TABLE @lt_save_page
        ACCEPTING DUPLICATE KEYS.

      " 다음 페이지 계산
      lv_skip = lv_skip + lv_top.
      lv_page = lv_page + 1.

      " 전체 건수 도달 시 종료
      IF lv_skip >= lv_total_count.
        EXIT.
      ENDIF.

    ENDDO.

    ev_ok  = abap_true.
    ev_msg = |SAVE OK. TOTAL={ lv_total_count }|.

  ENDMETHOD.


  METHOD get_attach_id.

    ev_attach_id = ``.
    ev_statusin  = ' '.

    TRY.
        DATA(lo_dest)   = cl_http_destination_provider=>create_by_comm_arrangement(
                            comm_scenario = 'ZCS_GAS_COMM'
                            service_id    = 'ZOB_ISLOG_REST' ).
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                            i_destination = lo_dest ).
        DATA(lo_req)    = lo_client->get_http_request( ).
        lo_req->set_header_field( i_name = 'Accept' i_value = 'application/xml' ).
        lo_req->set_uri_path(
          i_uri_path = |http/gasentec/SD0000_006?s%28%27{ iv_messageguid }%27%29/Attachments| ).
        DATA(lo_res)  = lo_client->execute( i_method = if_web_http_client=>get ).
        DATA(lv_code) = lo_res->get_status( )-code.
        DATA(lv_feed) = lo_res->get_text( ).
        lo_client->close( ).
      CATCH cx_http_dest_provider_error
            cx_web_http_client_error INTO DATA(lx).
        ev_statusin = ' '.
        RETURN.
    ENDTRY.

    IF lv_code <> 200.
      ev_statusin = ' '.
      RETURN.
    ENDIF.

    DATA lt_entries TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    SPLIT lv_feed AT '<entry>' INTO TABLE lt_entries.

    " ① 성공: Log : END - Body / Log : Response → O
    LOOP AT lt_entries INTO DATA(lv_entry).
      IF lv_entry CS '<d:Name>Log : END - Body</d:Name>'
      OR lv_entry CS '<d:Name>Log : Response</d:Name>'.
        ev_statusin = 'O'.
        FIND FIRST OCCURRENCE OF '<d:Id>' IN lv_entry MATCH OFFSET DATA(lv_pos).
        IF sy-subrc = 0.
          DATA(lv_start) = lv_pos + 6.
          DATA(lv_tail)  = lv_entry+lv_start.
          FIND FIRST OCCURRENCE OF '</d:Id>' IN lv_tail MATCH OFFSET DATA(lv_end).
          IF sy-subrc = 0.
            ev_attach_id = lv_tail(lv_end).
          ENDIF.
        ENDIF.
        RETURN.
      ENDIF.
    ENDLOOP.

    " ② 실패: HTTP_Receiver_Adapter_Response_Body → X
    LOOP AT lt_entries INTO lv_entry.
      IF lv_entry CS '<d:Name>HTTP_Receiver_Adapter_Response_Body</d:Name>'.
        ev_statusin = 'X'.
        FIND FIRST OCCURRENCE OF '<d:Id>' IN lv_entry MATCH OFFSET lv_pos.
        IF sy-subrc = 0.
          lv_start = lv_pos + 6.
          lv_tail  = lv_entry+lv_start.
          FIND FIRST OCCURRENCE OF '</d:Id>' IN lv_tail MATCH OFFSET lv_end.
          IF sy-subrc = 0.
            ev_attach_id = lv_tail(lv_end).
          ENDIF.
        ENDIF.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD update_log.
    UPDATE zsd_is_log_kar
      SET inlog    = @iv_inlog,
          inlogmsg = @iv_inlogmsg
      WHERE messageguid = @iv_messageguid.
  ENDMETHOD.
ENDCLASS.
