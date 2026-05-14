@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'CDS View forBooking'
@ObjectModel.sapObjectNodeType.name: 'ZRAP110_Booking_007'
define view entity ZRAP110_R_BOOKINGTP_007
  as select from ZRAP110_ABOOK007 as Booking
  association to parent ZRAP110_R_TRAVELTP_007 as _Travel on $projection.TravelID = _Travel.TravelID
{
  key TRAVEL_ID as TravelID,
  key BOOKING_ID as BookingID,
  BOOKING_DATE as BookingDate,
  CUSTOMER_ID as CustomerID,
  CARRIER_ID as CarrierID,
  CONNECTION_ID as ConnectionID,
  FLIGHT_DATE as FlightDate,
  BOOKING_STATUS as BookingStatus,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  FLIGHT_PRICE as FlightPrice,
  CURRENCY_CODE as CurrencyCode,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  LOCAL_LAST_CHANGED_AT as LocalLastChangedAt,
  _Travel
}
