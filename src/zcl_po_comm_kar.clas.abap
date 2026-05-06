CLASS zcl_po_comm_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ts_po_header,
             companycode             TYPE bukrs,
             supplier                TYPE lifnr,
             purchasingorganization  TYPE ekorg,
             purchasinggroup         TYPE ekgrp,
             purchaseordertype       TYPE c LENGTH 4,
             documentcurrency        TYPE waers,
             purchaseorderdate       TYPE d,
             paymentterms            TYPE dzterm,
             incotermsclassification TYPE c LENGTH 3,
             incotermslocation1      TYPE c LENGTH 70,
           END OF ts_po_header.

    TYPES: BEGIN OF ts_po_item,
             purchaseorderitem          TYPE ebelp,
             material                   TYPE matnr,
             plant                      TYPE werks_d,
             storagelocation            TYPE lgort_d,
             orderquantity              TYPE p LENGTH 8 DECIMALS 3,
             purchaseorderquantityunit  TYPE c LENGTH 3,
             netpriceamount             TYPE p LENGTH 8 DECIMALS 2,
             " abap_true  = 값 명시 전송 (0원 포함, API에 %control 켬)
             " abap_false = 미전송    (API 기본결정에 위임, %control 끔)
             netpriceamount_is_supplied TYPE abap_bool,
             taxcode                    TYPE mwskz,
             purchaseorderitemtext      TYPE txz01,
           END OF ts_po_item.
    TYPES tt_po_item TYPE TABLE OF ts_po_item WITH EMPTY KEY.

    TYPES: BEGIN OF ts_message,
             type    TYPE symsgty,
             message TYPE string,
           END OF ts_message.
    TYPES tt_messages TYPE TABLE OF ts_message WITH EMPTY KEY.

    TYPES: BEGIN OF ts_result,
             ebeln     TYPE ebeln,
             success   TYPE abap_bool,
             committed TYPE abap_bool,
             messages  TYPE tt_messages,
           END OF ts_result.

    CLASS-METHODS create_purchase_order
      IMPORTING
        !is_header       TYPE ts_po_header
        !it_item         TYPE tt_po_item
      RETURNING
        VALUE(rs_result) TYPE ts_result.

  PRIVATE SECTION.

    TYPES: BEGIN OF ts_find_context,
             created_by   TYPE syuname,
             changed_from TYPE timestampl,
             header       TYPE ts_po_header,
           END OF ts_find_context.

    TYPES tt_eml_header TYPE TABLE FOR CREATE i_purchaseordertp_2.
    TYPES tt_eml_item   TYPE TABLE FOR CREATE i_purchaseordertp_2\_PurchaseOrderItem.

    CLASS-METHODS validate_header
      IMPORTING
        !is_header         TYPE ts_po_header
      RETURNING
        VALUE(rt_messages) TYPE tt_messages.

    CLASS-METHODS validate_items
      IMPORTING
        !it_item           TYPE tt_po_item
      RETURNING
        VALUE(rt_messages) TYPE tt_messages.

    CLASS-METHODS build_eml_header
      IMPORTING
        !is_header TYPE ts_po_header
      EXPORTING
        !et_header TYPE tt_eml_header.

    CLASS-METHODS build_eml_items
      IMPORTING
        !it_item TYPE tt_po_item
      EXPORTING
        !et_item TYPE tt_eml_item.

    CLASS-METHODS execute_modify
      IMPORTING
        !it_header   TYPE tt_eml_header
        !it_item     TYPE tt_eml_item
      EXPORTING
        !ev_ebeln    TYPE ebeln
        !ev_error    TYPE abap_bool
        !et_messages TYPE tt_messages.

    CLASS-METHODS execute_commit
      EXPORTING
        !ev_error    TYPE abap_bool
        !et_messages TYPE tt_messages.

    CLASS-METHODS find_created_po
      IMPORTING
        !is_context     TYPE ts_find_context
      RETURNING
        VALUE(rv_ebeln) TYPE ebeln.

ENDCLASS.



