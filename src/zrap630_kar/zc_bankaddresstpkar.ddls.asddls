@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@Endusertext: {
  Label: '은행 주소 - TP'
}
@Objectmodel: {
  Usagetype.Dataclass: #TRANSACTIONAL, 
  Usagetype.Servicequality: #C, 
  Usagetype.Sizecategory: #L
}
@AccessControl.authorizationCheck: #MANDATORY
define view entity ZC_BANKADDRESSTPKAR
  as projection on I_BANKADDRESSTP
  association [1..1] to I_BANKADDRESSTP as _BaseEntity on $projection.BANKCOUNTRY = _BaseEntity.BANKCOUNTRY and $projection.BANKINTERNALID = _BaseEntity.BANKINTERNALID
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
    Label: '도로 주소', 
    Quickinfo: '도로 주소'
  }
  StreetName,
  @Endusertext: {
    Label: '번지', 
    Quickinfo: '번지'
  }
  HouseNumber,
  @Endusertext: {
    Label: '보충', 
    Quickinfo: '번지 보충'
  }
  HouseNumberSupplementText,
  @Endusertext: {
    Label: '도시', 
    Quickinfo: '도시'
  }
  CityName,
  @Endusertext: {
    Label: '우편번호', 
    Quickinfo: '시 우편번호'
  }
  PostalCode,
  @Endusertext: {
    Label: '국가/지역 키', 
    Quickinfo: '국가/지역 키'
  }
  Country,
  @Endusertext: {
    Label: '지역', 
    Quickinfo: '지역(시/도, 도, 군/구)'
  }
  Region,
  @Endusertext: {
    Label: '언어 키', 
    Quickinfo: '언어 키'
  }
  @Semantics: {
    Language: true
  }
  CorrespondenceLanguage,
  @Endusertext: {
    Label: '구역', 
    Quickinfo: '구역'
  }
  DistrictName,
  @Endusertext: {
    Label: '다른 시', 
    Quickinfo: '시(우편용 시와 다른 경우)'
  }
  VillageName,
  @Endusertext: {
    Label: '회사 우편번호', 
    Quickinfo: '회사 우편번호(대규모 고객)'
  }
  CompanyPostalCode,
  @Endusertext: {
    Label: '배달 불가능', 
    Quickinfo: '상세 주소 배달 불가 표시'
  }
  StreetAddrNonDeliverableReason,
  @Endusertext: {
    Label: '도로 주소 2', 
    Quickinfo: '도로 주소 2'
  }
  StreetPrefixName1,
  @Endusertext: {
    Label: '도로 주소 3', 
    Quickinfo: '도로 주소 3'
  }
  StreetPrefixName2,
  @Endusertext: {
    Label: '도로 주소 4', 
    Quickinfo: '도로 주소 4'
  }
  StreetSuffixName1,
  @Endusertext: {
    Label: '도로 주소 5', 
    Quickinfo: '도로 주소 5'
  }
  StreetSuffixName2,
  @Endusertext: {
    Label: '건물 코드', 
    Quickinfo: '건물(번호 또는 코드)'
  }
  Building,
  @Endusertext: {
    Label: '층', 
    Quickinfo: '건물층'
  }
  Floor,
  @Endusertext: {
    Label: '룸 번호', 
    Quickinfo: '룸 번호 또는 아파트 호수'
  }
  RoomNumber,
  @Endusertext: {
    Label: '호칭 키', 
    Quickinfo: '호칭 키'
  }
  FormOfAddress,
  @Endusertext: {
    Label: '조세 관할 구역', 
    Quickinfo: '조세 관할 구역'
  }
  TaxJurisdiction,
  @Endusertext: {
    Label: '운송 구역', 
    Quickinfo: '상품이 출발하거나 도착하는 운송 구역'
  }
  TransportZone,
  @Endusertext: {
    Label: '사서함', 
    Quickinfo: '사서함'
  }
  POBox,
  @Endusertext: {
    Label: '배달 불가능', 
    Quickinfo: '사서함 주소 배달 불가능 표시'
  }
  POBoxAddrNonDeliverableReason,
  @Endusertext: {
    Label: '번호 없는 사서함', 
    Quickinfo: '플래그: 번호 없는 사서함'
  }
  POBoxIsWithoutNumber,
  @Endusertext: {
    Label: '사서함 우편번호', 
    Quickinfo: '사서함 우편번호'
  }
  POBoxPostalCode,
  @Endusertext: {
    Label: '사서함 로비', 
    Quickinfo: '사서함 로비'
  }
  POBoxLobbyName,
  @Endusertext: {
    Label: '사서함 시', 
    Quickinfo: '사서함 도시'
  }
  POBoxDeviatingCityName,
  @Endusertext: {
    Label: '사서함지역', 
    Quickinfo: '사서함 지역(국가/지역, 시/도...)'
  }
  POBoxDeviatingRegion,
  @Endusertext: {
    Label: '국가/지역 사서함', 
    Quickinfo: '국가/지역의 사서함'
  }
  POBoxDeviatingCountry,
  @Endusertext: {
    Label: 'c/o', 
    Quickinfo: 'c/o 이름'
  }
  CareOfName,
  @Endusertext: {
    Label: '배달 서비스 유형', 
    Quickinfo: '배달 서비스 유형'
  }
  DeliveryServiceTypeCode,
  @Endusertext: {
    Label: '배달 서비스 번호', 
    Quickinfo: '배달 서비스 번호'
  }
  DeliveryServiceNumber,
  @Endusertext: {
    Label: '시간대', 
    Quickinfo: '주소 시간대'
  }
  AddressTimeZone,
  @Endusertext: {
    Label: '군/구', 
    Quickinfo: '군/구'
  }
  SecondaryRegionName,
  @Endusertext: {
    Label: '면/리', 
    Quickinfo: '면/리'
  }
  TertiaryRegionName,
  @Endusertext: {
    Label: '주소 버전', 
    Quickinfo: '국제 주소 버전 ID'
  }
  AddressRepresentationCode,
  @Endusertext: {
    Label: '주소 번호', 
    Quickinfo: '주소 번호'
  }
  AddressID,
  @Endusertext: {
    Label: '검색어 1', 
    Quickinfo: '검색어 1'
  }
  AddressSearchTerm1,
  @Endusertext: {
    Label: '검색어 2', 
    Quickinfo: '검색어 2'
  }
  AddressSearchTerm2,
  @Endusertext: {
    Label: '전화번호', 
    Quickinfo: '전체 번호: 지역 번호+번호+내선 번호'
  }
  InternationalPhoneNumber,
  @Endusertext: {
    Label: '모바일', 
    Quickinfo: '모바일'
  }
  InternationalMobilePhoneNumber,
  @Endusertext: {
    Label: '팩스번호', 
    Quickinfo: '전체 번호: 지역 번호+번호+내선 번호'
  }
  InternationalFaxNumber,
  @Endusertext: {
    Label: '전자메일 주소', 
    Quickinfo: '전자메일 주소'
  }
  EmailAddress,
  _Country,
  _FormOfAddress,
  _Region,
  _Bank : redirected to parent ZC_BANKTPKAR,
  _BankScriptVariant : redirected to composition child ZC_BANKSCRIPTEDADDRESSTPKAR,
  _BaseEntity
}
