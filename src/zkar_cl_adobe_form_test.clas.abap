CLASS zkar_cl_adobe_form_test DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS ZKAR_CL_ADOBE_FORM_TEST IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    TRY.
        DATA(lo_fdp_api) = cl_fp_fdp_services=>get_instance( 'ZKAR_MM_F0001_SRV' ).
        DATA(lv_xsd)     = lo_fdp_api->get_xsd_v2( ).

        DATA(lo_conv_in) = cl_abap_conv_codepage=>create_in( codepage = 'UTF-8' ).
        DATA(lv_xsd_str) = lo_conv_in->convert( source = lv_xsd ).

        out->write( lv_xsd_str ).

      CATCH cx_root INTO DATA(lo_err).
        out->write( |오류: { lo_err->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
