CLASS zbpr_sd_is_log_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZBPR_SD_IS_LOG_KAR IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
    ENDTRY.

    DATA lv_module TYPE c LENGTH 3.
    DATA lv_status_is TYPE c LENGTH 1.
    DATA lv_date_from TYPE d.
    DATA lv_date_to   TYPE d.
    DATA lv_time_from TYPE c LENGTH 6.
    DATA lv_time_to   TYPE c LENGTH 6.
    DATA lv_status_in      TYPE c LENGTH 1.
    DATA lv_criticality_in TYPE int1.
    DATA lv_inlog          TYPE string.
    DATA lv_attachment_id  TYPE string.
    DATA lv_att_value_path TYPE string.
    DATA lv_response2      TYPE string.
    DATA lv_response3      TYPE string.

    LOOP AT lt_filter INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'MODULE' OR 'FLOWMODULE'.
          lv_module = ls_filter-range[ 1 ]-low.
        WHEN 'FLOWDATE'.
          lv_date_from = ls_filter-range[ 1 ]-low.
          lv_date_to   = ls_filter-range[ 1 ]-high.
        WHEN 'FLOWTIME'.
          lv_time_from = ls_filter-range[ 1 ]-low.
          lv_time_to   = ls_filter-range[ 1 ]-high.
      ENDCASE.
    ENDLOOP.

    DATA(lv_base_url) = |http/gasentec/SD0000_005| &&
                        |?$format=json| &&
                        |&$filter=substringof('{ lv_module }',IntegrationFlowName)| &&
                        | and not substringof('LOG',IntegrationFlowName)| &&
                        |&$orderby=LogStart desc|.

    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).
    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).

    IF lv_top <= 0.
      lv_top = 20.
    ENDIF.

    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                  comm_scenario = 'ZCS_GAS_COMM' ).

        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination(
                                  i_destination = lo_destination ).

        DATA(lo_request) = lo_http_client->get_http_request( ).

        lo_request->set_uri_path(
          i_uri_path = |{ lv_base_url }&$top={ lv_top }&$skip={ lv_skip }| ).

        DATA(lo_response) = lo_http_client->execute(
                               i_method = if_web_http_client=>get ).
        DATA(lv_response) = lo_response->get_text( ).

        lo_http_client->close( ).

      CATCH cx_http_dest_provider_error
            cx_web_http_client_error INTO DATA(lx_error).
        RAISE SHORTDUMP lx_error.
    ENDTRY.

    TYPES: BEGIN OF ty_deferred_uri,
             uri TYPE string,
           END OF ty_deferred_uri.
    TYPES: BEGIN OF ty_deferred,
             __deferred TYPE ty_deferred_uri,
           END OF ty_deferred.
    TYPES: BEGIN OF ty_log,
             messageguid            TYPE string,
             correlationid          TYPE string,
             predecessormessageguid TYPE string,
             integrationflowname    TYPE string,
             status                 TYPE string,
             lastchangetime         TYPE string,
             attachments            TYPE ty_deferred,
           END OF ty_log.
    TYPES: BEGIN OF ty_d,
             results TYPE STANDARD TABLE OF ty_log WITH EMPTY KEY,
           END OF ty_d.
    TYPES: BEGIN OF ty_response,
             d TYPE ty_d,
           END OF ty_response.

    DATA ls_response TYPE ty_response.

    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_response
      CHANGING  data = ls_response ).

    TRY.
        DATA(lo_dest2) = cl_http_destination_provider=>create_by_comm_arrangement(
                           comm_scenario = 'ZCS_GAS_COMM' ).
        DATA(lo_client2) = cl_web_http_client_manager=>create_by_http_destination(
                             i_destination = lo_dest2 ).
      CATCH cx_http_dest_provider_error
            cx_web_http_client_error INTO DATA(lx_error2).
        RAISE SHORTDUMP lx_error2.
    ENDTRY.

    DATA lt_result TYPE TABLE OF zr_sd_is_log_kar.

    LOOP AT ls_response-d-results INTO DATA(ls_log).
      CLEAR: lv_status_is, lv_status_in, lv_criticality_in, lv_inlog,
             lv_attachment_id, lv_att_value_path, lv_response2, lv_response3.

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

      lv_status_is = SWITCH #(
        ls_log-status
        WHEN 'COMPLETED' THEN 'O'
        WHEN 'FAILED'    THEN 'X'
        ELSE space
      ).

      lv_status_in = space.
      lv_criticality_in = 0.
      CLEAR lv_inlog.

      IF ls_log-status = 'COMPLETED'.
        TRY.
            DATA(lo_req2) = lo_client2->get_http_request( ).
            lo_req2->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

            DATA(lv_att_path2) = |http/gasentec/SD0000_006?s('{ ls_log-messageguid }')/Attachments|.

            lo_req2->set_uri_path( i_uri_path = lv_att_path2 ).

            DATA(lo_res2) = lo_client2->execute( i_method = if_web_http_client=>get ).
            DATA(lv_status2) = lo_res2->get_status( )-code.
            lv_response2 = lo_res2->get_text( ).

            IF lv_status2 = 200.
              lv_status_in = 'O'.
              lv_criticality_in = 3.
              lv_inlog = lv_response2.
            ELSEIF lv_status2 = 500.
              lv_status_in = 'X'.
              lv_criticality_in = 1.
              lv_inlog = lv_response2.
            ELSEIF lv_status2 = 400.
              lv_status_in = 'X'.
              lv_criticality_in = 1.
              lv_inlog = lv_response2.
            ELSE.
              lv_status_in = 'X'.
              lv_criticality_in = 1.
              lv_inlog = |HTTP Status { lv_status2 } { lv_response2 }|.
            ENDIF.

          CATCH cx_web_http_client_error
                cx_http_dest_provider_error INTO DATA(lx_att_error).
            lv_status_in = 'X'.
            lv_criticality_in = 1.
            lv_inlog = lx_att_error->get_text( ).
        ENDTRY.
      ENDIF.

      DATA(ls_result) = VALUE zr_sd_is_log_kar(
        messageguid   = ls_log-messageguid
        flowname      = ls_log-integrationflowname
        statusis      = lv_status_is
        criticalityis = SWITCH #(
                          ls_log-status
                          WHEN 'COMPLETED' THEN 3
                          WHEN 'FAILED'    THEN 1
                          ELSE 0 )
        statusin      = lv_status_in
        criticalityin = lv_criticality_in
        inloglink     = 'View Log'
        inlog         = lv_inlog
        lasttime      = lv_last_time
      ).

      APPEND ls_result TO lt_result.
    ENDLOOP.

    io_response->set_total_number_of_records( lines( lt_result ) ).
    io_response->set_data( lt_result ).

  ENDMETHOD.
ENDCLASS.
