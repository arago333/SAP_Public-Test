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

    DATA(lo_save) = NEW zbpr_sd_is_log_save_kar( ).
    lo_save->fetch_and_save( iv_module = lv_module ).

  ENDMETHOD.

ENDCLASS.
