CLASS zcl_temp_delete_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_TEMP_DELETE_KAR IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    DELETE FROM ztest_post_h_d
      WHERE draftadministrativedatauuid = 'FA163E3DE1B11FE18FC45DB44588E8EA'.
    COMMIT WORK.
    out->write( 'Done' ).
  ENDMETHOD.
ENDCLASS.
