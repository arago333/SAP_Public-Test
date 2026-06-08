CLASS zcl_practice_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun.

ENDCLASS.



CLASS zcl_practice_kar IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
*====================================================================*
* Elementary Types
*====================================================================*
*
*  ABAP 타입은 크게 두 계층으로 나뉜다.
*
*  ┌──────────────────────────────────────────────────────────────────┐
*   고정 길이 (Fixed-length)
*
*    [문자]
*    c      : 문자(Character). c LENGTH 4. 빈 자리 공백 패딩.
*    n      : 숫자 문자. n LENGTH 10. 앞자리 '0' 패딩.
*             → 주문번호, 사업장코드처럼 앞자리 0이 의미 있을 때.
*
*    [날짜/시간]
*    d      : 날짜. 'YYYYMMDD' 8자리 고정.
*    t      : 시간. 'HHMMSS' 6자리 고정.
*    utclong: UTC 타임스탬프. d+t 조합 대신 Cloud ABAP 권장.
*             → 타임존 안전, 정밀도 높음, CL_ABAP_UTCLONG로 계산.
*
*    [정수]
*    i      : 32비트 정수. 건수, 인덱스, 카운터.
*    int8   : 64비트 정수. i 범위(-2^31~2^31-1) 초과할 때.
*             → 파일 크기, 누적 카운터 등 큰 숫자.
*
*    [소수점/금액]
*    p      : 팩형(Packed). DECIMALS 필수. 고정 소수점.
*             → i로 금액 담으면 소수점 날아간다. 반드시 p 쓸 것.
*    decfloat16: 십진 부동소수점 16자리. p보다 정밀도 높음.
*    decfloat34: 십진 부동소수점 34자리. 가장 정밀.
*             → p/f의 현대적 대체. DECIMALS 선언 불필요.
*             → Cloud ABAP에서 점점 많이 쓰임.
*    f      : 이진 부동소수점. 정밀도 낮아 금액에 쓰면 안 됨.
*
*    [바이트]
*    x      : 16진수 바이트(Hex).
*
*    [직접 선언 불가 - DDIC 타입으로만 존재]
*    b      : 1바이트 정수(INT1). DB 컬럼에서만 만날 수 있음.
*    s      : 2바이트 정수(INT2). DB 컬럼에서만 만날 수 있음.
*  ├──────────────────────────────────────────────────────────────────┤
*   가변 길이 (Variable-length)
*    string  : 동적 문자열. 텍스트 조합, 메시지 출력.
*    xstring : 바이너리. PDF, 파일 첨부, API 응답 바이너리.
*  └──────────────────────────────────────────────────────────────────┘
*
*  ✅ Clean ABAP 원칙
*  - DB 컬럼에 매핑되는 값 → Data Element 타입 그대로 쓴다.
*    예) companycode TYPE bukrs   (❌ TYPE c LENGTH 4)
*  - 로컬 텍스트 조합          → string
*  - 금액/수량 (고정 소수점)   → p with DECIMALS
*  - 타임스탬프                → utclong (d+t 조합 지양)
*  - 큰 정수                   → int8
*
*--------------------------------------------------------------------
    DATA lv_char   TYPE c LENGTH 10.
    DATA lv_numc   TYPE n LENGTH 10.
    DATA lv_date   TYPE d.
    DATA lv_time   TYPE t.
    DATA lv_int    TYPE i.
    DATA lv_packed TYPE p LENGTH 8 DECIMALS 2.
    DATA lv_dec16  TYPE decfloat16.
    DATA lv_dec34  TYPE decfloat34.
    DATA lv_string TYPE string.
    DATA lv_ts     TYPE utcl.

    lv_char = 'Hello'.
    lv_numc = '0123456789'.
    lv_date = cl_abap_context_info=>get_system_date( ).
    lv_time = cl_abap_context_info=>get_system_time( ).
    lv_int = 5678.
    lv_packed = '12345678.12'.
    lv_dec16 = '123456789.1234568'.
    lv_dec34 = '1234567890.1234567890123456789012'.
    lv_string = |날짜: { lv_date }, 시간:{ lv_time }, 건수:{ lv_int }|.
    lv_ts = utclong_current( ).

    out->write( lv_string ).
    out->write( |UTC 타임스탬프: { lv_ts }| ).
    out->write( |decfloat16: { lv_dec16 }| ).

    DATA(lv_ts_plus7) = utclong_add( val  = lv_ts
                                     days = 7 ).
    out->write( |7일 후 UTC: { lv_ts_plus7 }| ).

