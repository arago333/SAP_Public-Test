# Sales Order 비동기 생성 패턴 — 완전 가이드

> **대상**: 다음 프로젝트에서 동일 패턴을 처음부터 구현하는 개발자  
> **핵심 오브젝트**: `ZCL_SO_COMM_KAR`, `ZCL_SO_JOB_KAR`, `ZSSO_REQ_H_KAR`, `ZSSO_REQ_I_KAR`  
> **환경**: S/4HANA Public Cloud, ABAP Cloud (ADT)

---

## 목차

1. [왜 이 구조로 설계했나](#1-왜-이-구조로-설계했나)
2. [전체 아키텍처](#2-전체-아키텍처)
3. [DB 테이블 설계 — 결정 이유 포함](#3-db-테이블-설계--결정-이유-포함)
4. [단계별 실습 가이드](#4-단계별-실습-가이드)
5. [코드 상세 분석](#5-코드-상세-분석)
6. [주의사항 & 트러블슈팅](#6-주의사항--트러블슈팅)
7. [다음 프로젝트 적용 체크리스트](#7-다음-프로젝트-적용-체크리스트)

---

## 1. 왜 이 구조로 설계했나

### 1.1 I_SalesOrderTP의 근본적인 제약

S/4HANA Public Cloud에서 판매오더를 생성하는 Released API는 `I_SalesOrderTP`다.  
이 BO를 EML로 호출하면 반드시 `COMMIT ENTITIES`로 LUW를 닫아야 한다.

문제는 **`COMMIT ENTITIES`가 DB COMMIT을 내부적으로 포함**한다는 것이다.

```
MODIFY ENTITIES → (내부 버퍼에 쌓임)
COMMIT ENTITIES → DB COMMIT 포함하여 실제 저장
```

즉, **1번의 COMMIT ENTITIES = 1건의 완전한 처리**가 된다.  
LOOP 안에서 여러 건을 처리하려 해도, COMMIT 이후 동일 LUW에서 다시 MODIFY할 수 없다.

### 1.2 왜 BAPI를 안 쓰나

On-Premise에서는 `BAPI_SALESORDER_CREATEFROMDAT2`를 사용할 수 있다.  
하지만 **Cloud ABAP 환경에서는 Released API만 사용 가능**하고,  
해당 BAPI는 Cloud에서 사용 금지된 Classic API다.

```
❌ BAPI_SALESORDER_CREATEFROMDAT2  → Cloud 환경 사용 불가
✅ I_SalesOrderTP (RAP BO)         → Cloud Released API
```

### 1.3 왜 요청 테이블 + Job 패턴인가

| 방법 | 문제점 |
|------|--------|
| 동기 직접 호출 | 1건씩밖에 못 함, 외부 호출자가 결과 대기해야 함 |
| LOOP + COMMIT | COMMIT 이후 동일 세션에서 재사용 불가 |
| **요청 테이블 + Job** | ✅ 외부는 테이블에 INSERT만, Job이 1건씩 독립 세션으로 처리 |

**핵심 아이디어**: 외부 호출자와 실제 처리를 분리한다.  
외부는 요청 테이블에 데이터를 넣는 것으로 끝내고,  
Job이 짧은 주기로 돌면서 1건씩 꺼내 처리한다.

### 1.4 왜 클래스를 두 개로 나눴나

```
ZCL_SO_COMM_KAR  →  "판매오더 하나를 만들어주는 함수"  (순수 기능)
ZCL_SO_JOB_KAR   →  "대기 목록에서 꺼내서 시키는 역할"  (오케스트레이션)
```

`ZCL_SO_COMM_KAR`는 요청 테이블을 모른다.  
어디서든 `create_sales_order(헤더, 아이템)`을 호출하면 결과를 돌려준다.  
나중에 다른 Job이나 다른 프로그램에서 재사용할 수 있다.

`ZCL_SO_JOB_KAR`는 테이블 폴링과 상태 관리만 담당한다.  
EML 세부사항은 모른다.

---

## 2. 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        외부 호출자                               │
│                (Fiori / OData API / 다른 ABAP)                   │
└────────────────────────┬────────────────────────────────────────┘
                         │ INSERT (status='09')
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│            요청 큐 테이블                                         │
│   ZSSO_REQ_H_KAR  ─── 헤더 (1건)                                │
│   ZSSO_REQ_I_KAR  ─── 아이템 (N건)                              │
└────────────────────────┬────────────────────────────────────────┘
                         │ SELECT UP TO 1 ROWS (status='09')
                         │ UPDATE status='05'  ← 선점
                         │ COMMIT WORK
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│               ZCL_SO_JOB_KAR::execute()                         │
│               (Application Job — 짧은 주기 반복)                 │
└────────────────────────┬────────────────────────────────────────┘
                         │ call create_sales_order()
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│               ZCL_SO_COMM_KAR::create_sales_order()             │
│                                                                  │
│   ① 필수값 체크                                                   │
│   ② MODIFY ENTITIES OF i_salesordertp                           │
│   ③ FAILED 체크 → ROLLBACK ENTITIES                             │
│   ④ COMMIT ENTITIES BEGIN...END                                  │
│   ⑤ CONVERT KEY (%pid → 판매오더번호)                            │
│   ⑥ ts_result 반환                                               │
└────────────────────────┬────────────────────────────────────────┘
                         │ result
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│   ZSSO_REQ_H_KAR UPDATE                                         │
│   status='01' + vbeln=생성번호   (성공)                          │
│   status='99' + message_text     (오류)                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. DB 테이블 설계 — 결정 이유 포함

### 3.1 헤더 테이블: ZSSO_REQ_H_KAR

```
Sales Order Request: Header
```

| 필드명 | 타입 | PK | 설계 이유 |
|--------|------|----|-----------|
| CLIENT | CLNT | ✓ | 클라이언트 종속 표준 |
| REQ_ID | SYSUUID_C22 | ✓ | UUID 사용 → 채번 없이 유니크 보장, 외부에서 키를 미리 알 수 있음 |
| STATUS | CHAR(2) | | 2자리: 01/05/09/99 — 향후 상태 추가 여유 |
| SALESORDERTYPE | AUART | | `I_SalesOrderTP` 필드와 동일 도메인 사용 → 타입 변환 불필요 |
| SALESORGANIZATION | VKORG | | 동일 |
| DISTRIBUTIONCHANNEL | VTWEG | | 동일 |
| ORGANIZATIONDIVISION | SPART | | 동일 |
| SOLDTOPARTY | KUNNR | | 동일 |
| PURCHASEORDERBYCUSTOMER | BSTKD | | 동일 |
| REQUESTEDDELIVERYDATE | EDATU | | 동일 |
| VBELN | VBELN_VA | | 생성 후 채워짐 — 외부에서 REQ_ID로 폴링하여 결과 확인 |
| MESSAGE_TYPE | CHAR(1) | | S/W/E — 단순하게 1자리 |
| MESSAGE_TEXT | CHAR(255) | | 여러 메시지는 \` \| \`로 합쳐서 저장 (255자 제한 있음) |
| CREATED_BY/AT | SYUNAME/TIMESTAMPL | | 감사 추적 (Audit Trail) 표준 |
| LAST_CHANGED_BY/AT | SYUNAME/TIMESTAMPL | | Job이 처리할 때마다 갱신 |

> **REQ_ID를 UUID로 쓴 이유**:  
> 외부 시스템이 INSERT 전에 UUID를 생성해서 키를 미리 알 수 있다.  
> 나중에 `WHERE REQ_ID = 'xxx'`로 결과를 폴링할 수 있다.  
> 번호 채번 방식(`NUMBER_GET_NEXT` 등)은 Lock 경합이 생길 수 있다.

### 3.2 아이템 테이블: ZSSO_REQ_I_KAR

```
Sales Order Request: Item
```

| 필드명 | 타입 | PK | 설계 이유 |
|--------|------|----|-----------|
| CLIENT | CLNT | ✓ | |
| REQ_ID | SYSUUID_C22 | ✓ | 헤더의 FK |
| REQ_ITEM_NO | NUMC(6) | ✓ | 요청 아이템 순번 — SALESORDERITEM과 별도로 관리 |
| SALESORDERITEM | POSNV | | 실제 오더 품목번호 (10, 20, 30...) — 없으면 SAP이 자동 채번 |
| PRODUCT | MATNR | | 자재번호 |
| REQUESTEDQUANTITY | QUAN(13,3) | | REFTABLE/REFFIELD로 UNIT 연결 |
| REQUESTEDQUANTITYUNIT | UNIT(3) | | 수량단위 |
| PLANT | WERKS_D | | 플랜트 |
| SALESORDERITEMTEXT | CHAR(40) | | 품목 텍스트 |

> **REQ_ITEM_NO를 별도로 쓴 이유**:  
> `SALESORDERITEM`은 SAP 오더 품목번호(10, 20, 30)이고,  
> `REQ_ITEM_NO`는 요청 테이블 안에서의 순번이다.  
> 오더 품목번호를 비워두면 SAP이 자동 채번하기 때문에,  
> 요청 테이블에서 행을 구분할 별도 키가 필요하다.

---

## 4. 단계별 실습 가이드

> 처음 이 패턴을 적용하는 프로젝트 기준 순서

### Step 1. 패키지 생성

**ADT** → New → ABAP Package

```
패키지명: Z[프로젝트명]_SO  (예: ZKAR_SO)
설명:     Sales Order Related Objects
Software Component: LOCAL (개발계) 또는 프로젝트 Component
```

> 패키지를 먼저 만들어야 이후 오브젝트를 패키지에 묶을 수 있다.

---

### Step 2. 헤더 요청 테이블 생성

**ADT** → New → Database Table → 이름: `Z[PREFIX]_REQ_H`

최소 필드 구성:

```abap
@EndUserText.label : 'SO Request Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
define table z[prefix]_req_h {
  key client      : abap.clnt not null;
  key req_id      : sysuuid_c22 not null;         " UUID 키
  status          : abap.char(2);                  " 09/05/01/99
  salesordertype  : auart;
  salesorganization : vkorg;
  distributionchannel : vtweg;
  organizationdivision : spart;
  soldtoparty     : kunnr;
  purchaseorderbycustomer : bstkd;
  requesteddeliverydate : edatu;
  vbeln           : vbeln_va;                      " 생성 결과
  message_type    : abap.char(1);
  message_text    : abap.char(255);
  created_by      : syuname;
  created_at      : timestampl;
  last_changed_by : syuname;
  last_changed_at : timestampl;
}
```

**Activate** (Ctrl+F3)

---

### Step 3. 아이템 요청 테이블 생성

**ADT** → New → Database Table → 이름: `Z[PREFIX]_REQ_I`

```abap
@EndUserText.label : 'SO Request Item'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
define table z[prefix]_req_i {
  key client       : abap.clnt not null;
  key req_id       : sysuuid_c22 not null;
  key req_item_no  : abap.numc(6) not null;        " 요청 순번
  salesorderitem   : posnv;                         " 오더 품목번호 (비워두면 자동채번)
  product          : matnr;
  requestedquantity : abap.quan(13,3);
  @Semantics.unitOfMeasure
  requestedquantityunit : abap.unit(3);
  plant            : werks_d;
  salesorderitemtext : abap.char(40);
}
```

**Activate**

---

### Step 4. 공통 클래스 생성 (ZCL_[PREFIX]_COMM)

**ADT** → New → ABAP Class

```
클래스명: ZCL_[PREFIX]_COMM
설명:     Sales Order Common Class
Instantiation: PUBLIC
```

#### 4-1. PUBLIC SECTION — 타입 선언

```abap
PUBLIC SECTION.

  " 헤더 입력 구조체 — I_SalesOrderTP 헤더 필드와 1:1 매핑
  TYPES: BEGIN OF ts_so_header,
           salesordertype          TYPE auart,
           salesorganization       TYPE vkorg,
           distributionchannel     TYPE vtweg,
           organizationdivision    TYPE spart,
           soldtoparty             TYPE kunnr,
           purchaseorderbycustomer TYPE bstkd,
           requesteddeliverydate   TYPE edatu,
         END OF ts_so_header.

  " 아이템 입력 구조체
  TYPES: BEGIN OF ts_so_item,
           salesorderitem        TYPE posnv,
           product               TYPE matnr,
           requestedquantity     TYPE kwmeng,
           requestedquantityunit TYPE vrkme,
           plant                 TYPE werks_d,
           salesorderitemtext    TYPE arktx,
         END OF ts_so_item.
  TYPES tt_so_item TYPE TABLE OF ts_so_item WITH EMPTY KEY.

  " 메시지 구조체 — type: S/W/E, message: 텍스트
  TYPES: BEGIN OF ts_message,
           type    TYPE symsgty,
           message TYPE string,
         END OF ts_message.
  TYPES tt_messages TYPE TABLE OF ts_message WITH EMPTY KEY.

  " 결과 구조체
  TYPES: BEGIN OF ts_result,
           vbeln     TYPE vbeln_va,     " 생성된 판매오더번호
           success   TYPE abap_boolean, " 전체 성공 여부
           committed TYPE abap_boolean, " COMMIT 완료 여부
           messages  TYPE tt_messages,  " 메시지 목록
         END OF ts_result.

  " CLASS-METHOD: 인스턴스 없이 직접 호출 가능
  CLASS-METHODS create_sales_order
    IMPORTING
      is_header        TYPE ts_so_header
      it_item          TYPE tt_so_item
    RETURNING
      VALUE(rs_result) TYPE ts_result.
```

> **왜 CLASS-METHOD인가**:  
> 이 메서드는 내부 상태(인스턴스 변수)가 필요 없다.  
> 입력 → 처리 → 결과만 있으면 되므로, 인스턴스 생성 없이 직접 호출하는 CLASS-METHOD가 적합하다.  
> `ZCL_SO_COMM_KAR=>create_sales_order(...)` 형태로 어디서든 호출 가능.

#### 4-2. IMPLEMENTATION — ① 필수값 체크

```abap
METHOD create_sales_order.

  " ① 필수값 체크
  " IS INITIAL: 변수가 초기값(공백/0)인지 확인
  " 오류가 있으면 messages에 E 타입으로 쌓고 early return
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

  " E 타입 메시지가 하나라도 있으면 처리 중단
  " xsdbool(): 조건이 참이면 abap_true, 거짓이면 abap_false 반환
  " line_exists(): 테이블에 조건에 맞는 행이 있는지 확인
  DATA(lv_has_error) = xsdbool( line_exists( rs_result-messages[ type = 'E' ] ) ).
  IF lv_has_error = abap_true.
    rs_result-success   = abap_false.
    rs_result-committed = abap_false.
    RETURN.
  ENDIF.
```

#### 4-3. IMPLEMENTATION — ② EML 타입 선언

```abap
  " ② EML 전용 타입 선언
  " 'TABLE FOR CREATE i_salesordertp' : I_SalesOrderTP CREATE용 내부 테이블 타입
  " 이 타입은 SAP이 자동으로 정의한 것이며, %cid/%data/%control 등의 컴포넌트를 포함함
  DATA lt_so_header_create TYPE TABLE FOR CREATE i_salesordertp.

  " '\_item' : I_SalesOrderTP의 item 연관(association)에 대한 CREATE 테이블
  DATA lt_item_create      TYPE TABLE FOR CREATE i_salesordertp\_item.

  " LIKE LINE OF: 테이블의 한 행과 같은 타입의 구조체
  DATA ls_so   LIKE LINE OF lt_so_header_create.
  DATA ls_item LIKE LINE OF lt_item_create.
```

#### 4-4. IMPLEMENTATION — ③ 헤더 세팅

```abap
  " ③ 헤더 파라미터 세팅

  " %cid: Content ID — COMMIT 전 단계의 임시 식별자
  " 아이템이 %cid_ref로 이 헤더를 참조하기 위해 사용
  " 문자열이면 무엇이든 가능하지만, 한 MODIFY 호출 내에서 유니크해야 함
  ls_so-%cid = 'SO1'.

  " %data: 실제 필드 값 세팅
  " VALUE #(): 구조체를 인라인으로 초기화하는 ABAP 문법
  ls_so-%data = VALUE #(
    salesordertype          = is_header-salesordertype
    salesorganization       = is_header-salesorganization
    distributionchannel     = is_header-distributionchannel
    organizationdivision    = is_header-organizationdivision
    soldtoparty             = is_header-soldtoparty
    purchaseorderbycustomer = is_header-purchaseorderbycustomer
    requesteddeliverydate   = is_header-requesteddeliverydate
  ).

  " %control: 어떤 필드를 실제로 처리할지 지정하는 플래그
  " if_abap_behv=>mk-on  : 이 필드를 처리하겠다 (modify)
  " if_abap_behv=>mk-off : 이 필드는 건드리지 않겠다 (기본값)
  " %control을 지정하지 않으면 해당 필드는 무시될 수 있으므로 명시적으로 on 지정
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
```

#### 4-5. IMPLEMENTATION — ④ 아이템 세팅

```abap
  " ④ 아이템 세팅
  " ls_item은 헤더 CREATE 테이블의 child 연관용 구조체
  " %cid_ref: 위에서 설정한 헤더 %cid='SO1'을 참조 → 이 아이템들이 SO1 헤더에 속함을 의미
  ls_item-%cid_ref = 'SO1'.

  " %target: 실제 아이템 행들을 담는 내부 테이블
  " LOOP을 돌면서 아이템을 하나씩 %target에 APPEND
  LOOP AT it_item INTO DATA(ls_src_item).
    APPEND VALUE #(
      " %cid: 아이템 각각의 임시 ID — 'SOITEM1', 'SOITEM2', ...
      " sy-tabix: 현재 LOOP 순번 (1부터 시작)
      " 파이프( | | ): 문자열 템플릿(string template) — 변수를 중괄호로 감쌈
      %cid                           = |SOITEM{ sy-tabix }|

      salesorderitem                 = ls_src_item-salesorderitem
      product                        = ls_src_item-product
      requestedquantity              = ls_src_item-requestedquantity
      requestedquantityunit          = ls_src_item-requestedquantityunit
      plant                          = ls_src_item-plant
      salesorderitemtext             = ls_src_item-salesorderitemtext

      " %control은 %data 없이 인라인으로도 지정 가능
      %control-product               = if_abap_behv=>mk-on
      %control-requestedquantity     = if_abap_behv=>mk-on
      %control-requestedquantityunit = if_abap_behv=>mk-on
      %control-plant                 = if_abap_behv=>mk-on
      %control-salesorderitemtext    = if_abap_behv=>mk-on
    ) TO ls_item-%target.
  ENDLOOP.

  APPEND ls_item TO lt_item_create.
```

#### 4-6. IMPLEMENTATION — ⑤ MODIFY ENTITIES

```abap
  " ⑤ MODIFY ENTITIES — SAP BO에 데이터를 실제로 적용 요청
  " 아직 DB에 저장된 것은 아님. COMMIT ENTITIES 전까지는 내부 버퍼 상태
  TRY.
      MODIFY ENTITIES OF i_salesordertp
        ENTITY salesorder
          CREATE FROM lt_so_header_create           " 헤더 CREATE
          CREATE BY \_item FROM lt_item_create       " 아이템 CREATE (헤더 하위)
        MAPPED   DATA(ls_mapped)    " 성공한 엔티티의 키 매핑 정보
        FAILED   DATA(ls_failed)    " 실패한 엔티티 정보
        REPORTED DATA(ls_reported). " 메시지 상세 정보

    CATCH cx_root INTO DATA(lx_error).
      " cx_root: 모든 예외의 최상위 클래스 — 예상 못한 예외도 잡기 위해 사용
      APPEND VALUE #(
        type    = 'E'
        message = |MODIFY ENTITIES 예외: { lx_error->get_text( ) }|
      ) TO rs_result-messages.
      rs_result-success   = abap_false.
      rs_result-committed = abap_false.
      RETURN.
  ENDTRY.
```

> **MAPPED / FAILED / REPORTED 차이**:
> - `MAPPED`: 성공한 엔티티의 `%cid` → 실제 키(%key) 매핑 테이블. 이후 CONVERT KEY에 사용.
> - `FAILED`: 실패한 엔티티 목록. 어떤 `%cid`가 실패했는지.
> - `REPORTED`: 메시지 상세. `%msg` 객체로 실제 오류 텍스트를 가져올 수 있음.

#### 4-7. IMPLEMENTATION — ⑥ FAILED 처리

```abap
  " ⑥ FAILED 처리
  " IS NOT INITIAL: ls_failed에 뭔가 들어있으면 (실패 엔티티가 있으면) 오류 처리
  IF ls_failed IS NOT INITIAL.

    " ROLLBACK ENTITIES: MODIFY ENTITIES로 버퍼에 쌓은 것을 모두 취소
    " 중요: 여기서는 ROLLBACK WORK가 아닌 ROLLBACK ENTITIES를 써야 한다
    " ROLLBACK WORK는 DB 트랜잭션 전체를 롤백하지만,
    " ROLLBACK ENTITIES는 RAP 프레임워크 버퍼만 취소한다
    ROLLBACK ENTITIES.

    " ls_reported-salesorder: 헤더 엔티티의 메시지 목록
    LOOP AT ls_reported-salesorder INTO DATA(ls_hdr_err).
      " %msg IS BOUND: %msg가 NULL이 아닌 객체를 참조하는지 확인
      " IS BOUND를 빠뜨리면 NULL 객체 접근으로 DUMP 발생
      IF ls_hdr_err-%msg IS BOUND.
        APPEND VALUE #(
          type    = 'E'
          " if_message~get_text(): 메시지 인터페이스의 텍스트 반환 메서드
          message = ls_hdr_err-%msg->if_message~get_text( )
        ) TO rs_result-messages.
      ENDIF.
    ENDLOOP.

    " ls_reported-salesorderitem: 아이템 엔티티의 메시지 목록
    LOOP AT ls_reported-salesorderitem INTO DATA(ls_itm_err).
      IF ls_itm_err-%msg IS BOUND.
        APPEND VALUE #(
          type    = 'E'
          message = ls_itm_err-%msg->if_message~get_text( )
        ) TO rs_result-messages.
      ENDIF.
    ENDLOOP.

    " 메시지가 하나도 없는 경우에도 오류 메시지 최소 하나는 보장
    IF rs_result-messages IS INITIAL.
      APPEND VALUE #( type = 'E' message = '판매오더 생성 실패' ) TO rs_result-messages.
    ENDIF.

    rs_result-success   = abap_false.
    rs_result-committed = abap_false.
    RETURN.
  ENDIF.
```

#### 4-8. IMPLEMENTATION — ⑦ COMMIT ENTITIES + CONVERT KEY

```abap
  " ⑦ COMMIT ENTITIES BEGIN...END
  " 이 블록이 실제 DB COMMIT을 수행한다
  " BEGIN...END 형태: COMMIT 결과(FAILED/REPORTED)와 함께 키 변환도 블록 안에서 처리
  DATA(lv_commit_error) = abap_false.

  COMMIT ENTITIES BEGIN
    RESPONSE OF i_salesordertp
    FAILED   DATA(ls_commit_failed)
    REPORTED DATA(ls_commit_reported).

    " BEGIN...END 블록 안에서만 ls_mapped와 %pid가 유효
    " 블록 밖으로 나가면 %pid → 실제 키 변환이 불가능하므로 반드시 여기서 처리
    IF ls_commit_failed IS INITIAL.
      LOOP AT ls_mapped-salesorder ASSIGNING FIELD-SYMBOL(<ls_mapped_hdr>).

        " CONVERT KEY: %pid(Provisional ID, 임시 키)를 실제 DB 키로 변환
        " %pid는 COMMIT ENTITIES 전에 RAP 프레임워크가 부여한 임시 식별자
        " COMMIT 이후 실제 VBELN으로 변환하기 위해 CONVERT KEY 사용
        CONVERT KEY OF i_salesordertp\salesorder
          FROM <ls_mapped_hdr>-%pid   " 임시 키 입력
          TO DATA(ls_final_key).      " 실제 키 출력 (salesorder 필드에 VBELN 들어옴)

        rs_result-vbeln = ls_final_key-salesorder.
        EXIT. " 헤더는 1건이므로 첫 번째 행만 처리하고 바로 EXIT
      ENDLOOP.
    ELSE.
      lv_commit_error = abap_true.
    ENDIF.

  COMMIT ENTITIES END.

  " sy-subrc 추가 확인: COMMIT ENTITIES END 이후 subrc도 체크
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

  " 여기까지 왔으면 COMMIT 완료
  rs_result-committed = abap_true.

  IF rs_result-vbeln IS NOT INITIAL.
    rs_result-success = abap_true.
    APPEND VALUE #(
      type    = 'S'
      message = |판매오더 생성 성공: { rs_result-vbeln }|
    ) TO rs_result-messages.
  ELSE.
    " COMMIT은 됐는데 번호를 못 가져온 경우 — 성공이지만 경고
    rs_result-success = abap_true.
    APPEND VALUE #(
      type    = 'W'
      message = '판매오더 생성은 성공했으나 번호를 확정하지 못했습니다.'
    ) TO rs_result-messages.
  ENDIF.

