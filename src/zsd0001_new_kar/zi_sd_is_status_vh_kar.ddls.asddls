@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SD IS Status Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_SD_IS_STATUS_VH_KAR
  as select from I_Language
{
      @ObjectModel.text.element: ['StatusText']
  key cast( 'O' as abap.char(1) )   as StatusCode,
      cast( '성공' as abap.char(10) ) as StatusText
}
where
  Language = $session.system_language

union all

select from I_Language
{
  key cast( 'X' as abap.char(1) )   as StatusCode,
      cast( '실패' as abap.char(10) ) as StatusText
}
where
  Language = $session.system_language

union all

select from I_Language
{
  key cast( ' ' as abap.char(1) )  as StatusCode,
      cast( '-' as abap.char(10) ) as StatusText
}
where
  Language = $session.system_language
