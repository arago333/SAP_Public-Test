# ZSDR0001 — SD IS API Log 개발 완전 가이드

---

## 1. 설계서 분석법

### 순서 (이거 안 지키면 돌아감)
```
① Input 조건   → 필드명 / 타입 / 단일(P) or 멀티(S) / 초기값 / M(필수) or O(선택)
② Output 필드  → 표시할 필드 / 타입 / 용도
③ 정렬/필터 로직 → 어떤 기준으로 정렬, 조건 조합 방식
④ 상세 기능    → 비즈니스 로직, 특수 처리
⑤ API/CDS 목록 → 외부 API URL, 필드 목록, 사용 여부(USE)
```

### 이번 설계서에서 추출한 것들

**Input 조건:**
| Field | 단일/멀티 | 타입 | 초기값 | 의미 |
|---|---|---|---|---|
| Status_Is | 멀티(S) | CHAR(1) | O/X/공백 | IS 송수신 결과 |
| Status_In | 멀티(S) | CHAR(1) | O/X/공백 | 내부 처리 결과 |
| Module | 단일 | CHAR(3) | SD | FlowName 포함 조건 |
| Date | 멀티(S) | DATS(8) | - | LastTime 날짜 |
| Time | 멀티(S) | CHAR(6) | - | LastTime 시간 |

**Output 필드:**
| Field | 타입 | 설명 |
|---|---|---|
| Status_IS | CHAR(1) | 초록(O)/빨강(X) 아이콘 |
| Status_IN | CHAR(1) | 초록(O)/빨강(X) 아이콘, IS 실패 시 공백 |
| FlowName | CHAR(40) | IS Flow 이름 |
| LastTime | CHAR(20) | 마지막 변경 시간 (ex. 2026-05-14T13:25) |
| IN_Log | STRING | 로그 상세 텍스트 |

**정렬/필터 로직 (핵심):**
- Module → FlowName **포함** 조건 (`LIKE '%SD%'`)
- Date + Time → LastTime **조합** 매칭
- LastTime 기준 **내림차순** 정렬
- StatusIS 실패(X) → StatusIN은 **공백**

**이번에 놓쳤던 것들:**
| 항목 | 놓친 것 | 결과 |
|---|---|---|
| Module | FlowName 포함 조건 | DB SELECT에 LIKE 없이 전체 조회 |
| Date+Time | 조합해서 LastTime 매칭 | 시간 필터 없이 개발 |
| LastTime | 내림차순 정렬 | ORDER BY messageguid로 잘못 정렬 |
| StatusIS/IN | 멀티 조건 | DB SELECT 필터 누락 |

---

## 2. RAP 구조 설계 기준

### 언제 뭘 쓰나
```
외부 API 호출 + 조회만?
  └─ View Entity + Query Provider + 일반 클래스(API 호출)

저장/수정/삭제 필요?
  └─ Managed BO (persistent table)

둘 다 필요?
  └─ 두 구조 병행 → 복잡해짐, 최대한 피할 것
     어쩔 수 없으면 역할 명확히 분리

팝업/팝오버?
  └─ RAP + Metadata Extension만으론 불가
  └─ BAS + manifest.json + Controller Extension 필요
```

### CDS 종류 선택
| 종류 | 언제 | 특징 |
|---|---|---|
| `View Entity` | 일반 조회 | DB 기반, SELECT 가능 |
| `Custom Entity` | 외부 API 연동 | Query Provider 필수, DB 없음 |
| `Root View Entity` | BO 루트 | persistent table 연결 |
| `Projection View` | UI 노출용 | provider contract 설정 |

### 이번 프로젝트 구조
```
ZR_SD_IS_LOG_KAR2 (View Entity + Query Provider)
  → 조회 전용: List Report + Object Page
  → ZBPR_SD_IS_LOG_KAR2 (Query Provider 구현)

ZR_SD_IS_LOG2_KAR (Managed BO)
  → Action 전용: fetchLogs, fetchLog
  → ZBP_R_SD_IS_LOG2_KAR (Behavior Pool)

ZBPR_SD_IS_LOG_SAVE_KAR (일반 클래스)
  → DB 저장 전용: fetch_and_save, update_log
```

