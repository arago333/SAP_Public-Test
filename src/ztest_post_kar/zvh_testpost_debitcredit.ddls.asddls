@EndUserText.label: 'Debit Credit Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
define view entity ZVH_TESTPOST_DEBITCREDIT
  as select from I_Language
{
  key cast( 'S' as abap.char(1) )           as DebitCredit,
      cast( '차변 (Debit)' as abap.char(20) ) as DebitCreditText
}
where
  Language = $session.system_language

union all

select from I_Language
{
  key cast( 'H' as abap.char(1) )            as DebitCredit,
      cast( '대변 (Credit)' as abap.char(20) ) as DebitCreditText
}
where
  Language = $session.system_language
