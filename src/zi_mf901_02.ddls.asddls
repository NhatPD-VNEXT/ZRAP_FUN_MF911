@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '購買発注ファイルアップロード 明細'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_MF901_02
  as select from zmf911
  association to parent ZI_MF901_01 as _Header
    on $projection.AttachmentUUID = _Header.AttachmentUUID
{
  key attachment_uuid         as AttachmentUUID,
  key item_uuid               as ItemUUID,
      group                   as Group,
      purchase_order_item     as PurchaseOrderItem,
      purchase_document_type  as PurchaseDocumentType,
      company_code            as CompanyCode,
      purchasing_org          as PurchasingOrganization,
      purchasing_group        as PurchasingGroup,
      supplier                as Supplier,
      material                as Material,
      plant                   as Plant,
      order_quantity          as OrderQuantity,
      net_price_amount        as NetPriceAmount,
      status                  as Status,
      message                 as Message,
      criticality             as Criticality,
      /* Associations */
      _Header
}