### 클래스를 왜 나눴나
| 클래스 | 역할 | 이유 |
|---|---|---|
| `ZBPR_SD_IS_LOG_KAR2` | Query Provider (조회) | if_rap_query_provider 구현 |
| `ZBPR_SD_IS_LOG_SAVE_KAR` | DB 저장 전용 | Query Provider에서 UPDATE 불가 → 분리 |
| `ZBP_R_SD_IS_LOG2_KAR` | Managed BO Action | fetchLogs, fetchLog Action 구현 |

**핵심:** Query Provider는 READ-only contract → UPDATE 직접 불가 → 별도 클래스로 분리

---

## 3. Query Provider 구조

### if_rap_query_provider~select 흐름
```abap
METHOD if_rap_query_provider~select.

  " ① 필터 꺼내기
  DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).

  " ② 필터 변수 추출
  LOOP AT lt_filter INTO DATA(ls_filter).
    CASE ls_filter-name.
      WHEN 'FIELDNAME'. lv_var = ls_filter-range[ 1 ]-low.
    ENDCASE.
  ENDLOOP.

  " ③ 페이징
  DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).
  DATA(lv_skip) = io_request->get_paging( )->get_offset( ).

  " ④ 데이터 조회 + 결과 담기
  DATA lt_result TYPE TABLE OF {view_entity}.
  APPEND VALUE {view_entity}( ... ) TO lt_result.

  " ⑤ 응답
  io_response->set_total_number_of_records( lv_total ).
  io_response->set_data( lt_result ).

ENDMETHOD.
```

### Object Page vs List Report 분기
```abap
" MessageGuid가 있으면 Object Page 조회
IF lv_messageguid IS NOT INITIAL.
  " 단건 조회 로직
  io_response->set_total_number_of_records( lines( lt_result ) ).
  io_response->set_data( lt_result ).
  RETURN.
ENDIF.

" MessageGuid 없으면 List Report 조회
```

---

## 4. 외부 API 연동 패턴

### Communication Arrangement 호출
```abap
DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                  comm_scenario = 'ZCS_GAS_COMM'
                  service_id    = 'ZOB_ISLOG_REST' ).
DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                    i_destination = lo_dest ).
DATA(lo_req) = lo_client->get_http_request( ).
lo_req->set_uri_path( i_uri_path = |http/gasentec/SD0000_005?...| ).
DATA(lo_res) = lo_client->execute( i_method = if_web_http_client=>get ).
DATA(lv_code) = lo_res->get_status( )-code.
DATA(lv_body) = lo_res->get_text( ).
lo_client->close( ).
```

### fetch_and_save 패턴 (외부 API → DB 저장)
```abap
" 1. API 호출
" 2. JSON 파싱 (/ui2/cl_json=>deserialize)
" 3. DB MODIFY (있으면 UPDATE, 없으면 INSERT)
MODIFY {table} FROM TABLE @lt_data.
```

### IS API (OData V2) 필터 문법
| Edm 타입 | suffix | 예시 |
|---|---|---|
| String | `'...'` | `Status eq 'COMPLETED'` |
| Int64 | `L` | `LastChangeTime ge 1779324480000L` |
| DateTime | `datetime'...'` | `LogStart ge datetime'2026-05-21T00:00:00'` |
| Int32 | 없음 | `Count gt 10` |

**LastChangeTime 주의:**
- 응답은 String이지만 필터는 Int64 (`L` suffix 필수)
- `datetime'...'` 형식 불가
- KST → UTC 변환 필요 (-9시간)

---

## 5. 삽질 포인트

### Query Provider에서 UPDATE 불가
```
에러: Executing "UPDATE <dbtab>" from "SELECT" violates transactional contract "READ"
해결: 별도 일반 클래스 메서드로 분리
```

### WHERE절 host variable 타입 제약
```abap
" ❌ string 불가
DATA lv_pat TYPE string.
SELECT ... WHERE flowname LIKE @lv_pat.

" ✅ CHAR 타입으로
DATA lv_pat TYPE c LENGTH 45.
```

### FIND REGEX POSIX deprecated
```abap
" ❌ 에러
FIND FIRST OCCURRENCE OF REGEX `\('([^']+)'\)` IN lv_str MATCH OFFSET lv_pos.

