CLASS zcl_testpost_comm_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " 전표 헤더 구조체
    TYPES: BEGIN OF ts_bkpf,
             companycode                  TYPE bukrs,
             accountingdocumenttype       TYPE blart,
             documentdate                 TYPE bldat,
             postingdate                  TYPE budat,
             accountingdocumentheadertext TYPE bktxt,
             waers                        TYPE waers,
           END OF ts_bkpf.

    " 전표 라인 아이템 구조체
    TYPES: BEGIN OF ts_bseg,
             glaccount              TYPE hkont,   " G/L 계정
             journalentryitemamount TYPE wrbtr,   " 전기금액
             documentitemtext       TYPE sgtxt,   " 아이템텍스트
             costcenter             TYPE kostl,   " 코스트센터
             profitcenter           TYPE prctr,   " 프로핏센터
           END OF ts_bseg.
    TYPES tt_bseg TYPE TABLE OF ts_bseg WITH EMPTY KEY.  " 라인 아이템 테이블 타입

    " 역분개(Reverse) 파라미터 구조체
    TYPES: BEGIN OF ts_reverse,
             companycode        TYPE bukrs,      " 회사코드
             fiscalyear         TYPE gjahr,      " 회계연도
             accountingdocument TYPE belnr_d,    " 역전할 전표번호
             postingdate        TYPE budat,      " 전기일자
             reversalreason     TYPE c LENGTH 2, " 역전사유 코드
           END OF ts_reverse.
    " ────────────────────────────────────────
    " 메서드 선언 — CLASS-METHODS = 정적 메서드 (인스턴스 생성 없이 호출 가능)
    " 호출 방식: zcl_testpost_comm_kar=>document_post_func( ... )
    " ────────────────────────────────────────

    " 전표 전기 메서드
    CLASS-METHODS document_post_func
      IMPORTING !is_bkpf     TYPE ts_bkpf      " 헤더 (단건 구조체)
                !it_bseg     TYPE tt_bseg       " 라인 아이템 (테이블)
      EXPORTING !ev_belnr    TYPE belnr_d       " 생성된 전표번호 반환
                !ev_gjahr    TYPE gjahr         " 생성된 회계연도 반환
                !et_messages TYPE bapirettab.   " 에러/성공 메시지 반환

    " 전표 역전 메서드
    CLASS-METHODS document_reverse_func
      IMPORTING !is_reverse       TYPE ts_reverse   " 역전 대상 전표 정보
      EXPORTING !ev_reverse_belnr TYPE belnr_d      " 생성된 역전 전표번호 반환
                !ev_reverse_gjahr TYPE gjahr        " 생성된 역전 회계연도 반환
                !et_messages      TYPE bapirettab.  " 에러/성공 메시지 반환

ENDCLASS.