ENDMETHOD.
```

---

### Step 5. Job 클래스 생성 (ZCL_[PREFIX]_JOB)

**ADT** → New → ABAP Class

```
클래스명: ZCL_[PREFIX]_JOB
인터페이스: if_apj_dt_exec_object, if_apj_rt_exec_object
```

#### 5-1. DEFINITION

```abap
CLASS zcl_[prefix]_job DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " if_apj_dt_exec_object: Design Time — 잡 파라미터 정의용
    " 파라미터가 없으면 get_parameters를 빈 구현으로만 작성
    INTERFACES if_apj_dt_exec_object.

    " if_apj_rt_exec_object: Run Time — 실제 잡 실행 로직
    " execute 메서드가 잡 실행 시 호출됨
    INTERFACES if_apj_rt_exec_object.

ENDCLASS.
```

#### 5-2. execute 메서드 — 상태 상수 및 SELECT

```abap
METHOD if_apj_rt_exec_object~execute.

  " 상태 상수 정의 — 매직 넘버를 직접 쓰지 않고 상수로 관리
  CONSTANTS:
    lc_status_wait    TYPE c LENGTH 2 VALUE '09', " 대기
    lc_status_success TYPE c LENGTH 2 VALUE '01', " 성공
    lc_status_check   TYPE c LENGTH 2 VALUE '05', " 처리중/불명확
    lc_status_error   TYPE c LENGTH 2 VALUE '99'. " 오류

  DATA lt_headers   TYPE TABLE OF z[prefix]_req_h WITH EMPTY KEY.
  DATA lt_all_items TYPE TABLE OF z[prefix]_req_i WITH EMPTY KEY.

  " UP TO 1 ROWS: 대기 건 중 가장 오래된 것 1건만 SELECT
  " 왜 1건인가: I_SalesOrderTP 1 LUW = 1건 제약 때문
  " ORDER BY created_at ASCENDING: 먼저 들어온 것부터 처리 (FIFO)
  SELECT req_id,
         salesordertype,
         salesorganization,
         distributionchannel,
         organizationdivision,
         soldtoparty,
         purchaseorderbycustomer,
         requesteddeliverydate
    FROM z[prefix]_req_h
    WHERE status = @lc_status_wait
    ORDER BY created_at ASCENDING
    INTO CORRESPONDING FIELDS OF TABLE @lt_headers
    UP TO 1 ROWS.

  " 대기건 없으면 즉시 종료
  IF lt_headers IS INITIAL.
    RETURN.
  ENDIF.

  " FOR ALL ENTRIES: 헤더에 있는 req_id에 해당하는 아이템만 SELECT
  " 주의: FOR ALL ENTRIES 전에 반드시 lt_headers IS NOT INITIAL 체크 필요
  " (이미 위에서 INITIAL 체크 + RETURN 했으므로 여기서는 안전)
  SELECT req_id,
         req_item_no,
         salesorderitem,
         product,
         requestedquantity,
         requestedquantityunit,
         plant,
         salesorderitemtext
    FROM z[prefix]_req_i
    FOR ALL ENTRIES IN @lt_headers
    WHERE req_id = @lt_headers-req_id
    INTO CORRESPONDING FIELDS OF TABLE @lt_all_items.
