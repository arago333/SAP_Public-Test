@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'CDS View forTravel'
@ObjectModel.sapObjectNodeType.name: 'ZRAP110_Travel_007'
define root view entity ZRAP110_R_TRAVELTP_007
  as select from ZRAP110_ATRAV007 as Travel
  composition [0..*] of ZRAP110_R_BOOKINGTP_007 as _Booking
{
  key TRAVEL_ID as TravelID,
  AGENCY_ID as AgencyID,
  CUSTOMER_ID as CustomerID,
  BEGIN_DATE as BeginDate,
  END_DATE as EndDate,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  BOOKING_FEE as BookingFee,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  TOTAL_PRICE as TotalPrice,
  CURRENCY_CODE as CurrencyCode,
  DESCRIPTION as Description,
  OVERALL_STATUS as OverallStatus,
  @Semantics.systemDateTime.lastChangedAt: true
  LAST_CHANGED_AT as LastChangedAt,
  CREATED_BY as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  CREATED_AT as CreatedAt,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  LOCAL_LAST_CHANGED_AT as LocalLastChangedAt,
  _Booking
}
