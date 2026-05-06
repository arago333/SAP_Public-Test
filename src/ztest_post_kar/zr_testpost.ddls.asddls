@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Test Post'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_TestPost
  as select from ZI_TESTPOST_KAR
  composition [0..*] of ZR_TestPostItem as _Items
{

  key TestId,
      CompanyCode,
      AccountingDocumentType,
      DocumentDate,
      PostingDate,
      AccountingDocumentHeaderText,
      Waers,
      Status,
      Belnr,
      Gjahr,
      RevBelnr,
      RevGjahr,
      LastChangeAt,
      _Items
}