```

#### 5-3. execute 메서드 — 선점 잠금 패턴

```abap
  DATA ls_header    TYPE zcl_[prefix]_comm=>ts_so_header.
  DATA lt_items     TYPE zcl_[prefix]_comm=>tt_so_item.
  DATA ls_result    TYPE zcl_[prefix]_comm=>ts_result.
  DATA lv_timestamp TYPE timestampl.

  LOOP AT lt_headers INTO DATA(ls_req_header).

    CLEAR: ls_header, lt_items, ls_result, lv_timestamp.

    GET TIME STAMP FIELD lv_timestamp. " 현재 타임스탬프 취득

    " 선점 잠금 (Optimistic Locking 패턴)
    " WHERE status = @lc_status_wait 조건이 핵심
    " 다른 Job 인스턴스가 이미 가져간 경우 UPDATE가 0건이 됨
    UPDATE z[prefix]_req_h
      SET status          = @lc_status_check,  " '09' → '05'로 변경
          last_changed_by = @sy-uname,
          last_changed_at = @lv_timestamp
      WHERE req_id = @ls_req_header-req_id
      AND status   = @lc_status_wait.           " ← 이 조건이 선점 보장

    " sy-dbcnt: 직전 DML(UPDATE/INSERT/DELETE)로 영향받은 행 수
    " 0이면 다른 프로세스가 이미 이 건을 가져간 것 → 스킵
    IF sy-dbcnt = 0.
      CONTINUE.
    ENDIF.

    " COMMIT WORK: 선점을 DB에 즉시 확정
    " 이 COMMIT이 완료된 이후에는 다른 Job이 이 건을 가져갈 수 없음
    " 참고: 여기서는 EML이 아닌 일반 UPDATE를 쓰므로 COMMIT WORK 사용
    COMMIT WORK.
