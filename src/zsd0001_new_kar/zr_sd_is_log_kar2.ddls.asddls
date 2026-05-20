@EndUserText.label: 'SD IS API Log - Query View'
@ObjectModel.query.implementedBy: 'ABAP:ZBPR_SD_IS_LOG_KAR2'
@Metadata.allowExtensions: true
@UI.headerInfo: { typeName: 'IS Log', typeNamePlural: 'IS Logs' }

define root view entity ZR_SD_IS_LOG_KAR2
  as select from zsd_is_log_kar
  association [0..1] to ZR_SD_IS_LOG_DET_KAR as _LogDetail on $projection.MessageGuid = _LogDetail.MessageGuid
{
  key messageguid                     as MessageGuid,
      statusis                        as StatusIs,
      statusin                        as StatusIn,
      flowname                        as FlowName,
      lasttime                        as LastTime,

      inlog                           as InLog,
      @ObjectModel.foreignKey.association: '_LogDetail'
      inlogmsg                        as InLogMsg,
      case statusis
        when 'O' then cast( 3 as abap.int1 )
        when 'X' then cast( 1 as abap.int1 )
        else cast( 0 as abap.int1 )
      end                             as CriticalityIs,

      case statusin
        when 'O' then cast( 3 as abap.int1 )
        when 'X' then cast( 1 as abap.int1 )
        else cast( 0 as abap.int1 )
      end                             as CriticalityIn,

      cast( '' as abap.char(3) )      as FlowModule,
      cast( '00000000' as abap.dats ) as FlowDate,
      cast( '000000' as abap.tims )   as FlowTime,
      cast( 0 as abap.int4 )          as CriticalityLog,

      _LogDetail
}