*====================================================================*
* Structure 타입 + Internal Table
*====================================================================*
*
*  [구조 타입 (Structure)]
*  BEGIN OF .... END OF = (Row) 한 건의 설계도.
*  Internal Table의 line 타입, SELECT 결과 한 건, EML 결과 처리에
*
*  [Internal Table 3종]
*  ┌──────────┬──────────────────────────────────────────────────┐
*   STANDARD  삽입 순서 유지, 범용, 가장 많이 사용.
*             검색: 선형 O(n). SORT+BINARY SEARCH로 개선 가능.
*  ├──────────┼──────────────────────────────────────────────────┤
*   SORTED    삽입 시 KEY 기준 자동 정렬 유지.
*             READ TABLE KEY → 자동 이진 탐색 O(log n).
*             범위 조회(range access)에 유리.
*  ├──────────┼──────────────────────────────────────────────────┤
*   HASHED    KEY 기준 해시 저장. READ TABLE KEY → O(1).
*             순서 없음. 대량 단건 키 조회에 최적.
*  └──────────┴──────────────────────────────────────────────────┘
*
*  [언제 뭘 쓰나]
*  - 그냥 담고 LOOP            → STANDARD
*  - 단건 조회 소~중 빈도      → SORTED (KEY 명시)
*  - 단건 조회 고빈도 대량     → HASHED
*  - RAP EML 결과/reported 등  → STANDARD (프레임워크 기본)
*
*  ✅ KEY 선언 원칙
*  ❌ WITH DEFAULT KEY   → 모든 non-numeric 필드가 키. 의도치 않은 동작.
*  ✅ WITH EMPTY KEY     → 키 없는 단순 컬렉션. 가장 안전한 기본값.
*  ✅ WITH NON-UNIQUE KEY field1  → STANDARD 검색 최적화
*  ✅ WITH UNIQUE KEY field1      → SORTED/HASHED 중복 방지
*
*--------------------------------------------------------------------
    TYPES ty_amount TYPE p LENGTH 8 DECIMALS 2.
    TYPES:BEGIN OF ty_order,
            order_id      TYPE string,
            customer_name TYPE string,
            status        TYPE string,
            amount        TYPE ty_amount,
          END OF ty_order.

    TYPES tt_order TYPE STANDARD TABLE OF ty_order WITH EMPTY KEY.
    TYPES tt_order_sorted TYPE SORTED TABLE OF ty_order WITH UNIQUE KEY order_id.
    TYPES tt_order_hashed TYPE HASHED TABLE OF ty_order WITH UNIQUE KEY order_id.

    DATA lt_order TYPE tt_order.
    DATA lt_hashed TYPE tt_order_hashed.

*====================================================================*
* ENUM (상태값은 CONSTANTS 대신 ENUM)
*====================================================================*
*
*  ❌ CONSTANTS 방식의 문제점
*     CONSTANTS lc_open TYPE string VALUE 'OPEN'.
*     DATA lv_st TYPE string.
*     lv_st = 'ANYTHING'.   ← 컴파일러가 막을 수 없음.
*
*  ✅ ENUM 방식
*  - 허용 값 범위가 컴파일 시점에 고정된다.
*  - 범위 밖 값 대입 → 즉시 문법 오류
*  - Clean ABAP 공식 권장. Cloud ABAP 7.54+에서 사용 가능.
*
*  [활용 예시]
*  - Status (OPEN/CLOSED/IN_PROGRESS)
*  - Action 결과 코드
*  - Validation 분기 조건
*
*--------------------------------------------------------------------
    TYPES:
      BEGIN OF ENUM order_status_enum,
        initial_value,
        open,
        in_progress,
        closed,
      END OF ENUM order_status_enum.

    DATA(lv_status) = open.

    CASE lv_status.
      WHEN open.        out->write( `상태: OPEN` ).
      WHEN in_progress. out->write( `상태: IN_PROGRESS` ).
      WHEN closed.      out->write( `상태: CLOSED` ).
    ENDCASE.

