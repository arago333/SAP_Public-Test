
CLASS lhc_shop DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PUBLIC SECTION.
    CONSTANTS state_area_check_delivery_date       TYPE string VALUE 'CHECK_DELIVERYDATE'       ##NO_TEXT.
  PRIVATE SECTION.
    METHODS zz_validateDeliverydate               FOR VALIDATE ON SAVE
      IMPORTING keys FOR Shop~zz_validateDeliverydate.
    METHODS ZZ_setOverallStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Shop~ZZ_setOverallStatus.
    METHODS ZZ_ProvideFeedback FOR MODIFY
      IMPORTING keys FOR ACTION Shop~ZZ_ProvideFeedback RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Shop RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Shop RESULT result.

ENDCLASS.

CLASS lhc_shop IMPLEMENTATION.

  METHOD zz_validateDeliverydate.
    READ ENTITIES OF ZRAP630i_ShopTP_KAR IN LOCAL MODE
            ENTITY Shop
            FIELDS ( DeliveryDate OverallStatus )
            WITH CORRESPONDING #( keys )
            RESULT DATA(onlineorders).

    LOOP AT onlineorders INTO DATA(onlineorder).
      APPEND VALUE #( %tky           = onlineorder-%tky
                      %state_area    = state_area_check_delivery_date )
             TO reported-shop.
      DATA(deliverydate)             =  onlineorder-DeliveryDate - cl_abap_context_info=>get_system_date(  ).
      IF onlineorder-deliverydate IS INITIAL  .
        APPEND VALUE #( %tky           = onlineorder-%tky ) TO failed-shop.
        APPEND VALUE #( %tky           = onlineorder-%tky
                        %state_area    = state_area_check_delivery_date
                        %msg           = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = 'delivery period cannot be initial'
                       ) )
                TO reported-shop.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ZZ_setOverallStatus.

    " UPDATE용 내부테이블/구조체 선언 (Shop entity의 UPDATE 타입)
    DATA update_bo      TYPE TABLE FOR UPDATE     ZRAP630i_ShopTP_KAR\\Shop. "자식 entity
    DATA update_bo_line TYPE STRUCTURE FOR UPDATE ZRAP630i_ShopTP_KAR\\Shop.

    " keys로 넘어온 변경된 Shop 인스턴스들 전체 필드 READ
    " IN LOCAL MODE = 권한체크 없이 RAP 내부에서 직접 읽기
    READ ENTITIES OF ZRAP630I_ShopTP_KAR IN LOCAL MODE
      ENTITY Shop
        ALL FIELDS
        WITH CORRESPONDING #( keys )  " determination이 받은 key 목록
      RESULT DATA(OnlineOrders)
      FAILED DATA(onlineorders_failed)
      REPORTED DATA(onlineorders_reported).

    " Value Help 클래스에서 상품 목록 가져오기
    DATA(product_value_help) = NEW zrap630_cl_vh_product_KAR( ).
    DATA(products) = product_value_help->get_products( ).

    " READ로 가져온 주문 인스턴스들 순회
    LOOP AT onlineorders INTO DATA(onlineorder).

      " 수정할 인스턴스의 키 세팅 (%tky = draft/active 통합키)
      update_bo_line-%tky = onlineorder-%tky.

      " 선택된 상품(OrderedItem)을 상품목록에서 찾아서 가격 조회
      SELECT SINGLE * FROM @products AS hugo
        WHERE Product = @onlineorder-OrderedItem
        INTO @DATA(product).

      " 조회된 상품 가격/통화 세팅
      update_bo_line-OrderItemPrice = product-Price.
      update_bo_line-CurrencyCode   = product-Currency.

      " 가격 1000 초과면 승인 대기, 이하면 자동 승인
      IF product-Price > 1000.
        update_bo_line-OverallStatus = 'Awaiting approval'.
      ELSE.
        update_bo_line-OverallStatus = 'Automatically approved'.
      ENDIF.

      " 수정 대상 테이블에 추가
      APPEND update_bo_line TO update_bo.
    ENDLOOP.

    " 수집한 변경사항을 RAP BO에 반영
    " IN LOCAL MODE = 권한체크 없이 내부에서 직접 수정
    MODIFY ENTITIES OF zrap630i_shoptp_KAR IN LOCAL MODE
      ENTITY Shop
        UPDATE FIELDS (    " 이 세 필드만 업데이트
          OverallStatus
          CurrencyCode
          OrderItemPrice
        )
        WITH update_bo
      REPORTED DATA(update_reported).

    " 에러/메시지 상위로 전달
    reported = CORRESPONDING #( DEEP update_reported ).

  ENDMETHOD.

  METHOD ZZ_ProvideFeedback.
    MODIFY ENTITIES OF ZRAP630I_ShopTP_KAR IN LOCAL MODE
    ENTITY shop

    UPDATE FIELDS ( zzfeedbackzaa )
    WITH VALUE #( FOR Key IN keys ( %tky = key-%tky
                                    zzfeedbackzaa = key-%param-feedback ) ).
  ENDMETHOD.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

ENDCLASS.
