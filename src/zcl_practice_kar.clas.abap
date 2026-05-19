CLASS zcl_practice_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS run.
    CLASS-METHODS validate_amount.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PRACTICE_KAR IMPLEMENTATION.


  METHOD run.
    TYPES: BEGIN OF ty_bank,
             bukrs TYPE bukrs,
             hbkid TYPE hbkid,
             amout TYPE wrbtr,
           END OF ty_bank.

    DATA lt_bank TYPE TABLE OF ty_bank.

    FIELD-SYMBOLS <fs_bank> TYPE ty_bank.

    LOOP AT lt_bank ASSIGNING <fs_bank>.
      <fs_bank>-amout = 0.
    ENDLOOP.

    LOOP AT lt_bank ASSIGNING FIELD-SYMBOL(<bank>).
      <bank>-amout = 0.
    ENDLOOP.

  ENDMETHOD.


  METHOD validate_amount.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    DATA lv_supplier TYPE lifnr.
    lv_supplier = '1000'.
    out->write( lv_supplier ).

    TYPES: BEGIN OF ts_po_header,
             supplier TYPE lifnr,
           END OF ts_po_header.

    TYPES: BEGIN OF ts_po_item,
             item_no  TYPE i,
             material TYPE matnr,
             plant    TYPE werks_d,
             quantity TYPE i,
           END OF ts_po_item.



  ENDMETHOD.
ENDCLASS.
