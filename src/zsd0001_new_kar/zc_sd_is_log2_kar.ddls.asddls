@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SD IS API Log - Projection View'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_SD_IS_LOG2_KAR
  provider contract transactional_query
  as projection on ZR_SD_IS_LOG2_KAR
{
  key MessageGuid,
      StatusIs,
      StatusIn,
      FlowName,
      LastTime,
      InLog,

      _IsLog
}
