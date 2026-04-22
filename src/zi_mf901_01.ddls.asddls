@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '購買発注ファイルアップロード ヘッダ'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_MF901_01
  as select from zmf910
  composition [0..*] of ZI_MF901_02 as _Item
  association [0..1] to I_User as _UserCreatedBy  on $projection.CreatedBy     = _UserCreatedBy.UserID
  association [0..1] to I_User as _UserUpdatedBy  on $projection.LastUpdatedBy = _UserUpdatedBy.UserID
{
  key attachment_uuid       as AttachmentUUID,
      attachment            as Attachment,
      mimetype              as Mimetype,
      file_name             as FileName,
      total_count           as TotalCount,
      success_count         as SuccessCount,
      warning_count         as WarningCount,
      error_count           as ErrorCount,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_updated_by       as LastUpdatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_updated_at       as LastUpdatedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_updated_at as LocalLastUpdatedAt,
      /* Associations */
      _UserCreatedBy,
      _UserUpdatedBy,
      _Item
}
