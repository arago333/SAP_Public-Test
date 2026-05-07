# Sales Order 비동기 생성 패턴 가이드

> `I_SalesOrderTP` EML 기반 판매오더 비동기 생성 패턴  
> 구성 오브젝트: `ZCL_SO_COMM_KAR`, `ZCL_SO_JOB_KAR`, `ZSSO_REQ_H_KAR`, `ZSSO_REQ_I_KAR`

---

## 목차

1. [배경 및 제약사항](#1-배경-및-제약사항)
2. [전체 아키텍처](#2-전체-아키텍처)
3. [DB 테이블 설계](#3-db-테이블-설계)
4. [클래스 설계](#4-클래스-설계)
5. [구현 단계별 가이드](#5-구현-단계별-가이드)
6. [핵심 로직 분석](#6-핵심-로직-분석)
7. [다음 프로젝트 적용 체크리스트](#7-다음-프로젝트-적용-체크리스트)

---

## 1. 배경 및 제약사항

### 왜 비동기 구조인가?

`I_SalesOrderTP` (RAP BO)는 **한 LUW(논리적 작업 단위) 안에서 1건만 처리 가능**하다.  
`COMMIT ENTITIES`가 내부적으로 DB COMMIT을 포함하기 때문에, 대량 요청을 한 번에 처리할 수 없다.

```
[외부 요청] → [요청 테이블에 INSERT(status=09)] → [Job이 1건씩 꺼내서 처리]
```

### 핵심 제약

| 항목 | 내용 |
|------|------|
| EML MODIFY 후 COMMIT | 반드시 같은 세션에서 `COMMIT ENTITIES` 필요 |
| 1 LUW = 1건 | `I_SalesOrderTP` 특성상 1건 처리 후 COMMIT |
| Classic ABAP 금지 | `BAPI_SALESORDER_CREATEFROMDAT2` 사용 불가 (Cloud 환경) |
| Released API만 사용 | `I_SalesOrderTP` 는 Cloud ABAP Released API |

---

## 2. 전체 아키텍처

```
┌─────────────────────────────────────────────────────┐
│                   외부 호출자                         │
│         (Fiori App / OData / 다른 프로그램)            │
└──────────────────────┬──────────────────────────────┘
                       │ INSERT
                       ▼
┌─────────────────────────────────────────────────────┐
│  ZSSO_REQ_H_KAR (헤더 요청 테이블)  status=09(대기)  │
│  ZSSO_REQ_I_KAR (아이템 요청 테이블)                  │
└──────────────────────┬──────────────────────────────┘
                       │ SELECT (UP TO 1 ROWS)
                       ▼
┌─────────────────────────────────────────────────────┐
│  ZCL_SO_JOB_KAR (Application Job)                   │
│  - 짧은 주기로 반복 스케줄링                           │
│  - 1건 SELECT → status=05로 선점 → 처리               │
└──────────────────────┬──────────────────────────────┘
                       │ call
                       ▼
┌─────────────────────────────────────────────────────┐
│  ZCL_SO_COMM_KAR::create_sales_order()              │
│  - 필수값 체크                                        │
│  - MODIFY ENTITIES OF i_salesordertp                 │
│  - COMMIT ENTITIES BEGIN...END                       │
│  - CONVERT KEY (pid → 판매오더번호)                   │
└──────────────────────┬──────────────────────────────┘
                       │ UPDATE status
                       ▼
┌─────────────────────────────────────────────────────┐
│  ZSSO_REQ_H_KAR                                     │
│  status=01(성공) / 05(처리중) / 99(오류)              │
│  vbeln = 생성된 판매오더번호                           │
└─────────────────────────────────────────────────────┘
```

---

## 3. DB 테이블 설계

### 3.1 헤더 테이블: ZSSO_REQ_H_KAR

| 필드명 | 타입 | 설명 |
|--------|------|------|
| CLIENT | CLNT | 클라이언트 (PK) |
| REQ_ID | SYSUUID_C22 | 요청 UUID (PK) |
| STATUS | CHAR(2) | **처리 상태** (아래 참고) |
| SALESORDERTYPE | AUART | 오더유형 |
| SALESORGANIZATION | VKORG | 판매조직 |
| DISTRIBUTIONCHANNEL | VTWEG | 유통채널 |
| ORGANIZATIONDIVISION | SPART | 사업부 |
| SOLDTOPARTY | KUNNR | 판매처 |
| PURCHASEORDERBYCUSTOMER | BSTKD | 고객 PO번호 |
| REQUESTEDDELIVERYDATE | EDATU | 요청납기일 |
| VBELN | VBELN_VA | **생성된 판매오더번호** |
| MESSAGE_TYPE | CHAR(1) | S/W/E |
| MESSAGE_TEXT | CHAR(255) | 결과 메시지 |
| CREATED_BY | SYUNAME | 생성자 |
| CREATED_AT | TIMESTAMPL | 생성일시 |
| LAST_CHANGED_BY | SYUNAME | 최종변경자 |
| LAST_CHANGED_AT | TIMESTAMPL | 최종변경일시 |

**STATUS 코드 정의**

| 값 | 의미 |
|----|------|
| `09` | 대기 (Wait) |
| `05` | 처리중 (Check / Processing) |
| `01` | 성공 (Success) |
| `99` | 오류 (Error) |

### 3.2 아이템 테이블: ZSSO_REQ_I_KAR

| 필드명 | 타입 | 설명 |
|--------|------|------|
| CLIENT | CLNT | 클라이언트 (PK) |
| REQ_ID | SYSUUID_C22 | 요청 UUID (PK) |
| REQ_ITEM_NO | NUMC(6) | 요청 아이템 순번 (PK) |
| SALESORDERITEM | POSNV | 판매오더 품목번호 |
| PRODUCT | MATNR | 자재번호 |
| REQUESTEDQUANTITY | QUAN(13,3) | 요청수량 |
| REQUESTEDQUANTITYUNIT | UNIT(3) | 수량단위 |
| PLANT | WERKS_D | 플랜트 |
| SALESORDERITEMTEXT | CHAR(40) | 품목텍스트 |

> **PK 설계 포인트**: REQ_ID(UUID) + REQ_ITEM_NO(순번) 조합  
> 아이템 테이블에는 헤더 STATUS가 없음 — 헤더가 모든 상태 관리

---

## 4. 클래스 설계

### 4.1 ZCL_SO_COMM_KAR — 판매오더 생성 공통 클래스

**역할**: EML로 `I_SalesOrderTP` 호출하는 순수 기능 클래스

```
ZCL_SO_COMM_KAR
├── TYPE ts_so_header       헤더 입력 구조체
├── TYPE ts_so_item         아이템 입력 구조체
├── TYPE tt_so_item         아이템 테이블 타입
├── TYPE ts_message         메시지 구조체 (type + message)
├── TYPE tt_messages        메시지 테이블 타입
├── TYPE ts_result          결과 구조체 (vbeln + success + committed + messages)
└── METHOD create_sales_order (CLASS-METHOD)
    IMPORTING: is_header(헤더), it_item(아이템 테이블)
    RETURNING: rs_result(결과)
```

**설계 원칙**:
- `CLASS-METHOD` → 인스턴스 생성 불필요, 어디서든 직접 호출
- 입/출력 타입을 모두 클래스 내부에 선언 → 의존성 최소화
- COMMIT까지 포함 → 호출자는 결과만 확인

### 4.2 ZCL_SO_JOB_KAR — Application Job 클래스

**역할**: 요청 테이블을 폴링하여 1건씩 처리하는 스케줄러

```
ZCL_SO_JOB_KAR
├── INTERFACES if_apj_dt_exec_object   Job 파라미터 정의 (Design Time)
└── INTERFACES if_apj_rt_exec_object   Job 실행 로직 (Run Time)
    └── METHOD execute
        ├── SELECT ... UP TO 1 ROWS (대기건 1건)
        ├── UPDATE status=05 WHERE status=09  ← 선점 잠금
        ├── COMMIT WORK  ← 선점 확정
        ├── ZCL_SO_COMM_KAR=>create_sales_order()
        └── UPDATE status=01/05/99 + vbeln
```

---

## 5. 구현 단계별 가이드

### Step 1. 패키지 생성

```
패키지명: ZKAR_SO (또는 프로젝트에 맞게)
설명: Sales Order Common Class
```

### Step 2. DB 테이블 생성

ADT → New → Database Table 순서로 생성:

1. `ZSSO_REQ_H_KAR` — 헤더 요청 테이블
2. `ZSSO_REQ_I_KAR` — 아이템 요청 테이블

> UUID 키 사용: `SYSUUID_C22` 타입 사용 권장 (중복 없는 UUID)

### Step 3. 공통 클래스 생성 (ZCL_SO_COMM_KAR)

```abap
" 타입 선언 순서
1. ts_so_header    - I_SalesOrderTP 헤더 필드
2. ts_so_item      - I_SalesOrderTP 아이템 필드
3. tt_so_item      - 아이템 테이블
4. ts_message      - 메시지 (type + message)
5. tt_messages     - 메시지 테이블
6. ts_result       - 결과 (vbeln + success + committed + messages)
```

**create_sales_order 구현 흐름:**

```
① 필수값 체크 → E 메시지 있으면 early return
② EML 타입 선언 (TABLE FOR CREATE i_salesordertp)
③ 헤더 %cid / %data / %control 세팅
④ 아이템 %cid_ref / %target LOOP 세팅
⑤ MODIFY ENTITIES → MAPPED / FAILED / REPORTED 수신
⑥ FAILED 체크 → ROLLBACK ENTITIES + 메시지 추출
⑦ COMMIT ENTITIES BEGIN...END
   └─ CONVERT KEY (pid → 판매오더번호)
⑧ 결과 반환
```

### Step 4. Job 클래스 생성 (ZCL_SO_JOB_KAR)

```abap
" 인터페이스 구현
INTERFACES if_apj_dt_exec_object.   " 파라미터 없으면 빈 구현
INTERFACES if_apj_rt_exec_object.   " execute 메서드에 실제 로직
```

**선점 잠금 패턴 (중요):**

```abap
" status=09 → 05 UPDATE (다른 Job 인스턴스가 가져가지 못하도록)
UPDATE zsso_req_h_kar
  SET status = '05'
  WHERE req_id = @ls_req_header-req_id
  AND status = @lc_status_wait.   " ← WHERE 조건으로 원자적 선점

IF sy-dbcnt = 0.
  CONTINUE.   " 이미 다른 프로세스가 가져간 것 → 스킵
ENDIF.

COMMIT WORK.   " 선점 즉시 COMMIT (다른 Job 인스턴스와 격리)
```

### Step 5. 테스트 클래스 생성 (ZCL_SO_JOB_TEST_KAR)

```abap
INTERFACES if_oo_adt_classrun.   " ADT Console Runner
```

테스트 순서:
1. 테이블에 테스트 데이터 수동 INSERT (status=`09`)
2. `if_oo_adt_classrun~main` 실행 (F9)
3. 결과 테이블 SELECT로 확인

### Step 6. Application Job 등록

Fiori App **Application Jobs** 에서:
1. Job Catalog Entry 생성 → `ZCL_SO_JOB_KAR` 지정
2. Job Template 생성
3. 스케줄: **반복 주기 짧게** (예: 1~5분) 설정

---

## 6. 핵심 로직 분석

### 6.1 %cid / %cid_ref 패턴

```abap
ls_so-%cid = 'SO1'.          " 헤더에 임시 ID 부여

ls_item-%cid_ref = 'SO1'.    " 아이템이 'SO1' 헤더를 참조
" %target 에 아이템 행들을 APPEND
```

> `%cid`는 COMMIT 전 단계의 임시 식별자.  
> 헤더-아이템 관계를 EML 안에서 연결하는 핵심 메커니즘.

### 6.2 COMMIT ENTITIES BEGIN...END 블록

```abap
COMMIT ENTITIES BEGIN
  RESPONSE OF i_salesordertp
  FAILED   DATA(ls_commit_failed)
  REPORTED DATA(ls_commit_reported).

  " ← 이 블록 안에서만 ls_mapped 유효
  " CONVERT KEY 도 반드시 여기서 수행
  LOOP AT ls_mapped-salesorder ASSIGNING FIELD-SYMBOL(<ls_mapped_hdr>).
    CONVERT KEY OF i_salesordertp\salesorder
      FROM <ls_mapped_hdr>-%pid
      TO DATA(ls_final_key).
    rs_result-vbeln = ls_final_key-salesorder.
    EXIT.
  ENDLOOP.

COMMIT ENTITIES END.
```

> **주의**: `%pid`(provisional ID) → 실제 키 변환은 반드시 `BEGIN...END` 블록 안에서.

### 6.3 FAILED vs REPORTED

| 변수 | 내용 |
|------|------|
| `ls_failed` | 실패한 엔티티 목록 (어떤 %cid가 실패했는지) |
| `ls_reported` | 실패 메시지 상세 (`%msg` 객체 포함) |

```abap
" 메시지 추출 패턴
LOOP AT ls_reported-salesorder INTO DATA(ls_hdr_err).
  IF ls_hdr_err-%msg IS BOUND.
    APPEND VALUE #(
      type    = 'E'
      message = ls_hdr_err-%msg->if_message~get_text( )
    ) TO rs_result-messages.
  ENDIF.
ENDLOOP.
```

> `IS BOUND` 체크 필수 — `%msg`는 인터페이스 참조라 NULL일 수 있음.

### 6.4 메시지 길이 처리

```abap
" 여러 메시지를 하나의 문자열로 합칠 때
DATA(lv_full_msg) = concat_lines_of(
  table = VALUE string_table(
    FOR ls_msg IN ls_result-messages ( CONV string( ls_msg-message ) )
  )
  sep = ' | '
).

" DB 필드 길이(255) 초과 시 자르기
IF strlen( lv_full_msg ) > 255.
  lv_msg_text = lv_full_msg+0(255).
ENDIF.
```

### 6.5 동시성 처리 (Optimistic Locking)

```
Job A: SELECT req_id='UUID-1' (status=09) ──→ UPDATE status=05 WHERE status=09
Job B: SELECT req_id='UUID-1' (status=09) ──→ UPDATE status=05 WHERE status=09
                                                └─ sy-dbcnt=0 → CONTINUE (스킵)
```

`WHERE status = @lc_status_wait` 조건이 낙관적 잠금 역할.  
`COMMIT WORK` 직후 다른 프로세스는 해당 건을 선점 불가.

---

## 7. 다음 프로젝트 적용 체크리스트

### 설계 단계

- [ ] 요청 테이블 설계 (헤더/아이템 분리 or 통합)
- [ ] STATUS 코드 체계 정의 (09/05/01/99 권장)
- [ ] UUID vs 번호채번 방식 결정
- [ ] 처리 주기 결정 (Job 반복 간격)

### 개발 단계

- [ ] 패키지 생성
- [ ] DB 테이블 생성 (헤더 + 아이템)
- [ ] 공통 클래스 (`create_*`) 작성
  - [ ] 필수값 체크
  - [ ] EML MODIFY ENTITIES
  - [ ] COMMIT ENTITIES BEGIN...END
  - [ ] CONVERT KEY
- [ ] Job 클래스 작성
  - [ ] `UP TO 1 ROWS` SELECT
  - [ ] 선점 UPDATE + COMMIT WORK
  - [ ] 공통 클래스 호출
  - [ ] 결과 UPDATE
- [ ] 테스트 클래스 (`if_oo_adt_classrun`) 작성

### 확인 사항

- [ ] `%msg IS BOUND` 체크 누락 없는지
- [ ] COMMIT ENTITIES BEGIN...END 블록 안에서 CONVERT KEY 수행하는지
- [ ] ROLLBACK ENTITIES 위치 정확한지 (FAILED 시, COMMIT 오류 시 각각)
- [ ] 메시지 텍스트 255자 초과 처리 있는지
- [ ] Job 등록 (Application Jobs Fiori 앱) 완료했는지

---

## 참고

- Released BO: `I_SalesOrderTP` (S/4HANA Public Cloud)
- EML 문서: SAP Help Portal > ABAP RESTful Application Programming Model > EML
- Application Jobs: SAP Help Portal > Schedule Application Jobs
