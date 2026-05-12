@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Request Projection'
@Metadata.allowExtensions: true
define root view entity ZC_SO_REQUEST_KAR
  provider contract transactional_query
  as projection on ZR_SO_REQUEST_KAR
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
      _Items : redirected to composition child ZC_SO_REQUEST_ITEM_KAR
}
