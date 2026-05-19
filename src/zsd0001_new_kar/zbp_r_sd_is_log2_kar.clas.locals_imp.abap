CLASS lhc_ZR_SD_IS_LOG2_KAR DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.


    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR IsLog RESULT result.
    METHODS fetchlogs FOR MODIFY
      IMPORTING keys FOR ACTION IsLog~fetchlogs..

ENDCLASS.

CLASS lhc_ZR_SD_IS_LOG2_KAR IMPLEMENTATION.


  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD fetchlogs.

    " ① 필터/페이징 없이 전체 조회용 변수
    DATA lv_module TYPE c LENGTH 3 VALUE 'SD'.

    " ② Base URL 선언 (아까 만든 것과 동일)
    DATA(lv_base_url) = |http/gasentec/SD0000_005| &&
                        |?$format=json| &&
                        |&$filter=substringof('{ lv_module }',IntegrationFlowName)| &&
                        | and not substringof('LOG',IntegrationFlowName)| &&
                        |&$orderby=LogStart desc|.

    " ③ IS API 호출
    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                  comm_scenario = 'ZCS_GAS_COMM' ).
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination(
                                  i_destination = lo_destination ).
        DATA(lo_request) = lo_http_client->get_http_request( ).
        lo_request->set_uri_path(
          i_uri_path = |{ lv_base_url }&$top=100&$skip=0| ).
        DATA(lo_response) = lo_http_client->execute(
                               i_method = if_web_http_client=>get ).
        DATA(lv_response) = lo_response->get_text( ).
        lo_http_client->close( ).
      CATCH cx_http_dest_provider_error
            cx_web_http_client_error.
        RETURN.
    ENDTRY.

    " ④ JSON 파싱
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

    " ⑤ API 2용 클라이언트
    TRY.
        DATA(lo_dest2) = cl_http_destination_provider=>create_by_comm_arrangement(
                           comm_scenario = 'ZCS_GAS_COMM' ).
        DATA(lo_client2) = cl_web_http_client_manager=>create_by_http_destination(
                             i_destination = lo_dest2 ).
      CATCH cx_http_dest_provider_error
            cx_web_http_client_error.
        RETURN.
    ENDTRY.

    " ⑥ 결과 테이블 (DB 직접 저장용)
    DATA lt_db TYPE TABLE OF zsd_is_log_kar.

    LOOP AT ls_response-d-results INTO DATA(ls_log).

      " LastChangeTime 변환
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

      DATA(lv_status_is) = SWITCH #( ls_log-status
                             WHEN 'COMPLETED' THEN 'O'
                             WHEN 'FAILED'    THEN 'X'
                             ELSE ' ' ).

      DATA lv_status_in TYPE c LENGTH 1.
      DATA lv_inlog     TYPE string.

      IF ls_log-status = 'COMPLETED'.
        TRY.
            DATA(lo_req2) = lo_client2->get_http_request( ).
            lo_req2->set_uri_path(
              i_uri_path = |http/gasentec/SD0000_006?s('{ ls_log-messageguid }')/Attachments| ).
            DATA(lo_res2) = lo_client2->execute( i_method = if_web_http_client=>get ).
            DATA(lv_status2) = lo_res2->get_status( )-code.
            lv_inlog = lo_res2->get_text( ).
            IF lv_status2 = 200.
              lv_status_in = 'O'.
            ELSE.
              lv_status_in = 'X'.
            ENDIF.
          CATCH cx_web_http_client_error
                cx_http_dest_provider_error.
            lv_status_in = 'X'.
        ENDTRY.
      ENDIF.

      APPEND VALUE zsd_is_log_kar(
        client      = sy-mandt
        messageguid = ls_log-messageguid
        statusis    = lv_status_is
        statusin    = lv_status_in
        flowname    = ls_log-integrationflowname
        lasttime    = lv_last_time
        inlog       = lv_inlog
      ) TO lt_db.

    ENDLOOP.

    " ⑧ DB에 직접 UPSERT
    MODIFY zsd_is_log_kar FROM TABLE @lt_db.

  ENDMETHOD.

ENDCLASS.