```

#### 5-4. execute 메서드 — 실제 처리 및 결과 업데이트

```abap
    " 아이템 필터링: 이 헤더에 해당하는 아이템만 추출
    " VALUE #( FOR ... WHERE ... (...) ): 조건부 테이블 생성 표현식
    lt_items = VALUE #(
      FOR ls_req_item IN lt_all_items
      WHERE ( req_id = ls_req_header-req_id )
      (
        salesorderitem        = ls_req_item-salesorderitem
        product               = ls_req_item-product
        requestedquantity     = ls_req_item-requestedquantity
        requestedquantityunit = ls_req_item-requestedquantityunit
        plant                 = ls_req_item-plant
        salesorderitemtext    = ls_req_item-salesorderitemtext
      )
    ).

    IF lt_items IS INITIAL.
      UPDATE z[prefix]_req_h
        SET status       = @lc_status_error,
            message_type = 'E',
            message_text = '아이템 데이터가 없습니다.',
            last_changed_by = @sy-uname,
            last_changed_at = @lv_timestamp
        WHERE req_id = @ls_req_header-req_id.
      CONTINUE.
    ENDIF.

    " 헤더 구조체 조립
    ls_header = VALUE #(
      salesordertype          = ls_req_header-salesordertype
      salesorganization       = ls_req_header-salesorganization
      distributionchannel     = ls_req_header-distributionchannel
      organizationdivision    = ls_req_header-organizationdivision
      soldtoparty             = ls_req_header-soldtoparty
      purchaseorderbycustomer = ls_req_header-purchaseorderbycustomer
      requesteddeliverydate   = ls_req_header-requesteddeliverydate
    ).

    " 공통 클래스 호출 — EML 세부사항은 여기서 몰라도 됨
    ls_result = zcl_[prefix]_comm=>create_sales_order(
      is_header = ls_header
      it_item   = lt_items
    ).

    " 결과에 따라 status 결정
    DATA(lv_status) = SWITCH #( abap_true
      WHEN xsdbool( line_exists( ls_result-messages[ type = 'E' ] ) ) THEN lc_status_error
      WHEN xsdbool( ls_result-vbeln IS NOT INITIAL )                  THEN lc_status_success
      ELSE lc_status_check
    ).

    " 메시지들을 하나의 문자열로 합치기
    " concat_lines_of(): 테이블의 각 행을 구분자로 이어붙이는 내장 함수
    DATA lv_msg_text TYPE c LENGTH 255.
    IF ls_result-messages IS NOT INITIAL.
      DATA(lv_full_msg) = concat_lines_of(
        table = VALUE string_table(
          FOR ls_msg IN ls_result-messages ( CONV string( ls_msg-message ) )
        )
        sep = ' | '
      ).
      " DB 필드가 255자이므로 초과 시 잘라냄
      " +0(255): offset 0에서 255자 substring
      IF strlen( lv_full_msg ) > 255.
        lv_msg_text = lv_full_msg+0(255).
      ELSE.
        lv_msg_text = lv_full_msg.
      ENDIF.
    ENDIF.

    " 결과 UPDATE — status에 따라 vbeln 포함 여부가 다름
    IF lv_status = lc_status_success.
      UPDATE z[prefix]_req_h
        SET status          = @lc_status_success,
            vbeln           = @ls_result-vbeln,   " 생성된 오더번호
            message_type    = 'S',
            message_text    = @lv_msg_text,
            last_changed_by = @sy-uname,
            last_changed_at = @lv_timestamp
        WHERE req_id = @ls_req_header-req_id.
    ELSE.
      UPDATE z[prefix]_req_h
        SET status          = @lv_status,
            message_type    = SWITCH #( lv_status WHEN lc_status_error THEN 'E' ELSE 'W' ),
            message_text    = @lv_msg_text,
            last_changed_by = @sy-uname,
            last_changed_at = @lv_timestamp
        WHERE req_id = @ls_req_header-req_id.
    ENDIF.

  ENDLOOP.

  COMMIT WORK. " 마지막 UPDATE를 DB에 확정

