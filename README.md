# ZRAP_FUN_MF911 — 購買発注ファイルアップロード

RAP application for importing CSV files to create Purchase Orders via `I_PurchaseOrderTP_2`.

## Business Flow

1. Upload CSV file (columns: Group, PurchaseOrderItem, PurchaseDocumentType, CompanyCode, PurchasingOrganization, PurchasingGroup, Supplier, Material, Plant, OrderQuantity, NetPriceAmount).
2. `getDataFile` determination parses CSV → creates item records per row.
3. On save, `updateBusinessObject` groups items by `Group` field and calls `I_PurchaseOrderTP_2` BOI once per group to create one Purchase Order with multiple PO items.
4. Item `Status`, `Message`, and `Criticality` fields are updated with the BOI result.

## Object Naming

| Layer | Object |
|-------|--------|
| Interface CDS Header | ZI_MF911_01 |
| Interface CDS Item | ZI_MF911_02 |
| Projection CDS Header | ZC_MF911_01 |
| Projection CDS Item | ZC_MF911_02 |
| Interface BDEF | ZI_MF911_01 |
| Projection BDEF | ZC_MF911_01 |
| Behavior Pool | ZBP_I_MF911_01 |
| Parallel Helper | ZCL_MF911_01 |
| Service Definition | ZSD_MF911_01 |
| Service Binding | ZSB_U4_MF911_01 |

## Tables

| Table | Description |
|-------|-------------|
| zmf910 | Header — file upload + result counters |
| zmf910_d | Header draft table |
| zmf911 | Item — one row per CSV line |
| zmf911_d | Item draft table |

## Notes

- Replace `#NOT_REQUIRED` authorization check with DCL before production.
- Message class `ZRAP_COM_99` (numbers 003, 004) must exist in system.
- i18n properties file must be created separately for all `{@i18n>Key}` labels.
