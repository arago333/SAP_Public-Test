extend view entity ZRAP630C_ShopTP_KAR with
{
  @EndUserText.label: 'Feedback'
  @UI.dataFieldDefault: [{hidden: false}]
  @UI.identification: [{hidden: false},
  {type: #FOR_ACTION, dataAction: 'ZZ_ProvideFeedback', label: 'Update feedback' } ]
  @UI.lineItem: [{hidden: false},
   {type: #FOR_ACTION, dataAction: 'ZZ_ProvideFeedback', label: 'Update feedback' }]
  Shop.ZZFEEDBACKZAA as ZZFEEDBACKZAA
}