*====================================================================*
*  데이터 조작 - VALUE / INSERT / FILTER / REDUCE / FOR
*====================================================================*
*
* [VALUE #()]
* Structure/테이블 데이터 선언 동시에 초기화.
* RAP에서 EML 파라미터 구성, reported/failed 테이블 초기화에 필수.
*
* [INSERT INTO TABLE vs APPEND]
*  ❌ APPEND ls TO lt.    → STANDARD + 배열처럼 쓸 때만 의도 명확.
*                            테이블 종류 바꾸면 APPEND 안 될 수 있다.
*  ✅ INSERT VALUE #( ) INTO TABLE lt.
*                          → 모든 테이블 종류에서 동작. 리팩토링 안전.
*
* [FILTER #()]
*  [FILTER #( )]
*  ABAP 메모리 내 필터링. DB SELECT WHERE 와 다르다.
*  원본과 동일한 타입으로 반환.
*  ← SELECT WHERE  : DB에서 가져올 때 필터
*  ← FILTER #( )   : 이미 메모리에 있는 테이블을 자름
*
*  [FOR ... IN ... WHERE]
*  테이블을 돌면서 다른 타입으로 변환하거나 특정 필드만 추출.
*  ← FILTER  : 같은 타입 그대로 추출
*  ← FOR     : 타입 변환 or 필드 선택 추출
*
*  [REDUCE]
*  테이블 전체를 하나의 값으로 집계 (합계, 최대값 등).
*  단순 합계에 깔끔. 복잡한 로직은 LOOP + 변수 누적이 더 읽기 좋다.
*
*--------------------------------------------------------------------

    "VALUE로 테이블 초기화
    lt_order = VALUE #(
      ( order_id = 'O-001' customer_name = 'Kim'  status = `open`   amount = '10000.00' )
      ( order_id = 'O-002' customer_name = 'Lee'  status = `closed` amount = '20000.00' )
      ( order_id = 'O-003' customer_name = 'Park' status = `open`   amount = '30000.00' )
      ( order_id = 'O-004' customer_name = 'Choi' status = `open`   amount = '40000.00' )
      ( order_id = 'O-005' customer_name = 'Yoon' status = `closed` amount = '50000.00' )
    ).

    "INSERT INTO TABLE - 행 하나 추가
    INSERT VALUE #(
     order_id = 'O-006' customer_name = 'Jung' status = 'open' amount = '60000.00'
     ) INTO TABLE lt_order.

    out->write( |전체 건수: { lines( lt_order ) }| ).

    " 컴파일러 오류 때문에 더 확인하고 진행.
*    "FILTER - OPEN 주문만
*    DATA(lt_open) = FILTER #( lt_order WHERE status = `open` ).
*    out->write( |OPEN 건수: { lines( lt_open ) }| ).

    " FOR + WHERE - OPEN 주문의 order_id만 string_table로
    DATA(lt_open_ids) = VALUE string_table(
    FOR ls_fo IN lt_order
    WHERE ( status = `open` )
    ( ls_fo-order_id )
     ).
    out->write( `--- OPEN 주문 ID 목록 ---` ).
    LOOP AT lt_open_ids INTO DATA(lv_oid).
      out->write( lv_oid ).
    ENDLOOP.

    DATA(lv_open_total) = REDUCE ty_amount( " REDUCE - OPEN 주문 총 금액
      INIT lv_s = 0 " INIT = DATA 선언 + 초기화
      FOR ls_r IN lt_order " FOR = LOOP
      WHERE ( status = 'open' )
      NEXT lv_s = lv_s + ls_r-amount " NEXT = 누적 처리
    ).
    out->write( |OPEN 총 금액: { lv_open_total }| ).

*====================================================================*
* LOOP 패턴 - INTO / FIELD-SYMBOL / REFERENCE
*====================================================================*
*
*  [INTO DATA(ls)]   → 행 복사본. 읽기 전용일 때 가독성 좋음.
*                       수정 후 원본 반영하려면 별도 MODIFY 필요.
*
*  [ASSIGNING FIELD-SYMBOL(<ls>)]
*                    → 행 포인터. 수정하면 테이블 원본 직접 변경.
*                       성능: 복사 없음. 대량 데이터 + 수정에 유리.
*                       Clean ABAP: 루프 내 수정이 필요하면 이걸 써라.
*
*  [REFERENCE INTO DATA(lr)]
*                    → 참조 포인터. lr->field_name 으로 접근.
*                       OOP 스타일 일관성 원할 때.
*                       FIELD-SYMBOL보다 약간 느리지만 차이 미미.
*
*  [CHECK vs CONTINUE]
*  ❌ IF condition <> 'OPEN'. CONTINUE. ENDIF.
*  ✅ CHECK condition = 'OPEN'.   ← 조건이 거짓이면 다음 건으로 넘어감
*     → 짧고 의도가 명확하다.
*
*--------------------------------------------------------------------

    " 읽기전용 LOOP
    out->write( `--- LOOP INTO (읽기 전용) ---` ).
    LOOP AT lt_order INTO DATA(ls_ro).
      out->write( |{ ls_ro-order_id } / { ls_ro-customer_name } / { ls_ro-amount }| ).
    ENDLOOP.

    " 수정 LOOP (FIELD-SYMBOL)
    out->write( `--- LOOP FIELD-SYMBOL (amount 10% 인상) ---` ).
    LOOP AT lt_order ASSIGNING FIELD-SYMBOL(<ls_o>).
      <ls_o>-amount = <ls_o>-amount * '1.1'.
    ENDLOOP.

    " CHECK로 필터링
    out->write( `--- CHECK 패턴 (OPEN만 출력) ---` ).
    LOOP AT lt_order INTO DATA(ls_ck).
      CHECK ls_ck-status = 'open'.
      out->write( |{ ls_ck-order_id } / { ls_ck-amount }| ).
    ENDLOOP.

*====================================================================*
*  READ TABLE - 선형 / BINARY SEARCH / TABLE KEY
*====================================================================*
*
*  [검색 성능 비교]
*  ┌─────────────────────────────────┬──────────────────────────┐
*   방법                              시간 복잡도
*  ├─────────────────────────────────┼──────────────────────────┤
*   STANDARD + READ WITH KEY         O(n) 선형 탐색
*   STANDARD + SORT + BINARY SEARCH  O(log n) 이진 탐색
*   SORTED  + READ WITH TABLE KEY    O(log n) 자동 이진 탐색
*   HASHED  + READ WITH TABLE KEY    O(1)  해시 탐색
*  └─────────────────────────────────┴──────────────────────────┘
*
*  주의: BINARY SEARCH는 반드시 같은 KEY로 SORT 먼저 해야 한다.
*        SORT 후 데이터 추가하면 다시 SORT 필요 → 유지보수 부담.
*        대량 단건 조회가 많으면 처음부터 HASHED 쓰는 게 낫다.
*
*--------------------------------------------------------------------

    " READ TABLE + BINARY SEARCH (SORT 선행 필수)
    SORT lt_order BY order_id ASCENDING.

    READ TABLE lt_order
    INTO DATA(ls_found)
    WITH KEY order_id = 'O-003'
    BINARY SEARCH.

    IF sy-subrc = 0.
      out->write( |BINARY SEARCH 결과: { ls_found-customer_name }| ).
    ELSE.
      out->write( `찾지 못함` ).
    ENDIF.

    " HASHED TABLE - 단건 조회 O(1)
    lt_hashed = CORRESPONDING #( lt_order ).

    READ TABLE lt_hashed
          INTO DATA(ls_h)
          WITH TABLE KEY order_id = 'O-002'.

    IF sy-subrc = 0.
      out->write( |HASHED 검색 결과: { ls_h-customer_name }| ).
    ENDIF.

    " 없는 건 처리
    READ TABLE lt_order INTO DATA(ls_none)
      WITH KEY order_id = 'O-999'.
    IF sy-subrc <> 0.
      out->write( `O-999: 주문 없음` ).
    ENDIF.
*====================================================================*
*  SORT / CORRESPONDING
*====================================================================*
*
*  [SORT]
*  - SORT itab BY field1 ASCENDING field2 DESCENDING.
*  - BINARY SEARCH 쓰려면 먼저 SORT.
*  - SORTED TABLE은 자동 정렬이라 SORT 불필요.
*
*  [CORRESPONDING]
*  - 이름 같은 필드끼리 자동 복사.
*  - MAPPING : 이름 다른 필드 매핑.
*  - EXCEPT  : 특정 필드 제외 (초기값 유지).
*
*  [활용 예시]
*  - DB 조회 결과 → 화면 출력 구조
*  - EML Entity 결과 → 내부 처리 구조
*  - API 응답 → 저장용 구조
*
*--------------------------------------------------------------------

    SORT lt_order BY amount DESCENDING.

    out->write( `--- 금액 내림차순 ---` ).
    LOOP AT lt_order INTO DATA(ls_s).
      out->write( |{ ls_s-order_id } / { ls_s-amount }| ).
    ENDLOOP.

    " CORRESPONDING
    TYPES:
      BEGIN OF ty_order_display,
        order_id      TYPE string,
        customer_name TYPE string,
        amount        TYPE p LENGTH 8 DECIMALS 2,
      END OF ty_order_display.

    TYPES tt_order_display TYPE STANDARD TABLE OF ty_order_display WITH EMPTY KEY.

    DATA(lt_display) = CORRESPONDING tt_order_display( lt_order ).

    out->write( `---출력 구조 ---` ).
    LOOP AT lt_display INTO DATA(ls_d).
      out->write( |{ ls_d-order_id } / { ls_d-customer_name } / { ls_d-amount }| ).
    ENDLOOP.




  ENDMETHOD.
ENDCLASS.