CLASS ZCL_TESTPOST_COMM_KAR IMPLEMENTATION.


  METHOD document_post_func.
    " ════════════════════════════════════════
    " (1) 관문 — 필수값 체크
    " RETURN 하면 이후 로직 실행 안 함
    " ════════════════════════════════════════
    IF is_bkpf-companycode IS INITIAL.
      APPEND VALUE #( type = 'E' message = '회사코드는 필수 항목입니다.' ) TO et_messages.
      RETURN.
    ENDIF.

    " ════════════════════════════════════════
    " (2) EML용 액션 테이블 선언
    " TABLE FOR ACTION IMPORT i_journalentrytp~post
    " → I_JournalEntryTP BO의 post 액션에 넘길 파라미터 테이블 타입
    " ════════════════════════════════════════
    DATA: lt_post_entries TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          ls_entry        LIKE LINE OF lt_post_entries.  " 위 테이블의 라인 1개

    " ════════════════════════════════════════
    " (3) 헤더 파라미터 세팅
    " ls_entry-%param = post 액션에 전달할 입력값 묶음
    " ════════════════════════════════════════
    TRY.
        ls_entry-%cid = cl_system_uuid=>create_uuid_c22_static( ).
      CATCH cx_uuid_error.
        GET TIME STAMP FIELD DATA(lv_ts).
        ls_entry-%cid = CONV sysuuid_c22( lv_ts ).
    ENDTRY.
    ls_entry-%param = VALUE #(
      companycode                  = is_bkpf-companycode
      documentreferenceid          = 'BKPFF'   " 참조문서ID (고정값)
      businesstransactiontype      = 'RFBU'    " 거래유형: 재무 일반전표 (고정값)
      createdbyuser                = sy-uname  " 현재 로그인 유저
      accountingdocumenttype       = is_bkpf-accountingdocumenttype
      documentdate                 = is_bkpf-documentdate
      postingdate                  = is_bkpf-postingdate
      accountingdocumentheadertext = is_bkpf-accountingdocumentheadertext
    ).

    " ════════════════════════════════════════
    " (4) 라인 아이템 세팅
    " it_bseg 테이블을 루프 돌며 _glitems (G/L 아이템 목록) 에 APPEND
    " lv_lineitem = 아이템 순번 (1, 2, 3 ...)
    " ════════════════════════════════════════
    DATA lv_lineitem TYPE sy-tabix.
    LOOP AT it_bseg INTO DATA(ls_bseg).
      lv_lineitem = lv_lineitem + 1.  " 순번 증가
      APPEND VALUE #(
        glaccountlineitem = lv_lineitem              " 아이템 순번
        documentitemtext  = ls_bseg-documentitemtext
        profitcenter      = ls_bseg-profitcenter
        costcenter        = ls_bseg-costcenter
        glaccount         = ls_bseg-glaccount
        _currencyamount   = VALUE #( (               " 금액 + 통화 묶음 (내부 테이블)
          journalentryitemamount = ls_bseg-journalentryitemamount
          currency               = is_bkpf-waers ) )
      ) TO ls_entry-%param-_glitems.  " 헤더의 _glitems 하위에 아이템 추가
    ENDLOOP.
    APPEND ls_entry TO lt_post_entries.  " 완성된 엔트리를 액션 테이블에 추가

    " ════════════════════════════════════════
    " (5) EML — MODIFY ENTITIES (Interaction Phase)
    " 실제 DB 저장은 아직 아님. "전기 요청"을 SAP 프레임워크에 등록하는 단계
    " MAPPED   : 성공적으로 처리된 키 목록
    " FAILED   : 실패한 키 목록
    " REPORTED : 에러/경고 메시지 목록
    " ════════════════════════════════════════


*    MODIFY ENTITIES OF i_journalentrytp
*      ENTITY journalentry
*        EXECUTE post FROM lt_post_entries
*        MAPPED   DATA(ls_mapped)
*        FAILED   DATA(ls_failed)
*        REPORTED DATA(ls_reported).
*
*    " FAILED가 비어있지 않으면 = 전기 요청 자체가 실패
*    " → 메시지 수집 후 RETURN (COMMIT 하지 않음)
*    IF ls_failed IS NOT INITIAL.
*      LOOP AT ls_reported-journalentry INTO DATA(ls_err).
*        APPEND VALUE #(
*          type    = 'E'
*          message = ls_err-%msg->if_message~get_text( )  " 메시지 객체에서 텍스트 추출
*        ) TO et_messages.
*      ENDLOOP.
*      RETURN.
*    ENDIF.

    TRY.
        MODIFY ENTITIES OF i_journalentrytp
          ENTITY journalentry
            EXECUTE post FROM lt_post_entries
            MAPPED   DATA(ls_mapped)
            FAILED   DATA(ls_failed)
            REPORTED DATA(ls_reported).
      CATCH cx_root INTO DATA(lx_root).
        APPEND VALUE #(
          type    = 'E'
          message = lx_root->get_text( )
        ) TO et_messages.
        RETURN.
    ENDTRY.

*    IF ls_failed IS NOT INITIAL.
*      LOOP AT ls_reported-journalentry INTO DATA(ls_err).
*        APPEND VALUE #(
*          type    = 'E'
*          message = ls_err-%msg->if_message~get_text( )
*        ) TO et_messages.
*      ENDLOOP.
*      RETURN.
*    ENDIF.
    IF ls_failed IS NOT INITIAL.
      LOOP AT ls_reported-journalentry INTO DATA(ls_err).
        IF ls_err-%msg IS BOUND.
          APPEND VALUE #(
            type    = 'E'
            message = ls_err-%msg->if_message~get_text( )
          ) TO et_messages.
        ENDIF.
      ENDLOOP.
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '전표 전기 요청 실패' ) TO et_messages.
      ENDIF.
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.



    " ════════════════════════════════════════
    " (6) COMMIT ENTITIES (Save Phase)
    " 여기서 실제로 DB에 전표가 저장됨
    " RESPONSE OF i_journalentrytp : 커밋 후 결과(전표번호 등)를 받아옴
    " ════════════════════════════════════════
    COMMIT ENTITIES RESPONSE OF i_journalentrytp
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    IF ls_commit_failed IS INITIAL.  " 커밋 성공
      " 커밋 결과에서 생성된 전표번호/회계연도 추출
      READ TABLE ls_commit_reported-journalentry INTO DATA(ls_success) INDEX 1.
      IF sy-subrc = 0.  " READ TABLE 성공 여부 확인
        ev_belnr = ls_success-accountingdocument.  " 전표번호 반환
        ev_gjahr = ls_success-fiscalyear.          " 회계연도 반환
      ENDIF.
