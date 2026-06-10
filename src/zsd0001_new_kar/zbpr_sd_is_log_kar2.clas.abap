CLASS zbpr_sd_is_log_kar2 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS zbpr_sd_is_log_kar2 IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
    ENDTRY.

    DATA lv_module      TYPE c LENGTH 3.
    DATA lv_statusis    TYPE c LENGTH 1.
    DATA lv_statusin    TYPE c LENGTH 1.
    DATA lv_date_from   TYPE d.
    DATA lv_date_to     TYPE d.
    DATA lv_time_from   TYPE c LENGTH 6.
    DATA lv_time_to     TYPE c LENGTH 6.
    DATA lv_messageguid TYPE c LENGTH 100.

    LOOP AT lt_filter INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'MESSAGEGUID'. lv_messageguid = ls_filter-range[ 1 ]-low.
        WHEN 'FLOWMODULE'.  lv_module      = ls_filter-range[ 1 ]-low.
        WHEN 'STATUSIS'.
          IF lines( ls_filter-range ) = 1.
            lv_statusis = ls_filter-range[ 1 ]-low.
          ENDIF.
        WHEN 'STATUSIN'.
          IF lines( ls_filter-range ) = 1.
            lv_statusin = ls_filter-range[ 1 ]-low.
          ENDIF.
        WHEN 'FLOWDATE'.
          lv_date_from = ls_filter-range[ 1 ]-low.
          lv_date_to   = COND #(
            WHEN ls_filter-range[ 1 ]-high IS NOT INITIAL
            THEN ls_filter-range[ 1 ]-high
            ELSE ls_filter-range[ 1 ]-low ).
        WHEN 'FLOWTIME'.
          lv_time_from = ls_filter-range[ 1 ]-low.
          lv_time_to   = COND #(
            WHEN ls_filter-range[ 1 ]-high IS NOT INITIAL
            THEN ls_filter-range[ 1 ]-high
            ELSE ls_filter-range[ 1 ]-low ).
      ENDCASE.
    ENDLOOP.

    DATA lt_result TYPE TABLE OF zr_sd_is_log_kar2.

    " Object Page 조회
    IF lv_messageguid IS NOT INITIAL.

      SELECT SINGLE *
        FROM zsd_is_log_kar
        WHERE messageguid = @lv_messageguid
        INTO @DATA(ls_single).

      IF sy-subrc = 0.

        DATA lv_inlog_detail    TYPE string.
        DATA lv_inlogmsg_detail TYPE c LENGTH 255.
        lv_inlog_detail    = ls_single-inlog.
        lv_inlogmsg_detail = ls_single-inlogmsg.

        IF ls_single-inlog IS NOT INITIAL AND ls_single-inlogmsg IS NOT INITIAL.
          lv_inlog_detail    = ls_single-inlog.
          lv_inlogmsg_detail = ls_single-inlogmsg.
        ELSE.

          TRY.
              DATA(lo_dest2) = cl_http_destination_provider=>create_by_comm_arrangement(
                                 comm_scenario = 'ZCS_GAS_COMM'
                                 service_id    = 'ZOB_ISLOG_REST' ).
              DATA(lo_client2) = cl_web_http_client_manager=>create_by_http_destination(
                                   i_destination = lo_dest2 ).
              DATA(lo_req2) = lo_client2->get_http_request( ).
              lo_req2->set_header_field( i_name = 'Accept' i_value = 'application/xml' ).
              lo_req2->set_uri_path(
                i_uri_path = |http/gasentec/SD0000_006?s%28%27{ lv_messageguid }%27%29/Attachments| ).
              DATA(lo_res2)  = lo_client2->execute( i_method = if_web_http_client=>get ).
              DATA(lv_code2) = lo_res2->get_status( )-code.
              DATA(lv_feed)  = lo_res2->get_text( ).
              lo_client2->close( ).

              IF lv_code2 = 200.

                DATA lv_attach_id TYPE string.
                DATA lt_entries   TYPE STANDARD TABLE OF string WITH EMPTY KEY.
                DATA lv_entry     TYPE string.
                DATA lv_src_pos   TYPE i.
                DATA lv_start     TYPE i.
                DATA lv_end       TYPE i.
                DATA lv_tail      TYPE string.

                SPLIT lv_feed AT '<entry>' INTO TABLE lt_entries.

                LOOP AT lt_entries INTO lv_entry.
                  IF lv_entry CS '<d:Name>Log : Response</d:Name>'.
                    FIND FIRST OCCURRENCE OF '<d:Id>' IN lv_entry MATCH OFFSET lv_src_pos.
                    IF sy-subrc = 0.
                      lv_start = lv_src_pos + 6.
                      lv_tail  = lv_entry+lv_start.
                      FIND FIRST OCCURRENCE OF '</d:Id>' IN lv_tail MATCH OFFSET lv_end.
                      IF sy-subrc = 0.
                        lv_attach_id = lv_tail(lv_end).
                      ENDIF.
                    ENDIF.
                    EXIT.
                  ENDIF.
                ENDLOOP.

                IF lv_attach_id IS INITIAL.
                  LOOP AT lt_entries INTO lv_entry.
                    IF lv_entry CS '<d:Name>HTTP_Receiver_Adapter_Response_Body</d:Name>'.
                      FIND FIRST OCCURRENCE OF '<d:Id>' IN lv_entry MATCH OFFSET lv_src_pos.
                      IF sy-subrc = 0.
                        lv_start = lv_src_pos + 6.
                        lv_tail  = lv_entry+lv_start.
                        FIND FIRST OCCURRENCE OF '</d:Id>' IN lv_tail MATCH OFFSET lv_end.
                        IF sy-subrc = 0.
                          lv_attach_id = lv_tail(lv_end).
                        ENDIF.
                      ENDIF.
                      EXIT.
                    ENDIF.
                  ENDLOOP.
                ENDIF.

                IF lv_attach_id IS NOT INITIAL.

                  DATA(lo_dest3) = cl_http_destination_provider=>create_by_comm_arrangement(
                                     comm_scenario = 'ZCS_GAS_COMM'
                                     service_id    = 'ZOB_ISLOG_REST' ).
                  DATA(lo_client3) = cl_web_http_client_manager=>create_by_http_destination(
                                       i_destination = lo_dest3 ).
                  DATA(lo_req3) = lo_client3->get_http_request( ).
                  lo_req3->set_header_field( i_name = 'Accept' i_value = 'text/plain' ).
                  lo_req3->set_uri_path(
                    i_uri_path = |http/gasentec/SD0000_006?Attachments%28%27{ lv_attach_id }%27%29/%24value| ).
                  DATA(lo_res3)  = lo_client3->execute( i_method = if_web_http_client=>get ).
                  DATA(lv_code3) = lo_res3->get_status( )-code.
                  lv_inlog_detail = lo_res3->get_text( ).
                  lo_client3->close( ).

                  IF lv_code3 = 200.
                    IF ls_single-statusin = 'O'.
                      lv_inlogmsg_detail = 'Log fetched successfully'.
                    ELSEIF ls_single-statusin = 'X'.
                      lv_inlogmsg_detail = 'Internal process failed'.
                    ELSE.
                      lv_inlogmsg_detail = 'Log fetched'.
                    ENDIF.
                  ELSEIF lv_code3 = 400.
                    lv_inlogmsg_detail = 'Unspecified error occurred'.
                  ELSEIF lv_code3 = 500.
                    lv_inlogmsg_detail = 'An exception was raised'.
                  ELSE.
                    lv_inlogmsg_detail = |HTTP Status { lv_code3 }|.
                  ENDIF.

                  DATA(lo_save2) = NEW zbpr_sd_is_log_save_kar( ).
                  lo_save2->update_log(
                    iv_messageguid = lv_messageguid
                    iv_inlog       = lv_inlog_detail
                    iv_inlogmsg    = lv_inlogmsg_detail ).

                ELSE.
                  lv_inlogmsg_detail = 'Log : END - Body not found'.
                  lv_inlog_detail    = lv_feed.
                ENDIF.

              ELSE.
                lv_inlogmsg_detail = |HTTP Status { lv_code2 }|.
                lv_inlog_detail    = lv_feed.
              ENDIF.

            CATCH cx_http_dest_provider_error
                  cx_web_http_client_error INTO DATA(lx_err2).
              lv_inlogmsg_detail = lx_err2->get_text( ).
          ENDTRY.

        ENDIF.

        APPEND VALUE zr_sd_is_log_kar2(
          messageguid    = ls_single-messageguid
          statusis       = ls_single-statusis
          statusin       = ls_single-statusin
          flowname       = ls_single-flowname
          lasttime       = ls_single-lasttime
          inlog          = lv_inlog_detail
          inlogmsg       = lv_inlogmsg_detail
          criticalityis  = SWITCH #( ls_single-statusis WHEN 'O' THEN 3 WHEN 'X' THEN 1 ELSE 0 )
          criticalityin  = SWITCH #( ls_single-statusin WHEN 'O' THEN 3 WHEN 'X' THEN 1 ELSE 0 )
          criticalitylog = SWITCH #( lv_inlog_detail    WHEN '' THEN 0 ELSE 5 )
        ) TO lt_result.

      ENDIF.

      io_response->set_total_number_of_records( CONV int8( lines( lt_result ) ) ).
      io_response->set_data( lt_result ).
      RETURN.

    ENDIF.

    " List Report 조회
    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).
    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    IF lv_top <= 0.
      lv_top = 100.
    ENDIF.

    " KST 입력 날짜/시간 -> UTC epoch 변환
    DATA lv_epoch_from TYPE int8.
    DATA lv_epoch_to   TYPE int8.

    IF lv_date_from IS NOT INITIAL.
      DATA(lv_utc_from) = CONV utclong(
        |{ lv_date_from(4) }-{ lv_date_from+4(2) }-{ lv_date_from+6(2) }| &&
        |T{ COND #( WHEN lv_time_from IS NOT INITIAL THEN lv_time_from(2)   ELSE '00' ) }| &&
        |:{ COND #( WHEN lv_time_from IS NOT INITIAL THEN lv_time_from+2(2) ELSE '00' ) }:00| ).

      lv_epoch_from = CONV int8( utclong_diff(
        high = lv_utc_from
        low  = CONV utclong( '1970-01-01 00:00:00' ) ) ) * 1000.
    ENDIF.

    IF lv_date_to IS NOT INITIAL.
      DATA(lv_utc_to) = CONV utclong(
        |{ lv_date_to(4) }-{ lv_date_to+4(2) }-{ lv_date_to+6(2) }| &&
        |T{ COND #( WHEN lv_time_to IS NOT INITIAL THEN lv_time_to(2)   ELSE '23' ) }| &&
        |:{ COND #( WHEN lv_time_to IS NOT INITIAL THEN lv_time_to+2(2) ELSE '59' ) }:59| ).

      lv_epoch_to = CONV int8( utclong_diff(
        high = lv_utc_to
        low  = CONV utclong( '1970-01-01 00:00:00' ) ) ) * 1000.
    ENDIF.

    DATA(lv_time_filter) = COND string(
      WHEN lv_epoch_from > 0 AND lv_epoch_to > 0
        THEN | and LastChangeTime ge { lv_epoch_from }L and LastChangeTime le { lv_epoch_to }L|
      WHEN lv_epoch_from > 0
        THEN | and LastChangeTime ge { lv_epoch_from }L|
      WHEN lv_epoch_to > 0
        THEN | and LastChangeTime le { lv_epoch_to }L|
      ELSE `` ).

    DATA(lv_status_filter) = COND string(
      WHEN lv_statusis = 'O' THEN | and Status eq 'COMPLETED'|
      WHEN lv_statusis = 'X' THEN | and Status eq 'FAILED'|
      ELSE `` ).

    DATA(lv_module_filter) = COND string(
      WHEN lv_module IS NOT INITIAL
        THEN | and substringof('{ lv_module }',IntegrationFlowName)|
      ELSE `` ).

    DATA(lv_base_url) = |http/gasentec/SD0000_005| &&
                        |?$format=json| &&
                        |&$inlinecount=allpages| &&
                        |&$filter=not substringof('LOG',IntegrationFlowName)| &&
                        | and Status ne 'DISCARDED'| &&
                        lv_module_filter &&
                        lv_status_filter &&
                        lv_time_filter &&
                        |&$orderby=LastChangeTime desc|.

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
    DATA lv_total_count TYPE int8 VALUE 0.
    DATA lv_api_skip    TYPE i VALUE 0.
    DATA lv_api_top     TYPE i VALUE 100.
    DATA lv_page        TYPE i VALUE 1.
    DATA lt_all         TYPE TABLE OF zr_sd_is_log_kar2.

    DO.
      CLEAR ls_response.

      TRY.
          DATA(lo_dest1) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = 'ZCS_GAS_COMM'
                             service_id    = 'ZOB_ISLOG_REST' ).

          DATA(lo_client1) = cl_web_http_client_manager=>create_by_http_destination(
                               i_destination = lo_dest1 ).

          DATA(lo_req1) = lo_client1->get_http_request( ).
          lo_req1->set_uri_path(
            i_uri_path = |{ lv_base_url }&$top={ lv_api_top }&$skip={ lv_api_skip }| ).

          DATA(lo_res1)     = lo_client1->execute( i_method = if_web_http_client=>get ).
          DATA(lv_response) = lo_res1->get_text( ).
          lo_client1->close( ).

        CATCH cx_http_dest_provider_error
              cx_web_http_client_error.
          io_response->set_total_number_of_records( 0 ).
          io_response->set_data( lt_result ).
          RETURN.
      ENDTRY.

      TRY.
          /ui2/cl_json=>deserialize(
            EXPORTING json = lv_response
            CHANGING  data = ls_response ).
        CATCH cx_root.
          io_response->set_total_number_of_records( 0 ).
          io_response->set_data( lt_result ).
          RETURN.
      ENDTRY.

      IF lv_page = 1.
        lv_total_count = CONV int8( ls_response-d-__count ).
      ENDIF.

      IF ls_response-d-results IS INITIAL.
        EXIT.
      ENDIF.

      LOOP AT ls_response-d-results INTO DATA(ls_log).

        DATA lv_list_statusis TYPE c LENGTH 1.
        DATA lv_list_statusin TYPE c LENGTH 1.
        DATA lv_list_attach_id TYPE string.

        CLEAR: lv_list_statusis, lv_list_statusin, lv_list_attach_id.

        lv_list_statusis = SWITCH #( ls_log-status
          WHEN 'COMPLETED' THEN 'O'
          WHEN 'FAILED'    THEN 'X'
          ELSE ' ' ).

        " 남의 로직과 동일하게 StatusIs = O인 건만 Attachment 결과로 목록 생성
        IF lv_list_statusis <> 'O'.
          CONTINUE.
        ENDIF.

        DATA(lv_seconds) = CONV decfloat34( ls_log-lastchangetime ) / 1000.
        DATA(lv_utclong) = utclong_add(
                             val     = CONV utclong( '1970-01-01 00:00:00' )
                             seconds = lv_seconds ).

        " CPI LastChangeTime UTC -> KST display
        lv_utclong = utclong_add( val = lv_utclong seconds = 32400 ).

        CONVERT UTCLONG lv_utclong TIME ZONE 'UTC'
                INTO DATE DATA(lv_date) TIME DATA(lv_time).

        DATA(lo_save_attach) = NEW zbpr_sd_is_log_save_kar( ).

        lo_save_attach->get_attach_id(
          EXPORTING iv_messageguid = CONV #( ls_log-messageguid )
          IMPORTING ev_attach_id   = lv_list_attach_id
                    ev_statusin    = lv_list_statusin ).

        " Attachment에서 Log : Response 또는 HTTP_Receiver_Adapter_Response_Body가 없는 건 제외
        IF lv_list_statusin IS INITIAL.
          CONTINUE.
        ENDIF.

        IF lv_statusin IS NOT INITIAL AND lv_list_statusin <> lv_statusin.
          CONTINUE.
        ENDIF.

        APPEND VALUE zr_sd_is_log_kar2(
          messageguid    = ls_log-messageguid
          statusis       = lv_list_statusis
          statusin       = lv_list_statusin
          flowname       = ls_log-integrationflowname
          lasttime       = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }T{ lv_time(2) }:{ lv_time+2(2) }|
          inlog          = ``
          inlogmsg       = COND #(
                             WHEN lv_list_statusin = 'O' THEN 'Log fetched successfully'
                             WHEN lv_list_statusin = 'X' THEN 'Internal process failed'
                             ELSE `` )
          criticalityis  = SWITCH #( lv_list_statusis
                             WHEN 'O' THEN 3
                             WHEN 'X' THEN 1
                             ELSE 0 )
          criticalityin  = SWITCH #( lv_list_statusin
                             WHEN 'O' THEN 3
                             WHEN 'X' THEN 1
                             ELSE 0 )
          criticalitylog = 0
        ) TO lt_all.

      ENDLOOP.

      lv_api_skip = lv_api_skip + lv_api_top.
      lv_page     = lv_page + 1.

      IF CONV int8( lv_api_skip ) >= lv_total_count.
        EXIT.
      ENDIF.

    ENDDO.

    SORT lt_all BY lasttime DESCENDING.

    DATA lv_end_idx TYPE i.
    lv_end_idx = lv_skip + lv_top.

    DATA lv_idx TYPE i.
    lv_idx = lv_skip + 1.

    WHILE lv_idx <= lv_end_idx AND lv_idx <= lines( lt_all ).
      APPEND lt_all[ lv_idx ] TO lt_result.
      lv_idx = lv_idx + 1.
    ENDWHILE.

    io_response->set_total_number_of_records( CONV int8( lines( lt_all ) ) ).
    io_response->set_data( lt_result ).

  ENDMETHOD.
ENDCLASS.
