CLASS zcl_matdoc_job_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
ENDCLASS.



CLASS ZCL_MATDOC_JOB_KAR IMPLEMENTATION.


  METHOD if_apj_rt_exec_object~execute.

    CONSTANTS:
      lc_status_wait    TYPE c LENGTH 2 VALUE '09',
      lc_status_success TYPE c LENGTH 2 VALUE '01',
      lc_status_check   TYPE c LENGTH 2 VALUE '05',
      lc_status_error   TYPE c LENGTH 2 VALUE '99'.

    TYPES: BEGIN OF ts_header,
             req_id                     TYPE sysuuid_c22,
             goodsmovementcode          TYPE c LENGTH 2,
             postingdate                TYPE budat,
             documentdate               TYPE bldat,
             materialdocumentheadertext TYPE c LENGTH 25,
             referencedocument          TYPE c LENGTH 16,
           END OF ts_header.

    TYPES: BEGIN OF ts_item,
             req_id                   TYPE sysuuid_c22,
             req_item_no              TYPE n LENGTH 6,
             plant                    TYPE werks_d,
             material                 TYPE matnr,
             storagelocation          TYPE lgort_d,
             goodsmovementtype        TYPE bwart,
             quantityinentryunit      TYPE p LENGTH 8 DECIMALS 3,
             entryunit                TYPE meins,
             batch                    TYPE charg_d,
             purchaseorder            TYPE ebeln,
             purchaseorderitem        TYPE ebelp,
             costcenter               TYPE kostl,
             glaccount                TYPE hkont,
             materialdocumentitemtext TYPE c LENGTH 50,
           END OF ts_item.

    DATA lt_headers TYPE TABLE OF ts_header WITH EMPTY KEY.
    DATA lt_all_items TYPE TABLE OF ts_item WITH EMPTY KEY.

    SELECT req_id,
           goodsmovementcode,
           postingdate,
           documentdate,
           materialdocumentheadertext,
           referencedocument
      FROM zmdoc_req_h_kar
      WHERE status = @lc_status_wait
      INTO TABLE @lt_headers.

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    SELECT req_id,
           req_item_no,
           plant,
           material,
           storagelocation,
           goodsmovementtype,
           quantityinentryunit,
           entryunit,
           batch,
           purchaseorder,
           purchaseorderitem,
           costcenter,
           glaccount,
           materialdocumentitemtext
      FROM zmdoc_req_i_kar
      FOR ALL ENTRIES IN @lt_headers
      WHERE req_id = @lt_headers-req_id
      INTO TABLE @lt_all_items.

    DATA ls_header      TYPE zcl_matdoc_comm_kar=>ts_header.
    DATA lt_items       TYPE zcl_matdoc_comm_kar=>tt_items.
    DATA lv_matdoc      TYPE mblnr.
    DATA lv_matdocyr    TYPE mjahr.
    DATA lt_messages    TYPE bapirettab.
    DATA lv_msg_type    TYPE c LENGTH 1.
    DATA lv_msg_text    TYPE c LENGTH 255.
    DATA lv_timestamp   TYPE abp_lastchange_tstmpl.
    DATA lv_status      TYPE c LENGTH 2.

    LOOP AT lt_headers INTO DATA(ls_req_header).

      CLEAR:
        ls_header,
        lt_items,
        lv_matdoc,
        lv_matdocyr,
        lt_messages,
        lv_msg_type,
        lv_msg_text,
        lv_timestamp,
        lv_status.

      GET TIME STAMP FIELD lv_timestamp.

      lt_items = VALUE #(
        FOR ls_req_item IN lt_all_items
        WHERE ( req_id = ls_req_header-req_id )
        (
          plant                    = ls_req_item-plant
          material                 = ls_req_item-material
          storagelocation          = ls_req_item-storagelocation
          goodsmovementtype        = ls_req_item-goodsmovementtype
          quantityinentryunit      = ls_req_item-quantityinentryunit
          entryunit                = ls_req_item-entryunit
          batch                    = ls_req_item-batch
          purchaseorder            = ls_req_item-purchaseorder
          purchaseorderitem        = ls_req_item-purchaseorderitem
          costcenter               = ls_req_item-costcenter
          glaccount                = ls_req_item-glaccount
          materialdocumentitemtext = ls_req_item-materialdocumentitemtext
        )
      ).

      IF lt_items IS INITIAL.
        UPDATE zmdoc_req_h_kar
          SET status          = @lc_status_error,
              message_type    = 'E',
              message_text    = '아이템 데이터가 없습니다.',
              last_changed_by = @sy-uname,
              last_changed_at = @lv_timestamp
          WHERE req_id = @ls_req_header-req_id.
        CONTINUE.
      ENDIF.

      ls_header = VALUE #(
        goodsmovementcode          = ls_req_header-goodsmovementcode
        postingdate                = ls_req_header-postingdate
        documentdate               = ls_req_header-documentdate
        materialdocumentheadertext = ls_req_header-materialdocumentheadertext
        referencedocument          = ls_req_header-referencedocument
      ).

      zcl_matdoc_comm_kar=>material_document_post(
        EXPORTING
          is_header   = ls_header
          it_items    = lt_items
        IMPORTING
          ev_matdoc   = lv_matdoc
          ev_matdocyr = lv_matdocyr
          et_messages = lt_messages
      ).

