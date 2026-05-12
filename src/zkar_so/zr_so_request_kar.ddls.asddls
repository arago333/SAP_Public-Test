@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Request Root'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_SO_REQUEST_KAR
  as select from ZI_SO_REQUEST_KAR
  composition [0..*] of ZR_SO_REQUEST_ITEM_KAR as _Items
{
  key ReqId,
      Status,
      SalesOrderType,
      SalesOrganization,
      DistributionChannel,
      OrganizationDivision,
      SoldToParty,
      PurchaseOrderByCustomer,
      RequestedDeliveryDate,
      Vbeln,
      MessageType,
      MessageText,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      _Items
}
