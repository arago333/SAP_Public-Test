CLASS zbpr_sd_is_log_det_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.

CLASS zbpr_sd_is_log_det_kar IMPLEMENTATION.
  METHOD if_rap_query_provider~select.

    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
    ENDTRY.

    DATA lv_messageguid TYPE c LENGTH 100.
    DATA lv_inlog       TYPE string.
    DATA lv_inlogmsg    TYPE c LENGTH 255.

    LOOP AT lt_filter INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'MESSAGEGUID'.
          lv_messageguid = ls_filter-range[ 1 ]-low.
      ENDCASE.
    ENDLOOP.

    TRY.
        DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                          comm_scenario = 'ZCS_GAS_COMM'
                          service_id    = 'ZOB_ISLOG_REST' ).

        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                            i_destination = lo_dest ).

        DATA(lo_req) = lo_client->get_http_request( ).
        lo_req->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

        DATA(lv_path) = |http/gasentec/SD0000_006?s%28%27{ lv_messageguid }%27%29/Attachments|.
        lo_req->set_uri_path( i_uri_path = lv_path ).

        DATA(lo_res) = lo_client->execute( i_method = if_web_http_client=>get ).
        DATA(lv_status) = lo_res->get_status( )-code.
        lv_inlog = lo_res->get_text( ).

        IF lv_status = 200.
          lv_inlogmsg = 'Log fetched successfully'.
        ELSEIF lv_status = 400.
          lv_inlogmsg = 'Unspecified error occurred. See Error Context for more details'.
        ELSEIF lv_status = 500.
          lv_inlogmsg = 'An exception was raised'.
        ELSE.
          lv_inlogmsg = |HTTP Status { lv_status }|.
        ENDIF.

        lo_client->close( ).

      CATCH cx_http_dest_provider_error
            cx_web_http_client_error INTO DATA(lx_err).
        lv_inlog    = lx_err->get_text( ).
        lv_inlogmsg = 'An exception was raised'.
    ENDTRY.

    DATA lt_result TYPE TABLE OF zr_sd_is_log_det_kar.

    APPEND VALUE zr_sd_is_log_det_kar(
      messageguid = lv_messageguid
      inlogmsg    = lv_inlogmsg
      inlog       = lv_inlog
    ) TO lt_result.

    io_response->set_total_number_of_records( lines( lt_result ) ).
    io_response->set_data( lt_result ).

  ENDMETHOD.
ENDCLASS.