CLASS zcl_po_comm_kar IMPLEMENTATION.


  METHOD create_purchase_order.

    CLEAR rs_result.

    APPEND LINES OF validate_header( is_header ) TO rs_result-messages.
    APPEND LINES OF validate_items( it_item )    TO rs_result-messages.

    DATA(lv_has_error) = xsdbool(
      line_exists( rs_result-messages[ type = 'E' ] ) OR
      line_exists( rs_result-messages[ type = 'A' ] ) OR
      line_exists( rs_result-messages[ type = 'X' ] )
    ).
    IF lv_has_error = abap_true.
      rs_result-success   = abap_false.
      rs_result-committed = abap_false.
      RETURN.
    ENDIF.

    DATA lt_eml_header TYPE tt_eml_header.
    DATA lt_eml_items  TYPE tt_eml_item.

    build_eml_header(
      EXPORTING is_header = is_header
      IMPORTING et_header = lt_eml_header
    ).

    build_eml_items(
      EXPORTING it_item = it_item
      IMPORTING et_item = lt_eml_items
    ).

    DATA(ls_find_context) = VALUE ts_find_context(
      created_by = sy-uname
      header     = is_header
    ).
    GET TIME STAMP FIELD ls_find_context-changed_from.

    execute_modify(
      EXPORTING
        it_header   = lt_eml_header
        it_item     = lt_eml_items
      IMPORTING
        ev_ebeln    = DATA(lv_modify_ebeln)
        ev_error    = DATA(lv_modify_error)
        et_messages = DATA(lt_modify_msgs)
    ).

    IF lv_modify_error = abap_true.
      rs_result-success   = abap_false.
      rs_result-committed = abap_false.
      APPEND LINES OF lt_modify_msgs TO rs_result-messages.
      RETURN.
    ENDIF.

    execute_commit(
      IMPORTING
        ev_error    = DATA(lv_commit_error)
        et_messages = DATA(lt_commit_msgs)
    ).

    IF lv_commit_error = abap_true.
      rs_result-success   = abap_false.
      rs_result-committed = abap_false.
      APPEND LINES OF lt_commit_msgs TO rs_result-messages.
      RETURN.
    ENDIF.

    rs_result-committed = abap_true.
    rs_result-success   = abap_true.
    rs_result-ebeln     = lv_modify_ebeln.

    IF rs_result-ebeln IS INITIAL.
      rs_result-ebeln = find_created_po( ls_find_context ).
    ENDIF.

    IF rs_result-ebeln IS NOT INITIAL.
      APPEND VALUE #(
        type    = 'S'
        message = |구매오더 생성 성공: { rs_result-ebeln }|
      ) TO rs_result-messages.
    ELSE.
      APPEND VALUE #(
        type    = 'W'
        message = '구매오더 생성은 성공했으나 번호를 확정하지 못했습니다.'
      ) TO rs_result-messages.
    ENDIF.

  ENDMETHOD.


  METHOD validate_header.

    IF is_header-companycode IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'CompanyCode(회사코드)가 누락되었습니다.' ) TO rt_messages.
    ENDIF.
    IF is_header-supplier IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'Supplier(공급업체)가 누락되었습니다.' ) TO rt_messages.
    ENDIF.
    IF is_header-purchasingorganization IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'PurchasingOrganization(구매조직)이 누락되었습니다.' ) TO rt_messages.
    ENDIF.
    IF is_header-purchasinggroup IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'PurchasingGroup(구매그룹)이 누락되었습니다.' ) TO rt_messages.
    ENDIF.
    IF is_header-purchaseordertype IS INITIAL.
      APPEND VALUE #( type = 'E' message = 'PurchaseOrderType(오더유형)이 누락되었습니다.' ) TO rt_messages.
    ENDIF.

  ENDMETHOD.


  METHOD validate_items.

    IF it_item IS INITIAL.
      APPEND VALUE #( type = 'E' message = '아이템 데이터가 없습니다.' ) TO rt_messages.
      RETURN.
    ENDIF.

    DATA lt_item_nos TYPE SORTED TABLE OF ebelp WITH UNIQUE KEY table_line.

    LOOP AT it_item INTO DATA(ls_item).
      DATA(lv_idx) = sy-tabix.

      IF ls_item-material IS INITIAL.
        APPEND VALUE #( type = 'E' message = |Item { lv_idx }: Material(자재) 누락| ) TO rt_messages.
      ENDIF.
      IF ls_item-plant IS INITIAL.
        APPEND VALUE #( type = 'E' message = |Item { lv_idx }: Plant(플랜트) 누락| ) TO rt_messages.
      ENDIF.
      IF ls_item-orderquantity IS INITIAL.
        APPEND VALUE #( type = 'E' message = |Item { lv_idx }: OrderQuantity(수량) 누락| ) TO rt_messages.
      ENDIF.
      IF ls_item-purchaseorderquantityunit IS INITIAL.
        APPEND VALUE #( type = 'E' message = |Item { lv_idx }: PurchaseOrderQuantityUnit(수량단위) 누락| ) TO rt_messages.
      ENDIF.

      IF ls_item-purchaseorderitem IS NOT INITIAL.
        INSERT ls_item-purchaseorderitem INTO TABLE lt_item_nos.
        IF sy-subrc <> 0.
          APPEND VALUE #(
            type    = 'E'
            message = |Item { lv_idx }: PurchaseOrderItem(순번) { ls_item-purchaseorderitem } 중복|
          ) TO rt_messages.
        ENDIF.
      ENDIF.

      IF ls_item-netpriceamount IS NOT INITIAL
        AND ls_item-netpriceamount_is_supplied = abap_false.
        APPEND VALUE #(
          type    = 'W'
          message = |Item { lv_idx }: NetPriceAmount(단가) 값이 있으나 netpriceamount_is_supplied가 space — 가격이 전송되지 않습니다|
        ) TO rt_messages.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD build_eml_header.

    CLEAR et_header.

    DATA ls_entry TYPE LINE OF tt_eml_header.
    DATA ls_ctrl  LIKE ls_entry-%control.
    ls_ctrl-purchaseordertype      = cl_abap_behv=>flag_changed.
    ls_ctrl-companycode            = cl_abap_behv=>flag_changed.
    ls_ctrl-purchasingorganization = cl_abap_behv=>flag_changed.
    ls_ctrl-purchasinggroup        = cl_abap_behv=>flag_changed.
    ls_ctrl-supplier               = cl_abap_behv=>flag_changed.

    IF is_header-documentcurrency        IS NOT INITIAL. ls_ctrl-documentcurrency        = cl_abap_behv=>flag_changed. ENDIF.
    IF is_header-purchaseorderdate       IS NOT INITIAL. ls_ctrl-purchaseorderdate       = cl_abap_behv=>flag_changed. ENDIF.
    IF is_header-paymentterms            IS NOT INITIAL. ls_ctrl-paymentterms            = cl_abap_behv=>flag_changed. ENDIF.
    IF is_header-incotermsclassification IS NOT INITIAL. ls_ctrl-incotermsclassification = cl_abap_behv=>flag_changed. ENDIF.
    IF is_header-incotermslocation1      IS NOT INITIAL. ls_ctrl-incotermslocation1      = cl_abap_behv=>flag_changed. ENDIF.

    APPEND VALUE #(
      %cid                    = 'PO1'
      purchaseordertype       = is_header-purchaseordertype
      companycode             = is_header-companycode
      purchasingorganization  = is_header-purchasingorganization
      purchasinggroup         = is_header-purchasinggroup
      supplier                = is_header-supplier
      documentcurrency        = is_header-documentcurrency
      purchaseorderdate       = is_header-purchaseorderdate
      paymentterms            = is_header-paymentterms
      incotermsclassification = is_header-incotermsclassification
      incotermslocation1      = is_header-incotermslocation1
      %control                = ls_ctrl
    ) TO et_header.

  ENDMETHOD.


  METHOD build_eml_items.

    CLEAR et_item.

    DATA ls_item_entry TYPE LINE OF tt_eml_item.
    DATA ls_item_line  LIKE LINE OF ls_item_entry-%target.
    DATA ls_ctrl       LIKE ls_item_line-%control.

    ls_item_entry-%cid_ref = 'PO1'.

    LOOP AT it_item INTO DATA(ls_item).

      CLEAR ls_ctrl.
      ls_ctrl-material                  = cl_abap_behv=>flag_changed.
      ls_ctrl-plant                     = cl_abap_behv=>flag_changed.
      ls_ctrl-orderquantity             = cl_abap_behv=>flag_changed.
      ls_ctrl-purchaseorderquantityunit = cl_abap_behv=>flag_changed.

      IF ls_item-purchaseorderitem     IS NOT INITIAL. ls_ctrl-purchaseorderitem     = cl_abap_behv=>flag_changed. ENDIF.
      IF ls_item-storagelocation       IS NOT INITIAL. ls_ctrl-storagelocation       = cl_abap_behv=>flag_changed. ENDIF.
      IF ls_item-netpriceamount_is_supplied = abap_true.
        ls_ctrl-netpriceamount = cl_abap_behv=>flag_changed.
      ENDIF.
      IF ls_item-taxcode               IS NOT INITIAL. ls_ctrl-taxcode               = cl_abap_behv=>flag_changed. ENDIF.
      IF ls_item-purchaseorderitemtext IS NOT INITIAL. ls_ctrl-purchaseorderitemtext = cl_abap_behv=>flag_changed. ENDIF.

      APPEND VALUE #(
        %cid                      = |POITEM{ sy-tabix }|
        purchaseorderitem         = ls_item-purchaseorderitem
        material                  = ls_item-material
        plant                     = ls_item-plant
        storagelocation           = ls_item-storagelocation
        orderquantity             = ls_item-orderquantity
        purchaseorderquantityunit = ls_item-purchaseorderquantityunit
        netpriceamount            = ls_item-netpriceamount
        taxcode                   = ls_item-taxcode
        purchaseorderitemtext     = ls_item-purchaseorderitemtext
        %control                  = ls_ctrl
      ) TO ls_item_entry-%target.

    ENDLOOP.

    IF ls_item_entry-%target IS NOT INITIAL.
      APPEND ls_item_entry TO et_item.
    ENDIF.

  ENDMETHOD.

  METHOD execute_modify.

    CLEAR: ev_ebeln, ev_error, et_messages.

    TRY.
        MODIFY ENTITIES OF i_purchaseordertp_2
          ENTITY PurchaseOrder
            CREATE FROM it_header
            CREATE BY \_PurchaseOrderItem FROM it_item
            MAPPED   DATA(ls_mapped)
            FAILED   DATA(ls_failed)
            REPORTED DATA(ls_reported).
      CATCH cx_root INTO DATA(lx_error).
        ROLLBACK ENTITIES.
        ev_error = abap_true.
        APPEND VALUE #(
          type    = 'E'
          message = |MODIFY ENTITIES 예외: { lx_error->get_text( ) }|
        ) TO et_messages.
        RETURN.
    ENDTRY.

    IF ls_failed IS NOT INITIAL.
      ev_error = abap_true.
      ROLLBACK ENTITIES.

      LOOP AT ls_reported-purchaseorder INTO DATA(ls_po_err).
        IF ls_po_err-%msg IS BOUND.
          APPEND VALUE #( type = 'E'
            message = ls_po_err-%msg->if_message~get_text( )
          ) TO et_messages.
        ENDIF.
      ENDLOOP.

      LOOP AT ls_reported-purchaseorderitem INTO DATA(ls_item_err).
        IF ls_item_err-%msg IS BOUND.
          APPEND VALUE #( type = 'E'
            message = ls_item_err-%msg->if_message~get_text( )
          ) TO et_messages.
        ENDIF.
      ENDLOOP.

      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '구매오더 생성 요청 실패' ) TO et_messages.
      ENDIF.
      RETURN.
    ENDIF.

    LOOP AT ls_mapped-purchaseorder INTO DATA(ls_po).
      IF ls_po-purchaseorder IS NOT INITIAL.
        ev_ebeln = ls_po-purchaseorder.
        EXIT.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD execute_commit.

    CLEAR: ev_error, et_messages.

    COMMIT ENTITIES RESPONSE OF i_purchaseordertp_2
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    " sy-subrc: ls_failed에 안 잡힌 COMMIT 실패 케이스 방어
    IF sy-subrc <> 0 AND ls_failed IS INITIAL.
      ev_error = abap_true.
      APPEND VALUE #(
        type    = 'E'
        message = '구매오더 COMMIT 실패 (sy-subrc)'
      ) TO et_messages.
    ENDIF.

    IF ls_failed IS NOT INITIAL.
      ev_error = abap_true.

      LOOP AT ls_reported-purchaseorder INTO DATA(ls_po_err).
        IF ls_po_err-%msg IS BOUND.
          APPEND VALUE #( type = 'E'
            message = ls_po_err-%msg->if_message~get_text( )
          ) TO et_messages.
        ENDIF.
      ENDLOOP.

      LOOP AT ls_reported-purchaseorderitem INTO DATA(ls_item_err).
        IF ls_item_err-%msg IS BOUND.
          APPEND VALUE #( type = 'E'
            message = ls_item_err-%msg->if_message~get_text( )
          ) TO et_messages.
        ENDIF.
      ENDLOOP.

      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '구매오더 COMMIT 실패' ) TO et_messages.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD find_created_po.

    SELECT PurchaseOrder
      FROM I_PurchaseOrderAPI01
      WHERE CreatedByUser          = @is_context-created_by
        AND CompanyCode            = @is_context-header-companycode
        AND Supplier               = @is_context-header-supplier
        AND PurchasingOrganization = @is_context-header-purchasingorganization
        AND PurchasingGroup        = @is_context-header-purchasinggroup
        AND PurchaseOrderType      = @is_context-header-purchaseordertype
        AND LastChangeDateTime     >= @is_context-changed_from
        AND ( @is_context-header-documentcurrency IS INITIAL
              OR DocumentCurrency = @is_context-header-documentcurrency )
        AND ( @is_context-header-purchaseorderdate IS INITIAL
              OR PurchaseOrderDate = @is_context-header-purchaseorderdate )
      ORDER BY LastChangeDateTime DESCENDING, PurchaseOrder DESCENDING
      INTO TABLE @DATA(lt_found)
      UP TO 2 ROWS.

    IF lines( lt_found ) = 1.
      rv_ebeln = lt_found[ 1 ]-PurchaseOrder.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
