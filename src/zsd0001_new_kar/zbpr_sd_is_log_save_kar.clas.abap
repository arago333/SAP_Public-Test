CLASS zbpr_sd_is_log_save_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_module TYPE c LENGTH 3.

    METHODS fetch_and_save
      IMPORTING iv_module TYPE ty_module
      EXPORTING ev_ok     TYPE abap_bool
                ev_msg    TYPE string.

ENDCLASS.

CLASS zbpr_sd_is_log_save_kar IMPLEMENTATION.

  METHOD fetch_and_save.

    ev_ok = abap_false.
    CLEAR ev_msg.

    DATA(lv_base_url) = |http/gasentec/SD0000_005| &&
                        |?$format=json| &&
                        |&$filter=substringof('{ iv_module }',IntegrationFlowName)| &&
                        | and not substringof('LOG',IntegrationFlowName)| &&
                        |&$orderby=LogStart desc|.

    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                  comm_scenario = 'ZCS_GAS_COMM'
                                  service_id    = 'ZOB_ISLOG_REST' ).

        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination(
                                  i_destination = lo_destination ).

        DATA(lo_request) = lo_http_client->get_http_request( ).

        lo_request->set_uri_path(
          i_uri_path = |{ lv_base_url }&$top=100&$skip=0| ).

        DATA(lo_response) = lo_http_client->execute(
                               i_method = if_web_http_client=>get ).

        DATA(lv_status_005) = lo_response->get_status( )-code.
        DATA(lv_response)   = lo_response->get_text( ).

        lo_http_client->close( ).

        ev_msg = |005 STATUS={ lv_status_005 }|.

      CATCH cx_http_dest_provider_error
            cx_web_http_client_error INTO DATA(lx_err).
        ev_msg = |005 ERROR: { lx_err->get_text( ) }|.
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
        /ui2/cl_json=>deserialize(
          EXPORTING json = lv_response
          CHANGING  data = ls_response ).
      CATCH cx_root INTO DATA(lx_json).
        ev_msg = |JSON ERROR: { lx_json->get_text( ) }|.
        RETURN.
    ENDTRY.

    ev_msg = |005 STATUS={ lv_status_005 }, ROWS={ lines( ls_response-d-results ) }|.

    TRY.
        DATA(lo_dest2) = cl_http_destination_provider=>create_by_comm_arrangement(
                           comm_scenario = 'ZCS_GAS_COMM'
                           service_id    = 'ZOB_ISLOG_REST'
                            ).
        DATA(lo_client2) = cl_web_http_client_manager=>create_by_http_destination(
                             i_destination = lo_dest2 ).

      CATCH cx_http_dest_provider_error
            cx_web_http_client_error INTO DATA(lx_err2).
        ev_msg = |006 DEST ERROR: { lx_err2->get_text( ) }|.
        RETURN.
    ENDTRY.

    DATA lt_db TYPE TABLE OF zsd_is_log_kar.

    LOOP AT ls_response-d-results INTO DATA(ls_log).

      DATA(lv_seconds) = CONV decfloat34( ls_log-lastchangetime ) / 1000.
      DATA(lv_utclong) = utclong_add(
                           val     = CONV utclong( '1970-01-01 00:00:00' )
                           seconds = lv_seconds ).

      DATA lv_date TYPE d.
      DATA lv_time TYPE t.

      CONVERT UTCLONG lv_utclong TIME ZONE 'UTC' INTO DATE lv_date TIME lv_time.
      lv_utclong = utclong_add( val = lv_utclong seconds = 32400 ).
      CONVERT UTCLONG lv_utclong TIME ZONE 'UTC' INTO DATE lv_date TIME lv_time.

      DATA(lv_last_time) = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }| &&
                           |T{ lv_time(2) }:{ lv_time+2(2) }|.

      DATA(lv_status_is) = SWITCH #( ls_log-status
                             WHEN 'COMPLETED' THEN 'O'
                             WHEN 'FAILED'    THEN 'X'
                             ELSE ' ' ).

      DATA lv_status_in TYPE c LENGTH 1.
      DATA lv_inlog     TYPE string.
      DATA lv_inlogmsg  TYPE c LENGTH 255.

      CLEAR: lv_status_in, lv_inlog.

      IF ls_log-status = 'COMPLETED'.
        TRY.
            DATA(lo_req2) = lo_client2->get_http_request( ).
            lo_req2->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

            DATA(lv_att_path2) = |http/gasentec/SD0000_006?s('{ ls_log-messageguid }')/Attachments|.

            lo_req2->set_uri_path( i_uri_path = lv_att_path2 ).

            DATA(lo_res2) = lo_client2->execute( i_method = if_web_http_client=>get ).
            DATA(lv_status2) = lo_res2->get_status( )-code.
            DATA(lv_response_text) = lo_res2->get_text( ).

            CASE lv_status2.
              WHEN 200.
                lv_status_in = 'O'.
                lv_inlogmsg  = 'Log fetched successfully'.
                lv_inlog     = lv_response_text.
              WHEN 400.
                lv_status_in = 'X'.
                lv_inlogmsg  = 'Unspecified error occurred. See Error Context for more details'.
                lv_inlog     = lv_response_text.
              WHEN 500.
                lv_status_in = 'X'.
                lv_inlogmsg  = 'An exception was raised'.
                lv_inlog     = lv_response_text.
              WHEN OTHERS.
                lv_status_in = 'X'.
                lv_inlogmsg  = |HTTP Status { lv_status2 }|.
                lv_inlog     = lv_response_text.
            ENDCASE.

          CATCH cx_web_http_client_error
                cx_http_dest_provider_error INTO DATA(lx_att_err).
            lv_status_in = 'X'.
            lv_inlogmsg  = 'An exception was raised'.
            lv_inlog     = lx_att_err->get_text( ).
        ENDTRY.
      ENDIF.

      APPEND VALUE zsd_is_log_kar(
        client      = sy-mandt
        messageguid = ls_log-messageguid
        statusis    = lv_status_is
        statusin    = lv_status_in
        flowname    = ls_log-integrationflowname
        lasttime    = lv_last_time
        inlog       = lv_inlog
        inlogmsg    = lv_inlogmsg
      ) TO lt_db.

    ENDLOOP.

    IF lt_db IS INITIAL.
      ev_msg = |NO DATA TO SAVE. 005 STATUS={ lv_status_005 }, ROWS=0|.
      RETURN.
    ENDIF.

    MODIFY zsd_is_log_kar FROM TABLE @lt_db.

    IF sy-subrc = 0.
      ev_ok = abap_true.
      ev_msg = |SAVE OK. DB_ROWS={ lines( lt_db ) } DBCNT={ sy-dbcnt }|.
    ELSE.
      ev_msg = |SAVE FAIL. SY-SUBRC={ sy-subrc } DB_ROWS={ lines( lt_db ) }|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
