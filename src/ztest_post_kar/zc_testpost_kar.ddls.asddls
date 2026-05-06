@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Test Post Projection'
@Metadata.allowExtensions: true
define root view entity ZC_TestPost_KAR
  provider contract transactional_query
  as projection on ZR_TestPost
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
      _Items : redirected to composition child ZC_TESTPOSTITEM
}
