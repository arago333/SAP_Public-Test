@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Request Item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_SO_REQUEST_ITEM_KAR
  as select from zsso_req_i_kar
{
  key req_id                as ReqId,
  key req_item_no           as ReqItemNo,
      salesorderitem        as SalesOrderItem,
      product               as Product,
      @Semantics.quantity.unitOfMeasure: 'RequestedQuantityUnit'
      requestedquantity     as RequestedQuantity,
      requestedquantityunit as RequestedQuantityUnit,
      plant                 as Plant,
      salesorderitemtext    as SalesOrderItemText
}
