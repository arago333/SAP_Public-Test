CLASS zbpr_sd_is_log_kar2 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.

CLASS zbpr_sd_is_log_kar2 IMPLEMENTATION.
  METHOD if_rap_query_provider~select.

    " ① 필터 꺼내기
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
    ENDTRY.

    DATA lv_module    TYPE c LENGTH 3 VALUE 'SD'.
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

    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).
    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    IF lv_top <= 0.
      lv_top = 100.
    ENDIF.

    " ② IS API 호출 + DB 저장
    DATA(lo_save) = NEW zbpr_sd_is_log_save_kar( ).
    lo_save->fetch_and_save( iv_module = lv_module ).

    " ③ 전체 건수 조회
    DATA lv_total TYPE int8.
    SELECT COUNT(*) FROM zsd_is_log_kar INTO @lv_total.

    " ④ 페이징 적용해서 DB SELECT
    DATA lt_result TYPE TABLE OF zr_sd_is_log_kar2.
    DATA lt_db TYPE TABLE OF zsd_is_log_kar.

    SELECT * FROM zsd_is_log_kar
      ORDER BY messageguid
      INTO TABLE @lt_db.

    " 페이징 처리
    DATA lv_end TYPE i.
    lv_end = lv_skip + lv_top.

    DATA lv_idx TYPE i.
    lv_idx = lv_skip + 1.
    WHILE lv_idx <= lv_end AND lv_idx <= lines( lt_db ).
      DATA(ls_row) = lt_db[ lv_idx ].
      APPEND VALUE zr_sd_is_log_kar2(
        messageguid = ls_row-messageguid
        statusis    = ls_row-statusis
        statusin    = ls_row-statusin
        flowname    = ls_row-flowname
        lasttime    = ls_row-lasttime
        inlog            = ls_row-inlog
        criticalityis = SWITCH #( ls_row-statusis
                    WHEN 'O' THEN 3
                    WHEN 'X' THEN 1
                    ELSE 0 )
       criticalityin = SWITCH #( ls_row-statusin
                    WHEN 'O' THEN 3
                    WHEN 'X' THEN 1
                    ELSE 0 )
       criticalitylog = SWITCH #( ls_row-inlog
                   WHEN '' THEN 0
                   ELSE 5 )
      ) TO lt_result.
      lv_idx = lv_idx + 1.
    ENDWHILE.

    io_response->set_total_number_of_records( lv_total ).
    io_response->set_data( lt_result ).

  ENDMETHOD.
ENDCLASS.