ENDMETHOD.

" 파라미터 없는 잡이면 빈 구현
METHOD if_apj_dt_exec_object~get_parameters.
  et_parameter_def = VALUE #( ).
ENDMETHOD.
```

---

### Step 6. 테스트 클래스 생성

```abap
CLASS zcl_[prefix]_job_test DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun. " ADT F9 실행용
ENDCLASS.

CLASS zcl_[prefix]_job_test IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " 1. 대기건 확인
    SELECT req_id, status, salesordertype, soldtoparty
      FROM z[prefix]_req_h
      WHERE status = '09'
      INTO TABLE @DATA(lt_pending).

    out->write( |대기건 수: { lines( lt_pending ) }| ).
    IF lt_pending IS INITIAL.
      out->write( '대기건 없음' ).
      RETURN.
    ENDIF.

    " 2. Job 실행
    TRY.
        NEW zcl_[prefix]_job( )->if_apj_rt_exec_object~execute(
          it_parameters = VALUE #( )
        ).
        out->write( 'Job 실행 완료' ).
      CATCH cx_root INTO DATA(lx).
        out->write( |오류: { lx->get_text( ) }| ).
        RETURN.
    ENDTRY.

    " 3. 결과 확인
    SELECT req_id, status, vbeln, message_type, message_text
      FROM z[prefix]_req_h
      FOR ALL ENTRIES IN @lt_pending
      WHERE req_id = @lt_pending-req_id
      INTO TABLE @DATA(lt_result).

    LOOP AT lt_result INTO DATA(ls).
      out->write( |{ ls-req_id } → { ls-status } / { ls-vbeln } / { ls-message_text }| ).
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
```

**테스트 방법**: 클래스 열고 `F9` → ADT Console에서 결과 확인

---

### Step 7. Application Job 등록

1. **Fiori App** → "Application Jobs" 접속
2. **Job Catalog Entry** 생성
   - Class Name: `ZCL_[PREFIX]_JOB`
3. **Job Template** 생성
   - Catalog Entry 연결
4. **Schedule** 설정
   - Recurrence: 1~5분 간격 권장
   - 처리 건수에 따라 조정

---

## 6. 주의사항 & 트러블슈팅

### ⚠️ %msg IS BOUND 빠뜨리기

```abap
" 잘못된 코드
message = ls_hdr_err-%msg->if_message~get_text( )  " %msg가 NULL이면 DUMP