*    ELSE.  " 커밋 실패
*      LOOP AT ls_commit_reported-journalentry INTO DATA(ls_cmt_err).
*        APPEND VALUE #(
*          type    = 'E'
*          message = ls_cmt_err-%msg->if_message~get_text( )
*        ) TO et_messages.
*      ENDLOOP.
*    ENDIF.
    ELSE.
      LOOP AT ls_commit_reported-journalentry INTO DATA(ls_cmt_err).
        IF ls_cmt_err-%msg IS BOUND.
          APPEND VALUE #(
            type    = 'E'
            message = ls_cmt_err-%msg->if_message~get_text( )
          ) TO et_messages.
        ENDIF.
      ENDLOOP.
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '전표 COMMIT 실패' ) TO et_messages.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD document_reverse_func.
    " ════════════════════════════════════════
    " (1) 관문 — 필수값 체크
    " ════════════════════════════════════════
    IF is_reverse-companycode IS INITIAL.
      APPEND VALUE #( type = 'E' message = '회사코드는 필수 항목입니다.' ) TO et_messages.
      RETURN.
    ENDIF.

    " ════════════════════════════════════════
    " (2) EML용 역전 액션 테이블 선언
    " i_journalentrytp~reverse = 역전 액션
    " ════════════════════════════════════════
    DATA: lt_revs_entries TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse,
          ls_entry        LIKE LINE OF lt_revs_entries.

    " ════════════════════════════════════════
    " (3) 역전 대상 전표 키 세팅
    " 전기(post)와 달리 역전은 기존 전표를 특정해야 하므로
    " %param 이 아니라 엔트리 자체에 키(회사코드+연도+전표번호)를 직접 세팅
    " ════════════════════════════════════════
    ls_entry-companycode        = is_reverse-companycode.
    ls_entry-fiscalyear         = is_reverse-fiscalyear.
    ls_entry-accountingdocument = is_reverse-accountingdocument.
    ls_entry-%param = VALUE #(
      reversalreason = is_reverse-reversalreason  " 역전사유 코드
    ).
    APPEND ls_entry TO lt_revs_entries.

    " ════════════════════════════════════════
    " (4) EML — MODIFY ENTITIES (Interaction Phase)
    " post와 동일한 구조, 액션만 reverse로 다름
    " ════════════════════════════════════════
*    cl_abap_tx=>modify( ).


    MODIFY ENTITIES OF i_journalentrytp
      ENTITY journalentry
        EXECUTE reverse FROM lt_revs_entries
        MAPPED   DATA(ls_mapped)
        FAILED   DATA(ls_failed)
        REPORTED DATA(ls_reported).

    IF ls_failed IS NOT INITIAL.
      LOOP AT ls_reported-journalentry INTO DATA(ls_err).
        IF ls_err-%msg IS BOUND.
          APPEND VALUE #(
            type    = 'E'
            message = ls_err-%msg->if_message~get_text( )
          ) TO et_messages.
        ENDIF.
      ENDLOOP.
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '전표 역전 요청 실패' ) TO et_messages.
      ENDIF.
      RETURN.
    ENDIF.

    " ════════════════════════════════════════
    " (5) COMMIT ENTITIES (Save Phase)
    " 역분개 전표를 실제 DB에 저장
    " ════════════════════════════════════════
    COMMIT ENTITIES RESPONSE OF i_journalentrytp
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    IF ls_commit_failed IS INITIAL.  " 커밋 성공
      READ TABLE ls_commit_reported-journalentry INTO DATA(ls_success) INDEX 1.
      IF sy-subrc = 0.
        ev_reverse_belnr = ls_success-accountingdocument.  " 역전 전표번호 반환
        ev_reverse_gjahr = ls_success-fiscalyear.          " 역전 회계연도 반환
      ENDIF.
    ELSE.
      LOOP AT ls_commit_reported-journalentry INTO DATA(ls_cmt_err).
        IF ls_cmt_err-%msg IS BOUND.
          APPEND VALUE #(
            type    = 'E'
            message = ls_cmt_err-%msg->if_message~get_text( )
          ) TO et_messages.
        ENDIF.
      ENDLOOP.
      IF et_messages IS INITIAL.
        APPEND VALUE #( type = 'E' message = '전표 역전 COMMIT 실패' ) TO et_messages.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
