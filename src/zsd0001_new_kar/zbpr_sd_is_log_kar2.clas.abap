CLASS zbpr_sd_is_log_kar2 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS zbpr_sd_is_log_kar2 IMPLEMENTATION.
  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE TABLE OF zr_sd_is_log_kar2.
    APPEND VALUE zr_sd_is_log_kar2(
      messageguid = 'REACHED'
      flowname    = 'HERE'
    ) TO lt_result.
    io_response->set_total_number_of_records( lines( lt_result ) ).
    io_response->set_data( lt_result ).
    RETURN.
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
    ENDTRY.

    DATA lv_module   TYPE c LENGTH 3.
    DATA lv_date_from TYPE d.
    DATA lv_date_to   TYPE d.
    DATA lv_time_from TYPE c LENGTH 6.
    DATA lv_time_to   TYPE c LENGTH 6.

    LOOP AT lt_filter INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'FLOWMODULE'.
          lv_module    = ls_filter-range[ 1 ]-low.
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
      lv_top = 100.
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
        APPEND VALUE zr_sd_is_log_kar2(
          messageguid = 'ERROR'
          flowname    = lx_error->get_text( )
        ) TO lt_result.
        io_response->set_total_number_of_records( lines( lt_result ) ).
        io_response->set_data( lt_result ).
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
    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_response
      CHANGING  data = ls_response ).




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

      APPEND VALUE zr_sd_is_log_kar2(
        messageguid   = ls_log-messageguid
        flowname      = ls_log-integrationflowname
        statusis      = SWITCH #( ls_log-status
                          WHEN 'COMPLETED' THEN 'O'
                          WHEN 'FAILED'    THEN 'X'
                          ELSE ' ' )
        criticalityis = SWITCH #( ls_log-status
                          WHEN 'COMPLETED' THEN 3
                          WHEN 'FAILED'    THEN 1
                          ELSE 0 )
        lasttime      = lv_last_time
      ) TO lt_result.

    ENDLOOP.

    io_response->set_total_number_of_records( lines( lt_result ) ).
    io_response->set_data( lt_result ).
  ENDMETHOD.

ENDCLASS.
