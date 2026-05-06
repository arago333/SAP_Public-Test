@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'GENERATED Travel App (KAR)'
@ObjectModel: {
  sapObjectNodeType.name: 'ZRAP100_ATRAVKAR'
}
@AccessControl.authorizationCheck: #MANDATORY
@Search.searchable: true
define root view entity ZRAP100_C_TRAVELTP_KAR
  provider contract transactional_query
  as projection on ZRAP100_R_TRAVELTP_KAR
  association [1..1] to ZRAP100_R_TRAVELTP_KAR as _BaseEntity on $projection.TravelID = _BaseEntity.TravelID
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.90
  key TravelID,

      @Search.defaultSearchElement: true
      @ObjectModel.text.element:['AgencyName']
      @Consumption.valueHelpDefinition: [{entity: {name:'/DMO/I_Agency_StdVH', element: 'AgencyID'}, useForValidation: true  }]
      AgencyID,
      _Agency.Name              as AgencyName,
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['CustomerName']
      @Consumption.valueHelpDefinition: [{ entity : {name: '/DMO/I_Customer_StdVH', element: 'CustomerID' }, useForValidation: true }]
      CustomerID,
      _Customer.LastName        as CustomerName,
      BeginDate,
      EndDate,
      @Semantics: {
        amount.currencyCode: 'CurrencyCode'
      }
      BookingFee,
      @Semantics: {
        amount.currencyCode: 'CurrencyCode'
      }
      TotalPrice,
      @Consumption: {
        valueHelpDefinition: [ {
          entity.element: 'Currency',
          entity.name: 'I_CurrencyStdVH',
          useForValidation: true
        } ]
      }
      CurrencyCode,
      Description,
      @ObjectModel.text.element: ['OverallStatusText']
      @Consumption.valueHelpDefinition: [{ entity: {name:'/DMO/I_Overall_Status_VH', element: 'OverallStatus'},useForValidation: true }]
      OverallStatus,
      _OverallStatus._Text.Text as OverallStatusText : localized,

      @Semantics.largeObject: { mimeType: 'MimeType',   //case-sensitive
                    fileName: 'FileName',   //case-sensitive
                    acceptableMimeTypes: ['image/png', 'image/jpeg'],
                    contentDispositionPreference: #ATTACHMENT }
      Attachment,
      @Semantics.mimeType: true
      MimeType,
      FileName,
      @Semantics: {
        user.createdBy: true
      }
      CreatedBy,
      @Semantics: {
        systemDateTime.createdAt: true
      }
      CreatedAt,
      @Semantics: {
        user.localInstanceLastChangedBy: true
      }
      LocalLastChangedBy,
      @Semantics: {
        systemDateTime.localInstanceLastChangedAt: true
      }
      LocalLastChangedAt,
      @Semantics: {
        systemDateTime.lastChangedAt: true
      }
      LastChangedAt,
      _BaseEntity
}