*      IF lv_matdoc IS INITIAL OR lv_matdocyr IS INITIAL.
*        zcl_matdoc_comm_kar=>material_document_resolve(
*          EXPORTING
*            is_header   = ls_header
*            iv_username = sy-uname
*          IMPORTING
*            ev_matdoc   = lv_matdoc
*            ev_matdocyr = lv_matdocyr
*            et_messages = DATA(lt_resolve_msgs)
*        ).
*
*        APPEND LINES OF lt_resolve_msgs TO lt_messages.
*      ENDIF.

      IF line_exists( lt_messages[ type = 'E' ] ).
        lv_status = lc_status_error.
      ELSEIF lv_matdoc IS NOT INITIAL AND lv_matdocyr IS NOT INITIAL.
        lv_status = lc_status_success.
      ELSE.
        lv_status = lc_status_check.
      ENDIF.

      IF lv_status = lc_status_success.
        lv_msg_type = 'S'.
        lv_msg_text = |자재문서 생성 성공: { lv_matdoc } / { lv_matdocyr }|.

      ELSEIF lv_status = lc_status_error.
        lv_msg_type = 'E'.

        IF lt_messages IS NOT INITIAL.
          DATA(lv_full_msg) = concat_lines_of(
            table = VALUE string_table(
              FOR ls_msg IN lt_messages ( CONV string( ls_msg-message ) )
            )
            sep = ' | '
          ).

          IF strlen( lv_full_msg ) > 255.
            lv_msg_text = lv_full_msg+0(255).
          ELSE.
            lv_msg_text = lv_full_msg.
          ENDIF.
        ENDIF.

      ELSE.
        lv_msg_type = 'W'.

        IF lt_messages IS NOT INITIAL.
          DATA(lv_full_msg2) = concat_lines_of(
            table = VALUE string_table(
              FOR ls_msg IN lt_messages ( CONV string( ls_msg-message ) )
            )
            sep = ' | '
          ).

          IF strlen( lv_full_msg2 ) > 255.
            lv_msg_text = lv_full_msg2+0(255).
          ELSE.
            lv_msg_text = lv_full_msg2.
          ENDIF.
        ENDIF.
      ENDIF.


      IF lv_status = lc_status_success.
        UPDATE zmdoc_req_h_kar
          SET status          = @lc_status_success,
              matdoc          = @lv_matdoc,
              matdocyr        = @lv_matdocyr,
              message_type    = @lv_msg_type,
              message_text    = @lv_msg_text,
              last_changed_by = @sy-uname,
              last_changed_at = @lv_timestamp
          WHERE req_id = @ls_req_header-req_id.

      ELSEIF lv_status = lc_status_check.
        UPDATE zmdoc_req_h_kar
          SET status          = @lc_status_check,
              message_type    = @lv_msg_type,
              message_text    = @lv_msg_text,
              last_changed_by = @sy-uname,
              last_changed_at = @lv_timestamp
          WHERE req_id = @ls_req_header-req_id.

      ELSE.
        UPDATE zmdoc_req_h_kar
          SET status          = @lc_status_error,
              message_type    = @lv_msg_type,
              message_text    = @lv_msg_text,
              last_changed_by = @sy-uname,
              last_changed_at = @lv_timestamp
          WHERE req_id = @ls_req_header-req_id.
      ENDIF.

    ENDLOOP.

    COMMIT WORK.

  ENDMETHOD.


  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( ).
  ENDMETHOD.
ENDCLASS.
