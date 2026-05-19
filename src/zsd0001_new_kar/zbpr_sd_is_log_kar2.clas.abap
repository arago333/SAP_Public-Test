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

    " ② IS API 호출 + DB 저장 → 별도 클래스에서 처리
    DATA(lo_save) = NEW zbpr_sd_is_log_save_kar( ).
    lo_save->fetch_and_save( iv_module = lv_module ).

    " ③ DB에서 SELECT해서 결과 반환
    DATA lt_result TYPE TABLE OF zr_sd_is_log_kar2.

    SELECT * FROM zsd_is_log_kar
    INTO TABLE @DATA(lt_db_result).

    LOOP AT lt_db_result INTO DATA(ls_db).
      APPEND VALUE zr_sd_is_log_kar2(
        messageguid = ls_db-messageguid
        statusis    = ls_db-statusis
        statusin    = ls_db-statusin
        flowname    = ls_db-flowname
        lasttime    = ls_db-lasttime
      ) TO lt_result.
    ENDLOOP.

    io_response->set_total_number_of_records( lines( lt_result ) ).
    io_response->set_data( lt_result ).

  ENDMETHOD.
ENDCLASS.
