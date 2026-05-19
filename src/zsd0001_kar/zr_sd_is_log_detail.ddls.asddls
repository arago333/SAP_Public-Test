@EndUserText.label: 'SD IS API Log Detail - Custom Entity'
@ObjectModel.query.implementedBy: 'ABAP:ZBPR_SD_IS_LOG_DETAIL'
@UI.headerInfo: {
  typeName: 'Log Detail',
  typeNamePlural: 'Log Details'
}
define custom entity ZR_SD_IS_LOG_DETAIL
{
  key MessageGuid : abap.char(100);

      @UI.hidden  : true
      FlowName    : abap.char(40);

      @UI.hidden  : true
      StatusIn    : abap.char(1);

      @UI.multiLineText: true
      @UI.fieldGroup: [{ qualifier: 'LogQuickView', position: 10, label: 'Log Message' }]
      InLog       : abap.string(0);
}
