@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SD IS API Log - Base BO View'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_SD_IS_LOG2_KAR
  as select from zsd_is_log_kar
{
  key messageguid as MessageGuid,
      statusis    as StatusIs,
      statusin    as StatusIn,
      flowname    as FlowName,
      lasttime    as LastTime,
      inlog       as InLog,
      inlogmsg    as InLogMsg
}
