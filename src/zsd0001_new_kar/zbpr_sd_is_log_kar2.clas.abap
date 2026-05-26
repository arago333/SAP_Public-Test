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

    DATA lv_module      TYPE c LENGTH 3 VALUE 'SD'.
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
          " 멀티 선택 시 lv_statusis 빈값 → IS API 필터 없음
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

    " ─────────────────────────────────────────────
    " Object Page 조회
    " ─────────────────────────────────────────────
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

        " inlog/inlogmsg 둘 다 있으면 API 재호출 생략 (캐시 활용)
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

                " ① 성공 시: d:Name 기준으로 Log : END - Body 또는 Log : Response 찾기
                LOOP AT lt_entries INTO lv_entry.
                  IF lv_entry CS '<d:Name>Log : END - Body</d:Name>'
                  OR lv_entry CS '<d:Name>Log : Response</d:Name>'.
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

                " ② fallback: d:Name 기준으로 HTTP_Receiver_Adapter_Response_Body 찾기
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

                  " 메시지 확정 후 DB 저장
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

        " ← 캐시/재호출 공통 APPEND
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

      io_response->set_total_number_of_records( lines( lt_result ) ).
      io_response->set_data( lt_result ).
      RETURN.

    ENDIF.

    " ─────────────────────────────────────────────
    " List Report 조회
    " ─────────────────────────────────────────────
    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).
    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    IF lv_top <= 0.
      lv_top = 100.
    ENDIF.

    " 첫 페이지일 때만 005 API 호출 (반복 호출 방지)
    IF lv_skip = 0.
      DATA(lo_save) = NEW zbpr_sd_is_log_save_kar( ).
      lo_save->fetch_and_save(
        EXPORTING
          iv_module    = lv_module
          iv_statusis  = lv_statusis
          iv_date_from = lv_date_from
          iv_date_to   = lv_date_to
          iv_time_from = lv_time_from
          iv_time_to   = lv_time_to ).
    ENDIF.

    DATA lv_module_pat TYPE c LENGTH 45.
    lv_module_pat = |%{ lv_module }%|.

    DATA lv_from_str TYPE c LENGTH 16.
    DATA lv_to_str   TYPE c LENGTH 16.

    IF lv_date_from IS NOT INITIAL.
      lv_from_str = |{ lv_date_from(4) }-{ lv_date_from+4(2) }-{ lv_date_from+6(2) }|.
      IF lv_time_from IS NOT INITIAL.
        lv_from_str = |{ lv_from_str }T{ lv_time_from(2) }:{ lv_time_from+2(2) }|.
      ELSE.
        lv_from_str = |{ lv_from_str }T00:00|.
      ENDIF.
    ENDIF.

    IF lv_date_to IS NOT INITIAL.
      lv_to_str = |{ lv_date_to(4) }-{ lv_date_to+4(2) }-{ lv_date_to+6(2) }|.
      IF lv_time_to IS NOT INITIAL.
        lv_to_str = |{ lv_to_str }T{ lv_time_to(2) }:{ lv_time_to+2(2) }|.
      ELSE.
        lv_to_str = |{ lv_to_str }T23:59|.
      ENDIF.
    ENDIF.

    DATA lt_db TYPE TABLE OF zsd_is_log_kar.
    SELECT * FROM zsd_is_log_kar
      WHERE ( @lv_module_pat = '%%'   OR flowname LIKE @lv_module_pat )
        AND ( @lv_statusis   = ''     OR statusis = @lv_statusis )
        AND ( @lv_statusin   = ''     OR statusin = @lv_statusin )
        AND ( @lv_from_str   = ''     OR lasttime >= @lv_from_str )
        AND ( @lv_to_str     = ''     OR lasttime <= @lv_to_str )
      ORDER BY lasttime DESCENDING
      INTO TABLE @lt_db.

    DATA lv_total TYPE int8.
    lv_total = lines( lt_db ).

    DATA lv_end_list TYPE i.
    lv_end_list = lv_skip + lv_top.

    DATA lv_idx TYPE i.
    lv_idx = lv_skip + 1.

    WHILE lv_idx <= lv_end_list AND lv_idx <= lines( lt_db ).
      DATA(ls_row) = lt_db[ lv_idx ].
      APPEND VALUE zr_sd_is_log_kar2(
        messageguid    = ls_row-messageguid
        statusis       = ls_row-statusis
        statusin       = ls_row-statusin
        flowname       = ls_row-flowname
        lasttime       = ls_row-lasttime
        inlog          = ls_row-inlog
        inlogmsg       = ls_row-inlogmsg
        criticalityis  = SWITCH #( ls_row-statusis WHEN 'O' THEN 3 WHEN 'X' THEN 1 ELSE 0 )
        criticalityin  = SWITCH #( ls_row-statusin WHEN 'O' THEN 3 WHEN 'X' THEN 1 ELSE 0 )
        criticalitylog = SWITCH #( ls_row-inlog    WHEN '' THEN 0 ELSE 5 )
      ) TO lt_result.
      lv_idx = lv_idx + 1.
    ENDWHILE.

    io_response->set_total_number_of_records( lv_total ).
    io_response->set_data( lt_result ).

  ENDMETHOD.
ENDCLASS.
