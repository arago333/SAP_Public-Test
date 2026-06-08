CLASS lhc_ZR_SD_IS_LOG2_KAR DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR IsLog RESULT result.

    METHODS fetchlogs FOR MODIFY
      IMPORTING keys FOR ACTION IsLog~fetchlogs.

    METHODS fetchlog FOR MODIFY
      IMPORTING keys FOR ACTION IsLog~fetchlog RESULT result.

ENDCLASS.

CLASS lhc_ZR_SD_IS_LOG2_KAR IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD fetchlogs.

    DATA lt_pending TYPE TABLE OF zsd_is_log_kar.
    SELECT messageguid, statusis
      FROM zsd_is_log_kar
      WHERE statusis = 'O'
        AND statusin = ' '
      ORDER BY lasttime ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_pending
     UP TO 1 ROWS.

    CHECK lt_pending IS NOT INITIAL.

    DATA(lo_save) = NEW zbpr_sd_is_log_save_kar( ).
    DATA lt_update TYPE TABLE OF zsd_is_log_kar.

    LOOP AT lt_pending INTO DATA(ls_pending).
      DATA lv_attach_id TYPE string.
      DATA lv_statusin  TYPE c LENGTH 1.

      lo_save->get_attach_id(
        EXPORTING iv_messageguid = CONV #( ls_pending-messageguid )
        IMPORTING ev_attach_id   = lv_attach_id
                  ev_statusin    = lv_statusin ).

      " DB에서 기존 레코드 읽어서 전체 필드 채우기
      SELECT SINGLE *
        FROM zsd_is_log_kar
        WHERE messageguid = @ls_pending-messageguid
        INTO @DATA(ls_db).

      IF sy-subrc = 0.
        ls_db-statusin = lv_statusin.
        ls_db-inlogmsg = CONV #( COND string(
          WHEN lv_statusin = 'O' THEN 'Log fetched successfully'
          WHEN lv_statusin = 'X' THEN 'Internal process failed'
          ELSE                        'Attachment not found' ) ).
        APPEND ls_db TO lt_update.
      ENDIF.

    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    " MODIFY는 UPDATE와 달리 허용되는지 테스트
    MODIFY zsd_is_log_kar FROM TABLE @lt_update.

  ENDMETHOD.

  METHOD fetchlog.
    LOOP AT keys INTO DATA(ls_key).

      DATA lv_attach_id TYPE string.
      DATA lv_statusin  TYPE c LENGTH 1.
      DATA lv_inlog     TYPE string.
      DATA lv_inlogmsg  TYPE c LENGTH 255.

      DATA(lo_save) = NEW zbpr_sd_is_log_save_kar( ).

      " ① get_attach_id로 statusin + attach_id 확정
      lo_save->get_attach_id(
        EXPORTING iv_messageguid = CONV #( ls_key-messageguid )
        IMPORTING ev_attach_id   = lv_attach_id
                  ev_statusin    = lv_statusin ).

      " ② attach_id 있으면 $value로 실제 로그 가져오기
      IF lv_attach_id IS NOT INITIAL.
        TRY.
            DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                              comm_scenario = 'ZCS_GAS_COMM'
                              service_id    = 'ZOB_ISLOG_REST' ).
            DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                                i_destination = lo_dest ).
            DATA(lo_req) = lo_client->get_http_request( ).
            lo_req->set_header_field( i_name = 'Accept' i_value = 'text/plain' ).
            lo_req->set_uri_path(
              i_uri_path = |http/gasentec/SD0000_006?Attachments%28%27{ lv_attach_id }%27%29/%24value| ).
            DATA(lo_res)   = lo_client->execute( i_method = if_web_http_client=>get ).
            DATA(lv_code)  = lo_res->get_status( )-code.
            lv_inlog       = lo_res->get_text( ).
            lo_client->close( ).

            lv_inlogmsg = CONV #( COND string(
              WHEN lv_code = 200 AND lv_statusin = 'O' THEN 'Log fetched successfully'
              WHEN lv_code = 200 AND lv_statusin = 'X' THEN 'Internal process failed'
              ELSE |HTTP Status { lv_code }| ) ).

          CATCH cx_http_dest_provider_error
                cx_web_http_client_error INTO DATA(lx).
            lv_inlogmsg = CONV #( lx->get_text( ) ).
        ENDTRY.
      ELSE.
        lv_inlogmsg = CONV #( COND string(
          WHEN lv_statusin = ' ' THEN 'Attachment not found'
          ELSE                        'Internal process failed' ) ).
      ENDIF.

      " ③ DB 업데이트
      UPDATE zsd_is_log_kar
        SET statusin = @lv_statusin,
            inlog    = @lv_inlog,
            inlogmsg = @lv_inlogmsg
        WHERE messageguid = @ls_key-messageguid.

      APPEND VALUE #(
        %tky               = ls_key-%tky
        %param-messageguid = ls_key-messageguid
        %param-inlogmsg    = lv_inlogmsg
        %param-inlog       = lv_inlog
      ) TO result.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
