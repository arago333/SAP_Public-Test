@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Test Post Item Projection'
@Metadata.allowExtensions: true
define view entity ZC_TESTPOSTITEM
  as projection on ZR_TestPostItem
{
  key TestId,
  key ItemNo,
      GlAccount,
      Waers,
      JournalEntryItemAmount,
      DocumentItemText,
      CostCenter,
      ProfitCenter,
      DebitCredit,
      _Header : redirected to parent ZC_TestPost_KAR

}
