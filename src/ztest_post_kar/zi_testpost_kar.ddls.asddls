@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Test Post Interface View'
define view entity ZI_TESTPOST_KAR
  as select from ztest_post_h_kar
{
  key test_id         as TestId,
      companycode     as CompanyCode,
      doctype         as AccountingDocumentType,
      documentdate    as DocumentDate,
      postingdate     as PostingDate,
      headertext      as AccountingDocumentHeaderText,
      waers           as Waers,
      status          as Status,
      belnr           as Belnr,
      gjahr           as Gjahr,
      rev_belnr       as RevBelnr,
      rev_gjahr       as RevGjahr,
      last_changed_at as LastChangeAt
}
