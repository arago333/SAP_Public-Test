CLASS lhc_sorequest DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR SoRequest RESULT result.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE SoRequest.
    METHODS earlynumbering_cba__items FOR NUMBERING
      IMPORTING entities FOR CREATE SoRequest\_Items.
    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SoRequest~setInitialStatus.
ENDCLASS.

CLASS lhc_sorequest IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.
    LOOP AT entities INTO DATA(ls_entity).
      IF ls_entity-ReqId IS INITIAL.
        TRY.
            ls_entity-ReqId = cl_system_uuid=>create_uuid_c22_static( ).
          CATCH cx_uuid_error.
            APPEND VALUE #( %cid = ls_entity-%cid ) TO failed-sorequest.
            CONTINUE.
        ENDTRY.
      ENDIF.
      APPEND VALUE #(
        %cid       = ls_entity-%cid
        %key-ReqId = ls_entity-ReqId
      ) TO mapped-sorequest.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_cba__items.
    LOOP AT entities INTO DATA(ls_entity).
      DATA(lv_itemno) = 0.
      LOOP AT ls_entity-%target INTO DATA(ls_target).
        lv_itemno = lv_itemno + 1.
        APPEND VALUE #(
         %cid           = ls_target-%cid
         %key-ReqId     = ls_entity-ReqId
         %key-ReqItemNo = lv_itemno
       ) TO mapped-sorequestitem.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD setInitialStatus.
    MODIFY ENTITIES OF zr_so_request_kar IN LOCAL MODE
      ENTITY SoRequest
        UPDATE FIELDS ( Status CreatedBy CreatedAt )
        WITH VALUE #(
          FOR ls IN keys (
            %key-ReqId = ls-ReqId
            Status     = '09'
            CreatedBy  = sy-uname
          )
        ).
  ENDMETHOD.

ENDCLASS.
