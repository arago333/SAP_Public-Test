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

    DATA lv_module TYPE c LENGTH 3 VALUE 'SD'.
    DATA lo_save   TYPE REF TO zbpr_sd_is_log_save_kar.
    DATA lv_ok     TYPE abap_bool.
    DATA lv_msg    TYPE string.

    CREATE OBJECT lo_save.

    lo_save->fetch_and_save(
      EXPORTING
        iv_module = lv_module
      IMPORTING
        ev_ok     = lv_ok
        ev_msg    = lv_msg ).

  ENDMETHOD.

ENDCLASS.