" 올바른 코드
IF ls_hdr_err-%msg IS BOUND.
  message = ls_hdr_err-%msg->if_message~get_text( )
ENDIF.
```

### ⚠️ CONVERT KEY 위치

```abap
" 잘못된 코드 — 블록 밖에서 변환 시도
COMMIT ENTITIES BEGIN ... COMMIT ENTITIES END.
CONVERT KEY OF i_salesordertp\salesorder  " ← 여기서는 이미 %pid 무효
  FROM <ls_mapped_hdr>-%pid ...

" 올바른 코드 — 반드시 블록 안에서
COMMIT ENTITIES BEGIN ...
  CONVERT KEY OF i_salesordertp\salesorder  " ← 블록 안에서만 유효
    FROM <ls_mapped_hdr>-%pid ...
COMMIT ENTITIES END.
```

### ⚠️ ROLLBACK 종류 구분

| 구문 | 용도 |
|------|------|
| `ROLLBACK ENTITIES` | RAP 버퍼 취소 (MODIFY ENTITIES 이후) |
| `ROLLBACK WORK` | DB 트랜잭션 전체 롤백 (일반 UPDATE/INSERT 포함) |

RAP EML 실패 시에는 `ROLLBACK ENTITIES`를 사용한다.

### ⚠️ FOR ALL ENTRIES 빈 테이블 주의

```abap
" FOR ALL ENTRIES IN @lt_headers 사용 전에 반드시 INITIAL 체크
" 비어있는 테이블로 FOR ALL ENTRIES 사용 시 전체 테이블 SELECT가 됨
IF lt_headers IS INITIAL.
  RETURN.
