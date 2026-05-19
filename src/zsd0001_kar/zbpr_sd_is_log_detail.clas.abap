CLASS zbpr_sd_is_log_detail DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS zbpr_sd_is_log_detail IMPLEMENTATION.
  METHOD if_rap_query_provider~select.

    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
    ENDTRY.

    DATA lv_messageguid TYPE c LENGTH 100.
    DATA lv_inlog       TYPE string.
    DATA lv_flowname    TYPE c LENGTH 40.
    DATA lv_status_in   TYPE c LENGTH 1.

    LOOP AT lt_filter INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'MESSAGEGUID'.
          lv_messageguid = ls_filter-range[ 1 ]-low.
      ENDCASE.
    ENDLOOP.

    TRY.
        DATA(lo_dest2) = cl_http_destination_provider=>create_by_comm_arrangement(
                           comm_scenario = 'ZCS_GAS_COMM' ).
        DATA(lo_client2) = cl_web_http_client_manager=>create_by_http_destination(
                             i_destination = lo_dest2 ).
        DATA(lo_req2) = lo_client2->get_http_request( ).

        lo_req2->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

        DATA(lv_att_path2) = |http/gasentec/SD0000_006?s('{ lv_messageguid }')/Attachments|.

        lo_req2->set_uri_path( i_uri_path = lv_att_path2 ).

        DATA(lo_res2) = lo_client2->execute( i_method = if_web_http_client=>get ).
        DATA(lv_status2) = lo_res2->get_status( )-code.
        lv_inlog = lo_res2->get_text( ).

        IF lv_status2 = 200.
          lv_status_in = 'O'.
        ELSE.
          lv_status_in = 'X'.
        ENDIF.

      CATCH cx_http_dest_provider_error
            cx_web_http_client_error INTO DATA(lx_error).
        lv_inlog = lx_error->get_text( ).
        lv_status_in = 'X'.
    ENDTRY.

    DATA lt_result TYPE TABLE OF zr_sd_is_log_detail.

    APPEND VALUE zr_sd_is_log_detail(
      messageguid = lv_messageguid
      flowname    = lv_flowname
      statusin    = lv_status_in
      inlog       = lv_inlog
    ) TO lt_result.

    io_response->set_total_number_of_records( lines( lt_result ) ).
    io_response->set_data( lt_result ).

  ENDMETHOD.

ENDCLASS.
