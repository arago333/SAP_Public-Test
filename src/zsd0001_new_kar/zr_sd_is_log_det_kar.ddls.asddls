@EndUserText.label: 'SD IS API Log Detail - Popup'
@ObjectModel.query.implementedBy: 'ABAP:ZBPR_SD_IS_LOG_DET_KAR'
@Metadata.allowExtensions: true
@UI.headerInfo: {
  typeName: 'Log Detail',
  typeNamePlural: 'Log Details'
}
define root custom entity ZR_SD_IS_LOG_DET_KAR
{
  key MessageGuid : abap.char(100);

      @UI.fieldGroup: [{ qualifier: 'LogDetail', position: 10 }]
      InLogMsg    : abap.char(255);

      @UI.multiLineText: true
      @UI.fieldGroup: [{ qualifier: 'LogDetail', position: 20 }]
      InLog       : abap.string(0);
}