ENDIF.
SELECT ... FOR ALL ENTRIES IN @lt_headers ...
```

---

## 7. 다음 프로젝트 적용 체크리스트

### 설계

- [ ] 어떤 BO를 EML로 호출할지 확정 (Released API 여부 확인)
- [ ] 요청 테이블 필드 설계 (헤더/아이템 분리 여부)
- [ ] STATUS 코드 체계 확정
- [ ] Job 반복 주기 결정

### 개발

- [ ] 패키지 생성
- [ ] 헤더 요청 테이블 생성 + Activate
- [ ] 아이템 요청 테이블 생성 + Activate
- [ ] 공통 클래스 작성
  - [ ] 타입 선언 (header/item/message/result)
  - [ ] 필수값 체크 + early return
  - [ ] MODIFY ENTITIES (%cid/%data/%control 세팅)
  - [ ] FAILED 처리 + ROLLBACK ENTITIES
  - [ ] COMMIT ENTITIES BEGIN...END
  - [ ] CONVERT KEY (%pid → 실제 키)
- [ ] Job 클래스 작성
  - [ ] SELECT UP TO 1 ROWS + ORDER BY created_at
  - [ ] 선점 UPDATE + sy-dbcnt 체크 + COMMIT WORK
  - [ ] 공통 클래스 호출
  - [ ] 결과 UPDATE (status/vbeln/message)
- [ ] 테스트 클래스 작성 + F9 실행 확인

### 등록

- [ ] Application Job Catalog Entry 생성
- [ ] Job Template 생성
- [ ] 스케줄 등록 (반복 주기 설정)

---

## 참고

- Released BO: `I_SalesOrderTP`
- Cloud ABAP EML 문서: [SAP Help Portal — EML](https://help.sap.com/docs/abap-cloud)
- Application Jobs 문서: [SAP Help Portal — Schedule Application Jobs](https://help.sap.com/docs/SAP_S4HANA_CLOUD)
