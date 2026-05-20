@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SD IS API Log Detail - QuickView'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@UI.headerInfo: {
  typeName: 'Log Detail',
  typeNamePlural: 'Log Details'
}

define view entity ZR_SD_IS_LOG_DET_KAR
  as select from zsd_is_log_kar
{
  key messageguid as MessageGuid,

      @UI.fieldGroup: [{ qualifier: 'LogDetail', position: 10 }]
      @UI.multiLineText: true
      inlog       as InLog
}
