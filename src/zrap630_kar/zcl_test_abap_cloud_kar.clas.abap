CLASS zcl_test_abap_cloud_kar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_test_abap_cloud_kar IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    DATA create_bank TYPE STRUCTURE FOR CREATE i_banktp.
    DATA bank_id_number TYPE i_banktp-BankInternalID VALUE'8036'.

    SELECT SINGLE *
    FROM i_bank_2
    WITH PRIVILEGED ACCESS
    WHERE BankInternalID = @bank_id_number
    INTO @DATA(my_bank).

    IF sy-subrc = 0.
      out->write( |my new bank { my_bank-BankName } { my_bank-BankInternalID } already exists.| ).
      EXIT.
    ENDIF.


    create_bank = VALUE #( BankCountry         = 'ZW'
                           BankInternalID      = bank_id_number
                           LongBankName        = 'Bank name'
                           LongBankBranch      = 'Bank branch'
                           BankNumber          = bank_id_number
                           BankCategory        = ''
                           BankNetworkGrouping = ''
                           SWIFTCode           = 'SABMGB2LACP'
                           IsMarkedForDeletion = '' ).
    MODIFY ENTITIES OF i_banktp
           PRIVILEGED
              ENTITY bank
              CREATE FIELDS ( bankcountry
                            bankinternalid
                            longbankname
                            longbankbranch
                            banknumber
                            bankcategory
                            banknetworkgrouping
                            swiftcode
                            IsMarkedForDeletion )
              WITH VALUE #( ( %cid                = 'cid1'
                              BankCountry         = create_bank-BankCountry
                              BankInternalID      = create_bank-BankInternalID
                              LongBankName        = create_bank-LongBankName
                              LongBankBranch      = create_bank-LongBankBranch
                              BankNumber          = create_bank-BankNumber
                              BankCategory        = create_bank-BankCategory
                              BankNetworkGrouping = create_bank-BankNetworkGrouping
                              SWIFTCode           = create_bank-SWIFTCode
                              IsMarkedForDeletion = create_bank-IsMarkedForDeletion ) )

              MAPPED DATA(mapped)
              REPORTED DATA(reported)
              " TODO: variable is assigned but never used (ABAP cleaner)
              FAILED DATA(failed).

    LOOP AT mapped-bank INTO DATA(mapped_sucess).
      out->write( |mapped key { mapped_sucess-%key-BankInternalID }| ).
    ENDLOOP.

    LOOP AT reported-bank INTO DATA(reported_error_1).
      DATA(exc_create_bank) = cl_message_helper=>get_longtext_for_message( text = reported_error_1-%msg ).
      out->write( |error EML { exc_create_bank } |  ).
    ENDLOOP.

    IF reported-bank IS NOT INITIAL.
      EXIT.
    ENDIF.

    COMMIT ENTITIES
    RESPONSE OF i_banktp
    FAILED DATA(failed_commit)
    REPORTED DATA(reported_commit).

    LOOP AT reported_commit-bank INTO DATA(reported_error_2).
      DATA(exc_create_bank2) = cl_message_helper=>get_longtext_for_message( text = reported_error_2-%msg ).
      out->write( |error commit entities { exc_create_bank2 } |  ).
    ENDLOOP.

    IF reported_commit-bank IS NOT INITIAL.
      EXIT.
    ENDIF.

    COMMIT WORK.
    SELECT SINGLE *
          FROM I_Bank_2
     WITH
      PRIVILEGED ACCESS
          WHERE BankInternalID = @bank_id_number
          INTO @my_bank.

    IF sy-subrc = 0.
      out->write( |my new bank { my_bank-BankName } { my_bank-BankInternalID }| ).
    ELSE.
      out->write( |my new bank { my_bank-BankName } does not exist| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
