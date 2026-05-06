CLASS lhc_ZKAR_I_MM_PO DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    TYPES ty_items TYPE STANDARD TABLE OF I_PurchaseOrderItemAPI01 WITH EMPTY KEY.

    "! <p class="shorttext synchronized">PDF 생성 Action</p>
    METHODS createpdf FOR MODIFY
      IMPORTING keys FOR ACTION zkar_i_mm_po~CreatePdf RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zkar_i_mm_po RESULT result.

    "! <p class="shorttext synchronized">발주 헤더 XML 생성</p>
    "! @parameter is_po    | 발주 헤더 데이터
    "! @parameter rv_xml   | 헤더 XML 문자열
    METHODS build_xml_header
      IMPORTING
        is_po         TYPE I_PurchaseOrderAPI01
      RETURNING
        VALUE(rv_xml) TYPE string.

    "! <p class="shorttext synchronized">발주 아이템 XML 생성</p>
    "! @parameter it_items | 발주 아이템 데이터
    "! @parameter rv_xml   | 아이템 XML 문자열
    METHODS build_xml_items
      IMPORTING
        it_items      TYPE ty_items
      RETURNING
        VALUE(rv_xml) TYPE string.

    "! <p class="shorttext synchronized">발주 전체 XML 생성</p>
    "! @parameter is_po    | 발주 헤더 데이터
    "! @parameter it_items | 발주 아이템 데이터
    "! @parameter rv_xml   | 전체 XML 문자열
    METHODS build_xml
      IMPORTING
        is_po         TYPE I_PurchaseOrderAPI01
        it_items      TYPE ty_items
      RETURNING
        VALUE(rv_xml) TYPE string.

ENDCLASS.


CLASS lhc_ZKAR_I_MM_PO IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD build_xml_header.
    " 발주 헤더 정보를 XML 형식으로 변환
    rv_xml =
      |<Header>| &&
      |<PurchaseOrder>{ is_po-PurchaseOrder }</PurchaseOrder>| &&
      |<Supplier>{ is_po-Supplier }</Supplier>| &&
      |<CompanyCode>{ is_po-CompanyCode }</CompanyCode>| &&
      |<CreationDate>{ is_po-CreationDate }</CreationDate>| &&
      |<PurchasingOrganization>{ is_po-PurchasingOrganization }</PurchasingOrganization>| &&
      |</Header>|.
  ENDMETHOD.

  METHOD build_xml_items.
    " 발주 아이템 목록을 XML 형식으로 변환
    LOOP AT it_items INTO DATA(ls_item).
      rv_xml = rv_xml &&
        |<Item>| &&
        |<Material>{ ls_item-Material }</Material>| &&
        |<OrderQuantity>{ ls_item-OrderQuantity }</OrderQuantity>| &&
        |<NetPriceAmount>{ ls_item-NetPriceAmount }</NetPriceAmount>| &&
        |</Item>|.
    ENDLOOP.
    rv_xml = |<Items>| && rv_xml && |</Items>|.
  ENDMETHOD.

  METHOD build_xml.
    " 헤더 + 아이템 XML을 합쳐 전체 XML 구성
    rv_xml =
      |<PurchaseOrder>| &&
      build_xml_header( is_po ) &&
      build_xml_items( it_items ) &&
      |</PurchaseOrder>|.
  ENDMETHOD.

  METHOD createpdf.
    result = VALUE #( FOR key IN keys ( %tky = key-%tky ) ).

    LOOP AT keys INTO DATA(ls_key).

      " ① 발주 헤더 조회
      SELECT SINGLE *
        FROM I_PurchaseOrderAPI01
        WHERE PurchaseOrder = @ls_key-PurchaseOrder
        INTO @DATA(ls_po).

      " 발주 데이터 없으면 오류 메시지 후 다음 키로
      IF sy-subrc <> 0.
        APPEND VALUE #(
          %tky = ls_key-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |발주 데이터 없음: { ls_key-PurchaseOrder }| )
        ) TO reported-zkar_i_mm_po.
        CONTINUE.
      ENDIF.

      " ② 발주 아이템 조회
      SELECT *
        FROM I_PurchaseOrderItemAPI01
        WHERE PurchaseOrder = @ls_key-PurchaseOrder
        INTO TABLE @DATA(lt_items).

      " ③ XML 빌드 (헤더 + 아이템)
      DATA(lo_form) = NEW zkar_cl_adobe_form( ).
      DATA(ls_xml_result) = lo_form->string_to_xstring(
   build_xml( is_po    = ls_po
              it_items = lt_items ) ).

      IF ls_xml_result-xstring IS INITIAL.
        APPEND VALUE #(
          %tky = ls_key-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |XML 변환 실패: { ls_xml_result-err_msg }| )
        ) TO reported-zkar_i_mm_po.
        CONTINUE.
      ENDIF.

      " ④ PDF 생성 (ADS 렌더링)
      DATA(ls_result) = lo_form->render_pdf(
        iv_xml_data  = ls_xml_result-xstring
        iv_form_name = 'ZKAR_MM_F0001' ).

      " ⑤ 결과 처리
      IF ls_result-success = abap_true.
        " PDF 생성 성공 → 테이블에 저장
        MODIFY ENTITIES OF zkar_i_mm_po IN LOCAL MODE
          ENTITY zkar_i_mm_po
          UPDATE FIELDS ( PdfContent MimeType FileName
                          CompanyCode Supplier CreationDate
                          PurchasingOrganization PurchasingGroup
                          Language PoType )
          WITH VALUE #( (
            %tky                   = ls_key-%tky
            PdfContent             = ls_result-pdf
            MimeType               = 'application/pdf'
            FileName               = |PO_{ ls_key-PurchaseOrder }.pdf|
            CompanyCode            = ls_po-CompanyCode
            Supplier               = ls_po-Supplier
            CreationDate           = ls_po-CreationDate
            PurchasingOrganization = ls_po-PurchasingOrganization
            PurchasingGroup        = ls_po-PurchasingGroup
            Language               = ls_po-Language
            PoType                 = ls_po-PurchaseOrderType
          ) ).
      ELSE.
        " PDF 생성 실패 → 오류 메시지
        APPEND VALUE #(
          %tky = ls_key-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |PDF 생성 실패: { ls_result-err_msg }| )
        ) TO reported-zkar_i_mm_po.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
