CLASS zcl_test_data_insert DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CLASS-METHODS insert_mdoc_header
      IMPORTING
        iv_req_id TYPE sysuuid_c22.

    CLASS-METHODS insert_mdoc_item_gr501
      IMPORTING
        iv_req_id TYPE sysuuid_c22.

    CLASS-METHODS insert_mdoc_item_gi201
      IMPORTING
        iv_req_id TYPE sysuuid_c22.

    CLASS-METHODS insert_po_header
      IMPORTING iv_req_id TYPE sysuuid_c22.  " iv_req_id로 통일

    CLASS-METHODS insert_po_item
      IMPORTING iv_req_id TYPE sysuuid_c22.

    CLASS-METHODS insert_so_header
      IMPORTING iv_req_id TYPE sysuuid_c22.

    CLASS-METHODS insert_so_item
      IMPORTING iv_req_id TYPE sysuuid_c22.
ENDCLASS.



CLASS zcl_test_data_insert IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    DATA lv_req_id TYPE sysuuid_c22.

    TRY.
        lv_req_id = cl_system_uuid=>create_uuid_c22_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        out->write( |UUID 생성 오류: { lx_uuid->get_text( ) }| ).
        RETURN.
    ENDTRY.

    out->write( |테스트용 ReqId 생성: { lv_req_id }| ).

    " ==================================================
    " Material Document 테스트 데이터
    " 필요할 때 원하는 시나리오만 사용
    " ==================================================

*    insert_mdoc_header( iv_req_id = lv_req_id ).
*    insert_mdoc_item_gr501( iv_req_id = lv_req_id ).
*    insert_mdoc_item_gi201( iv_req_id = lv_req_id ).
*    insert_po_test( iv_purchaseorder = '450000002' ).
*    inseRT_po_header( iv_req_id = lv_req_id ).
*    insert_po_item( iv_req_id = lv_req_id ).
    insert_so_header( iv_req_id = lv_req_id ).
    insert_so_item( iv_req_id = lv_req_id ).

    " ==================================================
    " Purchase Order PDF 테스트용 데이터
    " ==================================================

    COMMIT WORK.

    out->write( '테스트 데이터 INSERT 완료' ).

  ENDMETHOD.


  METHOD insert_mdoc_header.

    DATA lv_created_at TYPE timestampl.
    GET TIME STAMP FIELD lv_created_at.

*    INSERT zmdoc_req_h_kar FROM @( VALUE #(
*      client                     = sy-mandt
*      req_id                     = iv_req_id
*      status                     = '09'
*      goodsmovementcode          = '05'
*      postingdate                = '20240215'
*      documentdate               = cl_abap_context_info=>get_system_date( )
*      materialdocumentheadertext = |MDOC { iv_req_id }|
*      referencedocument          = |TEST_{ iv_req_id }|
*      created_by                 = sy-uname
*      created_at                 = lv_created_at
*      last_changed_by            = sy-uname
*      last_changed_at            = lv_created_at
*    ) ).

  ENDMETHOD.


  METHOD insert_mdoc_item_gr501.

*    INSERT zmdoc_req_i_kar FROM @( VALUE #(
*      client                   = sy-mandt
*      req_id                   = iv_req_id
*      req_item_no              = '000001'
*      plant                    = '4310'
*      material                 = 'TG0011'
*      storagelocation          = '431A'
*      goodsmovementtype        = '501'
*      quantityinentryunit      = '1.000'
*      entryunit                = 'ST'
*      materialdocumentitemtext = 'MDOC TEST GR501 ITEM'
*    ) ).

  ENDMETHOD.


  METHOD insert_mdoc_item_gi201.

*    INSERT zmdoc_req_i_kar FROM @( VALUE #(
*      client                   = sy-mandt
*      req_id                   = iv_req_id
*      req_item_no              = '000001'
*      plant                    = '4310'
*      material                 = 'TG0011'
*      storagelocation          = '431A'
*      goodsmovementtype        = '201'
*      quantityinentryunit      = '1.000'
*      entryunit                = 'ST'
*      costcenter               = '43101001'
*      materialdocumentitemtext = 'MDOC TEST GI201 ITEM'
*    ) ).

  ENDMETHOD.


  METHOD insert_po_header.
    DATA lv_created_at TYPE timestampl.
    GET TIME STAMP FIELD lv_created_at.
*
*    INSERT zpo_req_h_kar FROM @( VALUE #(
*      mandt                   = sy-mandt
*      req_id                  = iv_req_id
*      status                  = '09'
*      companycode             = '4310'
*      supplier                = '0043300001'
*      purchasingorganization  = '4310'
*      purchasinggroup         = '001'
*      purchaseordertype       = 'NB'
*      documentcurrency        = 'KRW'
*      purchaseorderdate       = cl_abap_context_info=>get_system_date( )
*      paymentterms            = '0001'
*      incotermsclassification = 'EXW'
*      incotermslocation1      = 'SEOUL'
*      created_by              = sy-uname
*      created_at              = lv_created_at
*      last_changed_by         = sy-uname
*      last_changed_at         = lv_created_at
*    ) ).
  ENDMETHOD.

  METHOD insert_po_item.
*    INSERT zpo_req_i_kar FROM @( VALUE #(
*      mandt                     = sy-mandt
*      req_id                    = iv_req_id
*      purchaseorderitem         = '00010'
*      material                  = 'TG0011'
*      plant                     = '4310'
*      storagelocation           = '431A'
*      orderquantity             = '1.000'
*      purchaseorderquantityunit = 'EA'
*      netpriceamount            = '1000.00'
*      taxcode                   = 'V1'
*      purchaseorderitemtext     = 'PO TEST ITEM'
*    ) ).
  ENDMETHOD.

  METHOD insert_so_header.

*    DELETE FROM zsso_req_h_kar.
*    DELETE FROM zsso_req_i_kar.

    DATA lv_created_at TYPE timestampl.
    GET TIME STAMP FIELD lv_created_at.
    INSERT zsso_req_h_kar FROM @( VALUE #(
  client                  = sy-mandt
  req_id                  = iv_req_id  " 22자리
  status                  = '09'                      " 대기
  salesordertype          = 'TA'
  salesorganization       = '4310'
  distributionchannel     = '10'
  organizationdivision    = '00'
  soldtoparty             = '0043100014'
  purchaseorderbycustomer = 'SF-TEST-001'
  requesteddeliverydate   = '20260601'
  created_by              = sy-uname
  created_at              = lv_created_at
  last_changed_by         = sy-uname
  last_changed_at         = lv_created_at
) ).
  ENDMETHOD.

  METHOD insert_so_item.
    INSERT zsso_req_i_kar FROM @( VALUE #(
      client                = sy-mandt
      req_id                = iv_req_id
      req_item_no           = '000001'
      salesorderitem        = '000010'
      product               = 'TG11'
      requestedquantity     = '5.000'
      requestedquantityunit = 'ST'
      plant                 = '4310'
      salesorderitemtext    = 'SO TEST ITEM'
    ) ).
  ENDMETHOD.

ENDCLASS.

