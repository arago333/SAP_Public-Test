@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Request Header'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_SO_REQUEST_KAR
  as select from zsso_req_h_kar

{
  key req_id                  as ReqId,
      status                  as Status,
      salesordertype          as SalesOrderType,
      salesorganization       as SalesOrganization,
      distributionchannel     as DistributionChannel,
      organizationdivision    as OrganizationDivision,
      soldtoparty             as SoldToParty,
      purchaseorderbycustomer as PurchaseOrderByCustomer,
      requesteddeliverydate   as RequestedDeliveryDate,
      vbeln                   as Vbeln,
      message_type            as MessageType,
      message_text            as MessageText,
      created_by              as CreatedBy,
      created_at              as CreatedAt,
      last_changed_by         as LastChangedBy,
      last_changed_at         as LastChangedAt
}
