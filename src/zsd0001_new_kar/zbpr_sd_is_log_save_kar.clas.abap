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

    METHODS fetch_and_save
      IMPORTING iv_module    TYPE ty_module
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

    " Date + Time → epoch milliseconds 변환 (LastChangeTime 필터용)
    DATA lv_epoch_from TYPE int8.
    DATA lv_epoch_to   TYPE int8.

    IF iv_date_from IS NOT INITIAL.
      DATA(lv_utc_from) = CONV utclong(
        |{ iv_date_from(4) }-{ iv_date_from+4(2) }-{ iv_date_from+6(2) }| &&
        |T{ COND #( WHEN iv_time_from IS NOT INITIAL THEN iv_time_from(2) ELSE '00' ) }| &&
        |:{ COND #( WHEN iv_time_from IS NOT INITIAL THEN iv_time_from+2(2) ELSE '00' ) }:00| ).
      DATA(lv_diff_from) = utclong_diff(
        high  = lv_utc_from
        low   = CONV utclong( '1970-01-01 00:00:00' ) ).
      lv_epoch_from = CONV int8( lv_diff_from ) * 1000.
    ENDIF.

    IF iv_date_to IS NOT INITIAL.
      DATA(lv_utc_to) = CONV utclong(
        |{ iv_date_to(4) }-{ iv_date_to+4(2) }-{ iv_date_to+6(2) }| &&
        |T{ COND #( WHEN iv_time_to IS NOT INITIAL THEN iv_time_to(2) ELSE '23' ) }| &&
        |:{ COND #( WHEN iv_time_to IS NOT INITIAL THEN iv_time_to+2(2) ELSE '59' ) }:59| ).
      DATA(lv_diff_to) = utclong_diff(
        high = lv_utc_to
        low  = CONV utclong( '1970-01-01 00:00:00' ) ).
      lv_epoch_to = CONV int8( lv_diff_to ) * 1000.
    ENDIF.

    " 시간 필터 조합
    DATA lv_time_filter TYPE string.
    IF lv_epoch_from > 0 AND lv_epoch_to > 0.
      lv_time_filter = | and LastChangeTime ge { lv_epoch_from }L and LastChangeTime le { lv_epoch_to }L|.
    ELSEIF lv_epoch_from > 0.
      lv_time_filter = | and LastChangeTime ge { lv_epoch_from }L|.
    ELSEIF lv_epoch_to > 0.
      lv_time_filter = | and LastChangeTime le { lv_epoch_to }L|.
    ENDIF.

    DATA(lv_base_url) = |http/gasentec/SD0000_005| &&
                        |?$format=json| &&
                        |&$filter=substringof('{ iv_module }',IntegrationFlowName)| &&
                        | and not substringof('LOG',IntegrationFlowName)| &&
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

    ev_msg = |005 STATUS={ lv_status_005 }, ROWS={ lines( ls_response-d-results ) }|.

    DATA lt_db TYPE TABLE OF zsd_is_log_kar.

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

      DATA(lv_status_in) = SWITCH #( ls_log-status
                             WHEN 'COMPLETED' THEN 'O'
                             ELSE ' ' ).


      APPEND VALUE zsd_is_log_kar(
        client      = sy-mandt
        messageguid = ls_log-messageguid
        statusis    = lv_status_is
        statusin    = lv_status_in
        flowname    = ls_log-integrationflowname
        lasttime    = lv_last_time
        inlog       = ''
        inlogmsg    = ''
      ) TO lt_db.

    ENDLOOP.

    IF lt_db IS INITIAL.
      ev_msg = |NO DATA TO SAVE. ROWS=0|.
      RETURN.
    ENDIF.

    MODIFY zsd_is_log_kar FROM TABLE @lt_db.
    IF sy-subrc = 0.
      ev_ok  = abap_true.
      ev_msg = |SAVE OK. ROWS={ lines( lt_db ) }|.
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
