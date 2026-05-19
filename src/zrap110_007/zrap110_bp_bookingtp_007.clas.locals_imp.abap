CLASS lhc_booking DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF booking_status,
        new      TYPE c LENGTH 1 VALUE 'N',
        booked   TYPE c LENGTH 1 VALUE 'B',
        canceled TYPE c LENGTH 1 VALUE 'X',
      END OF booking_status.

    METHODS getDaysToFlight FOR READ
      IMPORTING keys FOR FUNCTION Booking~getDaysToFlight RESULT result.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~calculateTotalPrice.

    METHODS setInitialBookingValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~setInitialBookingValues.

    METHODS validateBookingStatus FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~validateBookingStatus.

ENDCLASS.

CLASS lhc_booking IMPLEMENTATION.

  METHOD getDaysToFlight.
  ENDMETHOD.

**************************************************************************
* Determination calculateTotalPrice
**************************************************************************
  METHOD calculateTotalPrice.
    " Read all parent IDs
    READ ENTITIES OF ZRAP110_R_TravelTP_007 IN LOCAL MODE
      ENTITY Booking BY \_Travel
        FIELDS ( TravelID  )
        WITH CORRESPONDING #(  keys  )
      RESULT DATA(travels).

    " Trigger Re-Calculation on Root Node
    MODIFY ENTITIES OF ZRAP110_R_TravelTP_007 IN LOCAL MODE
      ENTITY Travel
        EXECUTE reCalcTotalPrice
          FROM CORRESPONDING  #( travels ).
  ENDMETHOD.

**************************************************************************
* Determination setInitialBookingValues:
* Set initial values for BookingDate, BookingStatus, and CustomerID
**************************************************************************
  METHOD setInitialBookingValues.

    "Read all travels for the requested bookings
    " If multiple bookings of the same travel are requested, the travel is returned only once.
    READ ENTITIES OF ZRAP110_R_TravelTP_007 IN LOCAL MODE
      ENTITY Booking BY \_Travel
        FIELDS ( CustomerID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(travels) LINK DATA(booking_to_travel).

    "Read all bookings
    READ ENTITIES OF ZRAP110_R_TravelTP_007 IN LOCAL MODE
      ENTITY Booking
        FIELDS ( TravelID CustomerID BookingDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(bookings).

    DATA: update TYPE TABLE FOR UPDATE zrap110_r_traveltp_007\\Booking.
    update = CORRESPONDING #( bookings ).
    DELETE update WHERE CustomerID IS NOT INITIAL AND BookingDate IS NOT INITIAL AND BookingStatus IS NOT INITIAL.

    LOOP AT update ASSIGNING FIELD-SYMBOL(<update>).
      IF <update>-CustomerID IS INITIAL.
        <update>-CustomerID = travels[ KEY id %tky = booking_to_travel[ KEY id source-%tky = <update>-%tky ]-target-%tky ]-CustomerID.
        <update>-%control-CustomerID = if_abap_behv=>mk-on.
      ENDIF.

      IF <update>-BookingDate IS INITIAL.
        <update>-BookingDate = cl_abap_context_info=>get_system_date( ).
        <update>-%control-BookingDate = if_abap_behv=>mk-on.
      ENDIF.

      IF <update>-BookingStatus IS INITIAL.
        <update>-BookingStatus = booking_status-new.
        <update>-%control-BookingStatus = if_abap_behv=>mk-on.
      ENDIF.
    ENDLOOP.

    IF update IS NOT INITIAL.
      MODIFY ENTITIES OF ZRAP110_R_TravelTP_007 IN LOCAL MODE
      ENTITY Booking
        UPDATE FROM update.
    ENDIF.

  ENDMETHOD.

  METHOD validateBookingStatus.
  ENDMETHOD.

ENDCLASS.

*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