" ✅ 문자열 파싱으로 대체
FIND FIRST OCCURRENCE OF `('` IN lv_str MATCH OFFSET lv_pos1.
lv_pos1 = lv_pos1 + 2.
DATA(lv_temp) = lv_str+lv_pos1.
FIND FIRST OCCURRENCE OF `')` IN lv_temp MATCH OFFSET lv_pos2.
lv_id = lv_temp(lv_pos2).
```

### features:instance → 자동 $batch POST 에러
```
action ( features : instance ) fetchLog ...
→ Fiori 화면 로드 시 $batch POST 자동 발생
→ Query Provider는 POST 불가 → 에러
해결: ( features : instance ) 제거
```

### Attachment URL 404
```
MessageProcessingLogAttachments('696e...')/$value
→ /api/v1/ 붙여서 호출 → it-cpi015-rt에서 404
이유: runtime URL은 /api/v1/ 직접 접근 불가
해결: SD0000_006 iFlow 통해 호출
  http/gasentec/SD0000_006?Attachments%28%27{id}%27%29/%24value
```

### utclong_diff 파라미터명
```abap
" ❌ 에러
utclong_diff( val1 = lv_from val2 = lv_epoch ).

" ✅ 정답
utclong_diff( high = lv_from low = CONV utclong( '1970-01-01 00:00:00' ) ).
```

---

## 6. ABAP Cloud 제약 요약

| 제약 | 대안 |
|---|---|
| Query Provider에서 UPDATE 불가 | 일반 클래스로 분리 |
| WHERE절 string 타입 불가 | CHAR 타입으로 선언 |
| FIND REGEX POSIX deprecated | 문자열 파싱 |
| Custom Entity → Action 불가 | Managed BO 병행 |
| 팝업/팝오버 → RAP만 불가 | BAS + manifest.json |
| SUBMIT, CALL TRANSACTION 불가 | Released API만 사용 |

---

## 7. epoch 변환 공식

### KST → epoch milliseconds (IS API 필터용)
```abap
DATA(lv_utc) = CONV utclong(
  |{ date(4) }-{ date+4(2) }-{ date+6(2) }T{ time(2) }:{ time+2(2) }:00| ).
DATA(lv_diff) = utclong_diff(
  high = lv_utc
  low  = CONV utclong( '1970-01-01 00:00:00' ) ).
lv_epoch = ( CONV int8( lv_diff ) - 32400 ) * 1000.  " -32400 = KST→UTC 보정
```

### epoch milliseconds → KST (IS API 응답 → DB 저장용)
```abap
DATA(lv_seconds) = CONV decfloat34( lv_lastchangetime ) / 1000.
DATA(lv_utclong) = utclong_add(
  val     = CONV utclong( '1970-01-01 00:00:00' )
  seconds = lv_seconds ).
lv_utclong = utclong_add( val = lv_utclong seconds = 32400 ).  " +32400 = UTC→KST
CONVERT UTCLONG lv_utclong TIME ZONE 'UTC' INTO DATE lv_date TIME lv_time.
```

---

## 8. 주요 ABAP 문법 (이번에 쓴 것들)

### SWITCH / COND
```abap
" SWITCH: 값 매핑
DATA(lv_status) = SWITCH #( ls_log-status
  WHEN 'COMPLETED' THEN 'O'
  WHEN 'FAILED'    THEN 'X'
  ELSE ' ' ).

" COND: 조건 분기
DATA(lv_time_str) = COND string(
  WHEN iv_time IS NOT INITIAL THEN iv_time(2)
  ELSE '00' ).
```

### CONV
```abap
" 타입 변환
DATA(lv_utc) = CONV utclong( '2026-05-22T10:00:00' ).
DATA(lv_int) = CONV int8( lv_decfloat ).
```

### MODIFY (INSERT or UPDATE)
```abap
" 있으면 UPDATE, 없으면 INSERT
MODIFY {table} FROM TABLE @lt_data.
```

### SPLIT + 문자열 파싱
```abap
" XML entry 파싱
SPLIT lv_feed AT '<entry>' INTO TABLE lt_entries.
LOOP AT lt_entries INTO lv_entry.
  IF lv_entry CS 'Log : END - Body'.
    FIND FIRST OCCURRENCE OF 'src="' IN lv_entry MATCH OFFSET lv_pos.
    lv_tail = lv_entry+(lv_pos + 5).
    FIND FIRST OCCURRENCE OF '"' IN lv_tail MATCH OFFSET lv_end.
    lv_path = lv_tail(lv_end).
  ENDIF.
ENDLOOP.
```

### JSON 파싱
```abap
/ui2/cl_json=>deserialize(
  EXPORTING json = lv_response
  CHANGING  data = ls_response ).
```
