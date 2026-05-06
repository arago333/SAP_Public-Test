@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Test Post Item View'
define view entity ZR_TestPostItem
  as select from ZI_TESTPOSTITEM_KAR
  association to parent ZR_TestPost as _Header on $projection.TestId = _Header.TestId
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
      _Header
}
