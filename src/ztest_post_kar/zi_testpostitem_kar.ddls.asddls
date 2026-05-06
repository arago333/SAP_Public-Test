@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Test Post Interface Item View'
define view entity ZI_TESTPOSTITEM_KAR
  as select from ztest_post_i_kar
  association to parent ZI_TESTPOST_KAR as _Header on $projection.TestId = _Header.TestId
{
  key test_id      as TestId,
  key item_no      as ItemNo,
      glaccount    as GlAccount,
      waers        as Waers,
      amount       as JournalEntryItemAmount,
      itemtext     as DocumentItemText,
      costcenter   as CostCenter,
      profitcenter as ProfitCenter,
      debitcredit  as DebitCredit,
      _Header
}
