CLASS zcl_so_comm_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES: BEGIN OF ts_so_header,
             salesordertype          TYPE auart,
             salesorganization       TYPE vkorg,
             distributionchannel     TYPE vtweg,
             organizationdivision    TYPE spart,
             soldtoparty             TYPE kunnr,
             purchaseorderbycustomer TYPE bstkd,
             requesteddeliverydate   TYPE edatu,
           END OF ts_so_header.

    TYPES: BEGIN OF ts_so_item,
             salesorderitem        TYPE posnv,
             product               TYPE matnr,
             requestedquantity     TYPE kwmeng,
             requestedquantityunit TYPE vrkme,
             plant                 TYPE werks_d,
             salesorderitemtext    TYPE arktx,
           END OF ts_so_item.
    TYPES tt_so_item TYPE TABLE OF ts_so_item WITH EMPTY KEY.

    TYPES: BEGIN OF ts_message,
             type    TYPE symsgty,
             message TYPE string,
           END OF ts_message.
    TYPES tt_messages TYPE TABLE OF ts_message WITH EMPTY KEY.

    TYPES: BEGIN OF ts_result,
             vbeln     TYPE vbeln_va,
             success   TYPE abap_boolean,
             committed TYPE abap_boolean,
             messages  TYPE tt_messages,
           END OF ts_result.

    CLASS-METHODS create_sales_order
      IMPORTING
        is_header        TYPE ts_so_header
        it_item          TYPE tt_so_item
      RETURNING
        VALUE(rs_result) TYPE ts_result.

ENDCLASS.



