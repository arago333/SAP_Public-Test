@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@Endusertext: {
  Label: '은행 - TP'
}
@Objectmodel: {
  Supportedcapabilities: [ #UI_PROVIDER_PROJECTION_SOURCE ], 
  Usagetype.Dataclass: #TRANSACTIONAL, 
  Usagetype.Servicequality: #C, 
  Usagetype.Sizecategory: #M
}
@AccessControl.authorizationCheck: #MANDATORY
define root view entity ZC_BANKTPKAR
  provider contract TRANSACTIONAL_QUERY
  as projection on I_BANKTP
  association [1..1] to I_BANKTP as _BaseEntity on $projection.BANKCOUNTRY = _BaseEntity.BANKCOUNTRY and $projection.BANKINTERNALID = _BaseEntity.BANKINTERNALID
{
  @Endusertext: {
    Label: '은행 국가/지역', 
    Quickinfo: '은행 국가/지역 키'
  }
  key BankCountry,
  @Endusertext: {
    Label: '은행 키', 
    Quickinfo: '은행 키'
  }
  key BankInternalID,
  @Endusertext: {
    Label: '은행 이름', 
    Quickinfo: '은행 이름'
  }
  LongBankName,
  @Endusertext: {
    Label: '은행 지점', 
    Quickinfo: '은행 지점'
  }
  LongBankBranch,
  @Endusertext: {
    Label: 'SWIFT/BIC', 
    Quickinfo: '국제 지급을 위한 SWIFT/BIC'
  }
  SWIFTCode,
  @Endusertext: {
    Label: '은행 그룹', 
    Quickinfo: '은행 그룹(은행 네트워크)'
  }
  BankNetworkGrouping,
  @Endusertext: {
    Label: '삭제 지시자', 
    Quickinfo: '삭제 지시자'
  }
  IsMarkedForDeletion,
  @Endusertext: {
    Label: '은행 번호', 
    Quickinfo: '은행 번호'
  }
  BankNumber,
  @Endusertext: {
    Label: '내부 은행 범주', 
    Quickinfo: '내부 은행 범주'
  }
  BankCategory,
  _BankAddress : redirected to composition child ZC_BANKADDRESSTPKAR,
  _BaseEntity
}
