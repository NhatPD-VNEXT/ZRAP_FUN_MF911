@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for ZI_MF911_02'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_MF911_02
  as projection on ZI_MF911_02
{
  key AttachmentUUID,
  key ItemUUID,
      Group,
      PurchaseOrderItem,
      PurchaseDocumentType,
      CompanyCode,
      PurchasingOrganization,
      PurchasingGroup,
      Supplier,
      Material,
      Plant,
      OrderQuantity,
      NetPriceAmount,
      Status,
      Message,
      Criticality,
      /* Associations */
      _Header : redirected to parent ZC_MF911_01
}
