@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for ZI_MF911_01'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_MF911_01
  provider contract transactional_query
  as projection on ZI_MF911_01
{
  key AttachmentUUID,
      @Semantics.largeObject: {
        mimeType: 'Mimetype',
        fileName: 'FileName',
        acceptableMimeTypes: ['text/csv'],
        contentDispositionPreference: #ATTACHMENT
      }
      Attachment,
      @Semantics.mimeType: true
      Mimetype,
      FileName,
      TotalCount,
      SuccessCount,
      WarningCount,
      ErrorCount,
      @ObjectModel.text.element: [ 'CreatedByDescription' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_BusinessUserVH', element: 'UserID' } }]
      CreatedBy,
      @Consumption.filter.selectionType: #INTERVAL
      CreatedAt,
      @ObjectModel.text.element: [ 'LastUpdatedByDescription' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_BusinessUserVH', element: 'UserID' } }]
      LastUpdatedBy,
      @Consumption.filter.selectionType: #INTERVAL
      LastUpdatedAt,
      @Consumption.filter.selectionType: #INTERVAL
      LocalLastUpdatedAt,
      @UI.hidden: true
      @Consumption.filter.hidden: true
      _UserCreatedBy.UserDescription as CreatedByDescription,
      @UI.hidden: true
      @Consumption.filter.hidden: true
      _UserUpdatedBy.UserDescription as LastUpdatedByDescription,
      /* Associations */
      _Item : redirected to composition child ZC_MF911_02
}
