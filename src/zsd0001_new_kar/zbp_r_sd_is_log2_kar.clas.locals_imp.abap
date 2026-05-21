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
    DATA lv_module TYPE c LENGTH 3 VALUE 'SD'.
    DATA lo_save   TYPE REF TO zbpr_sd_is_log_save_kar.
    DATA lv_ok     TYPE abap_bool.
    DATA lv_msg    TYPE string.
    CREATE OBJECT lo_save.
    lo_save->fetch_and_save(
      EXPORTING iv_module = lv_module
      IMPORTING ev_ok     = lv_ok
                ev_msg    = lv_msg ).
  ENDMETHOD.
  METHOD fetchlog.
    LOOP AT keys INTO DATA(ls_key).

      DATA lv_inlog    TYPE string.
      DATA lv_statusin TYPE c LENGTH 1.
      DATA lv_inlogmsg TYPE c LENGTH 255.

      TRY.
          DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                            comm_scenario = 'ZCS_GAS_COMM'
                            service_id    = 'ZOB_ISLOG_REST' ).
          DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                              i_destination = lo_dest ).
          DATA(lo_req) = lo_client->get_http_request( ).
          lo_req->set_uri_path(
            i_uri_path =  |http/gasentec/SD0000_006?s%28%27{ ls_key-messageguid }%27%29/Attachments| ).
          DATA(lo_res)    = lo_client->execute( i_method = if_web_http_client=>get ).
          DATA(lv_status) = lo_res->get_status( )-code.
          lv_inlog        = lo_res->get_text( ).
          lo_client->close( ).

          IF lv_status = 200.
            lv_statusin = 'O'.
            lv_inlogmsg = 'Log fetched successfully'.
          ELSE.
            lv_statusin = 'X'.
            lv_inlogmsg = |HTTP Status { lv_status }|.
          ENDIF.

        CATCH cx_http_dest_provider_error
              cx_web_http_client_error INTO DATA(lx).
          lv_statusin = 'X'.
          lv_inlogmsg = lx->get_text( ).
      ENDTRY.

      UPDATE zsd_is_log_kar
        SET statusin = @lv_statusin,
            inlog    = @lv_inlog,
            inlogmsg = @lv_inlogmsg
        WHERE messageguid = @ls_key-messageguid.

      " $self → DB에서 최신 데이터 읽어서 반환
      SELECT SINGLE * FROM zsd_is_log_kar
        WHERE messageguid = @ls_key-messageguid
        INTO @DATA(ls_db).

      APPEND VALUE #(
        %tky               = ls_key-%tky
        %param-messageguid = ls_key-messageguid
        %param-inlogmsg    = lv_inlogmsg
        %param-inlog       = lv_inlog
      ) TO result.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
