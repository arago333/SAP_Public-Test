CLASS zcl_practice_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS run.
    CLASS-METHODS validate_amount.

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
ENDCLASS.
