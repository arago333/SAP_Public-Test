CLASS zdmo_gen_rap630_single_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zdmo_gen_rap630_single_kar IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    DATA(lo_gen) = NEW zdmo_gen_rap630_single( i_unique_suffix = 'KAR' ).
    lo_gen->if_oo_adt_classrun~main( out ).
  ENDMETHOD.
ENDCLASS.
