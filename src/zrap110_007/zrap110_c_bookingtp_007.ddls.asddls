@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View forBooking'
@ObjectModel.semanticKey: [ 'BookingID' ]
@Search.searchable: true
define view entity ZRAP110_C_BOOKINGTP_007
  as projection on ZRAP110_R_BOOKINGTP_007 as Booking
{
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.90 
  key TravelID,
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.90 
  key BookingID,
  BookingDate,
  CustomerID,
  CarrierID,
  ConnectionID,
  FlightDate,
  BookingStatus,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  FlightPrice,
  @Consumption.valueHelpDefinition: [ {
    entity: {
      name: 'I_Currency', 
      element: 'Currency'
    }, 
    useForValidation: true
  } ]
  CurrencyCode,
  LocalLastChangedAt,
  _Travel : redirected to parent ZRAP110_C_TRAVELTP_007
}
