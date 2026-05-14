@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View forTravel'
@ObjectModel.semanticKey: [ 'TravelID' ]
@Search.searchable: true
define root view entity ZRAP110_C_TRAVELTP_007
  provider contract TRANSACTIONAL_QUERY
  as projection on ZRAP110_R_TRAVELTP_007 as Travel
{
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.90 
  key TravelID,
  AgencyID,
  CustomerID,
  BeginDate,
  EndDate,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  BookingFee,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  TotalPrice,
  @Consumption.valueHelpDefinition: [ {
    entity: {
      name: 'I_Currency', 
      element: 'Currency'
    }, 
    useForValidation: true
  } ]
  CurrencyCode,
  Description,
  OverallStatus,
  LastChangedAt,
  CreatedBy,
  CreatedAt,
  LocalLastChangedAt,
  _Booking : redirected to composition child ZRAP110_C_BOOKINGTP_007
}
