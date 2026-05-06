@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order PDF Output'
@Metadata.allowExtensions: true

define root view entity ZKAR_I_MM_PO
  as select from zkar_t_mm_po
{
  key purchaseorder           as PurchaseOrder,
      company_code            as CompanyCode,
      purchasing_organization as PurchasingOrganization,
      purchasing_group        as PurchasingGroup,
      supplier                as Supplier,
      creation_date           as CreationDate,
      language                as Language,
      po_type                 as PoType,

      @Semantics.largeObject: {
        mimeType: 'MimeType',
        fileName: 'FileName',
        contentDispositionPreference: #ATTACHMENT
      }
      pdf_content             as PdfContent,

      @Semantics.mimeType: true
      mime_type               as MimeType,

      file_name               as FileName,
      created_at              as CreatedAt
}
