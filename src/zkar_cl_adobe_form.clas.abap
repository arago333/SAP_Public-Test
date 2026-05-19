CLASS zkar_cl_adobe_form DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_pdf_result,
        pdf     TYPE xstring,
        pages   TYPE i,
        success TYPE abap_bool,
        err_msg TYPE string,
      END OF ty_pdf_result.

    TYPES:
      BEGIN OF ty_xdp_result,
        xdp     TYPE xstring,
        err_msg TYPE string,
      END OF ty_xdp_result.

    TYPES:
      BEGIN OF ty_xstring_result,
        xstring TYPE xstring,
        err_msg TYPE string,
      END OF ty_xstring_result.

    METHODS string_to_xstring
      IMPORTING
        iv_string        TYPE string
      RETURNING
        VALUE(rs_result) TYPE ty_xstring_result.

    METHODS render_pdf
      IMPORTING
        iv_xml_data      TYPE xstring
        iv_form_name     TYPE fpname
        iv_locale        TYPE string DEFAULT 'ko_KR'
      RETURNING
        VALUE(rs_result) TYPE ty_pdf_result.

  PRIVATE SECTION.

    METHODS get_xdp_layout
      IMPORTING
        iv_form_name     TYPE fpname
      RETURNING
        VALUE(rs_result) TYPE ty_xdp_result.

    METHODS render_pdf_internal
      IMPORTING
        iv_xml_data      TYPE xstring
        iv_xdp_layout    TYPE xstring
        iv_locale        TYPE string
      RETURNING
        VALUE(rs_result) TYPE ty_pdf_result.

ENDCLASS.



CLASS ZKAR_CL_ADOBE_FORM IMPLEMENTATION.


  METHOD render_pdf.
    IF iv_xml_data IS INITIAL.
      rs_result-success = abap_false.
      rs_result-err_msg = '입력 XML 데이터가 비어 있습니다.'.
      RETURN.
    ENDIF.

    IF iv_form_name IS INITIAL.
      rs_result-success = abap_false.
      rs_result-err_msg = 'Form Object 이름이 비어 있습니다.'.
      RETURN.
    ENDIF.

    DATA(ls_xdp_result) = get_xdp_layout( iv_form_name ).

    IF ls_xdp_result-xdp IS INITIAL.
      rs_result-success = abap_false.
      rs_result-err_msg = COND string(
        WHEN ls_xdp_result-err_msg IS NOT INITIAL
        THEN ls_xdp_result-err_msg
        ELSE |Form [{ iv_form_name }] XDP 로드 실패| ).
      RETURN.
    ENDIF.

    rs_result = render_pdf_internal(
      iv_xml_data   = iv_xml_data
      iv_xdp_layout = ls_xdp_result-xdp
      iv_locale     = iv_locale ).
  ENDMETHOD.


  METHOD get_xdp_layout.
    CLEAR rs_result.

    TRY.
        DATA(lo_reader) = cl_fp_form_reader=>create_form_reader( iv_form_name ).
        rs_result-xdp = lo_reader->get_layout( ).

        IF rs_result-xdp IS INITIAL.
          rs_result-err_msg = |Form [{ iv_form_name }] Layout 데이터가 비어 있습니다.|.
        ENDIF.

      CATCH cx_root INTO DATA(lo_err).
        CLEAR rs_result-xdp.
        rs_result-err_msg = |Form [{ iv_form_name }] Layout 조회 실패: { lo_err->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD render_pdf_internal.
    CLEAR rs_result.

    TRY.
        DATA(ls_options) = VALUE cl_fp_ads_util=>ty_gs_options_pdf( ).

        cl_fp_ads_util=>render_pdf(
          EXPORTING
            iv_xml_data   = iv_xml_data
            iv_xdp_layout = iv_xdp_layout
            iv_locale     = iv_locale
            is_options    = ls_options
          IMPORTING
            ev_pdf        = rs_result-pdf
            ev_pages      = rs_result-pages ).

        rs_result-success = abap_true.
        CLEAR rs_result-err_msg.

      CATCH cx_root INTO DATA(lo_err).
        rs_result-success = abap_false.
        rs_result-err_msg = |ADS 렌더링 실패: { lo_err->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD string_to_xstring.
    CLEAR rs_result.

    TRY.
        DATA(lo_conv) = cl_abap_conv_codepage=>create_out( codepage = 'UTF-8' ).
        rs_result-xstring = lo_conv->convert( source = iv_string ).

      CATCH cx_root INTO DATA(lo_err).
        CLEAR rs_result-xstring.
        rs_result-err_msg = |XML -> XSTRING 변환 실패: { lo_err->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