CLASS ZCL_SO_COMM_KAR IMPLEMENTATION.


  METHOD create_sales_order.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " ① 필수값 체크
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    IF is_header-salesordertype IS INITIAL.
      APPEND VALUE #( type = 'E' message = '오더유형이 누락되었습니다.' ) TO rs_result-messages.
    ENDIF.
    IF is_header-salesorganization IS INITIAL.
      APPEND VALUE #( type = 'E' message = '판매조직이 누락되었습니다.' ) TO rs_result-messages.
    ENDIF.
    IF is_header-distributionchannel IS INITIAL.
      APPEND VALUE #( type = 'E' message = '유통채널이 누락되었습니다.' ) TO rs_result-messages.
    ENDIF.
    IF is_header-soldtoparty IS INITIAL.
      APPEND VALUE #( type = 'E' message = '판매처가 누락되었습니다.' ) TO rs_result-messages.
    ENDIF.
    IF it_item IS INITIAL.
      APPEND VALUE #( type = 'E' message = '아이템이 누락되었습니다.' ) TO rs_result-messages.
    ENDIF.

    DATA(lv_has_error) = xsdbool( line_exists( rs_result-messages[ type = 'E' ] ) ).
    IF lv_has_error = abap_true.
      rs_result-success   = abap_false.
      rs_result-committed = abap_false.
      RETURN.
    ENDIF.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " ② EML 타입 선언
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    DATA lt_so_header_create TYPE TABLE FOR CREATE i_salesordertp.
    DATA lt_item_create      TYPE TABLE FOR CREATE i_salesordertp\_item.
    DATA ls_so   LIKE LINE OF lt_so_header_create.
    DATA ls_item LIKE LINE OF lt_item_create.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " ③ 헤더 파라미터 세팅
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    ls_so-%cid = 'SO1'.
    ls_so-%data = VALUE #(
      salesordertype          = is_header-salesordertype
      salesorganization       = is_header-salesorganization
      distributionchannel     = is_header-distributionchannel
      organizationdivision    = is_header-organizationdivision
      soldtoparty             = is_header-soldtoparty
      purchaseorderbycustomer = is_header-purchaseorderbycustomer
      requesteddeliverydate   = is_header-requesteddeliverydate
    ).
    ls_so-%control = VALUE #(
      salesordertype          = if_abap_behv=>mk-on
      salesorganization       = if_abap_behv=>mk-on
      distributionchannel     = if_abap_behv=>mk-on
      organizationdivision    = if_abap_behv=>mk-on
      soldtoparty             = if_abap_behv=>mk-on
      purchaseorderbycustomer = if_abap_behv=>mk-on
      requesteddeliverydate   = if_abap_behv=>mk-on
    ).
    APPEND ls_so TO lt_so_header_create.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " ④ 아이템 파라미터 세팅
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    ls_item-%cid_ref = 'SO1'.
    LOOP AT it_item INTO DATA(ls_src_item).
      APPEND VALUE #(
        %cid                           = |SOITEM{ sy-tabix }|
        salesorderitem                 = ls_src_item-salesorderitem
        product                        = ls_src_item-product
        requestedquantity              = ls_src_item-requestedquantity
        requestedquantityunit          = ls_src_item-requestedquantityunit
        plant                          = ls_src_item-plant
        salesorderitemtext             = ls_src_item-salesorderitemtext
        %control-product               = if_abap_behv=>mk-on
        %control-requestedquantity     = if_abap_behv=>mk-on
        %control-requestedquantityunit = if_abap_behv=>mk-on
        %control-plant                 = if_abap_behv=>mk-on
        %control-salesorderitemtext    = if_abap_behv=>mk-on
      ) TO ls_item-%target.
    ENDLOOP.
    APPEND ls_item TO lt_item_create.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " ⑤ MODIFY ENTITIES PRIVILEGED
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    TRY.
        MODIFY ENTITIES OF i_salesordertp
          ENTITY salesorder
            CREATE FROM lt_so_header_create
            CREATE BY \_item FROM lt_item_create
          MAPPED   DATA(ls_mapped)
          FAILED   DATA(ls_failed)
          REPORTED DATA(ls_reported).

      CATCH cx_root INTO DATA(lx_error).
        APPEND VALUE #(
          type    = 'E'
          message = |MODIFY ENTITIES 예외: { lx_error->get_text( ) }|
        ) TO rs_result-messages.
        rs_result-success   = abap_false.
        rs_result-committed = abap_false.
        RETURN.
    ENDTRY.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " ⑥ FAILED 에러 처리
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    IF ls_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.

      LOOP AT ls_reported-salesorder INTO DATA(ls_hdr_err).
        IF ls_hdr_err-%msg IS BOUND.
          APPEND VALUE #(
            type    = 'E'
            message = ls_hdr_err-%msg->if_message~get_text( )
          ) TO rs_result-messages.
        ENDIF.
      ENDLOOP.

      LOOP AT ls_reported-salesorderitem INTO DATA(ls_itm_err).
        IF ls_itm_err-%msg IS BOUND.
          APPEND VALUE #(
            type    = 'E'
            message = ls_itm_err-%msg->if_message~get_text( )
          ) TO rs_result-messages.
        ENDIF.
      ENDLOOP.

      IF rs_result-messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '판매오더 생성 실패' ) TO rs_result-messages.
      ENDIF.

      rs_result-success   = abap_false.
      rs_result-committed = abap_false.
      RETURN.
    ENDIF.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " ⑦ COMMIT ENTITIES BEGIN...END
    "    번호 추출도 BEGIN...END 안에서 함께 처리
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    DATA(lv_commit_error) = abap_false.

    COMMIT ENTITIES BEGIN
   RESPONSE OF i_salesordertp
   FAILED   DATA(ls_commit_failed)
   REPORTED DATA(ls_commit_reported).

    IF ls_commit_failed IS INITIAL.
      LOOP AT ls_mapped-salesorder ASSIGNING FIELD-SYMBOL(<ls_mapped_hdr>).
        CONVERT KEY OF i_salesordertp\\salesorder
          FROM <ls_mapped_hdr>-%pid
          TO DATA(ls_final_key).
        rs_result-vbeln = ls_final_key-salesorder.
        EXIT.
      ENDLOOP.
    ELSE.
      lv_commit_error = abap_true.
    ENDIF.

    COMMIT ENTITIES END.

    IF sy-subrc <> 0.
      lv_commit_error = abap_true.
    ENDIF.

    IF lv_commit_error = abap_true.
      ROLLBACK ENTITIES.
      LOOP AT ls_commit_reported-salesorder INTO DATA(ls_cmt_err).
        IF ls_cmt_err-%msg IS BOUND.
          APPEND VALUE #(
            type    = 'E'
            message = ls_cmt_err-%msg->if_message~get_text( )
          ) TO rs_result-messages.
        ENDIF.
      ENDLOOP.
      rs_result-success   = abap_false.
      rs_result-committed = abap_false.
      RETURN.
    ENDIF.

    rs_result-committed = abap_true.

    IF rs_result-vbeln IS NOT INITIAL.
      rs_result-success = abap_true.
      APPEND VALUE #(
        type    = 'S'
        message = |판매오더 생성 성공: { rs_result-vbeln }|
      ) TO rs_result-messages.
    ELSE.
      rs_result-success = abap_true.
      APPEND VALUE #(
        type    = 'W'
        message = '판매오더 생성은 성공했으나 번호를 확정하지 못했습니다.'
      ) TO rs_result-messages.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
