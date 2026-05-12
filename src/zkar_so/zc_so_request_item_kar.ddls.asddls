@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Request Item Projection'
@Metadata.allowExtensions: true
define view entity ZC_SO_REQUEST_ITEM_KAR
  as projection on ZR_SO_REQUEST_ITEM_KAR
{
  key ReqId,
  key ReqItemNo,
      SalesOrderItem,
      Product,
      RequestedQuantity,
      RequestedQuantityUnit,
      Plant,
      SalesOrderItemText,
      _Header : redirected to parent ZC_SO_REQUEST_KAR
}
