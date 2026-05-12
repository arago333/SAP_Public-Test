@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Request Item Root'
define view entity ZR_SO_REQUEST_ITEM_KAR
  as select from ZI_SO_REQUEST_ITEM_KAR
  association to parent ZR_SO_REQUEST_KAR as _Header
    on $projection.ReqId = _Header.ReqId
{
  key ReqId,
  key ReqItemNo,
      SalesOrderItem,
      Product,
      RequestedQuantity,
      RequestedQuantityUnit,
      Plant,
      SalesOrderItemText,
      _Header
}
