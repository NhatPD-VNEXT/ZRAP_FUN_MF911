# ZRAP_FUN_MF911 — 購買発注ファイルアップロード

RAP application for importing CSV files to create Purchase Orders via `I_PurchaseOrderTP_2`.

## Objects

| Object | Description |
|--------|-------------|
| ZI_MF911_01 | Header Interface CDS |
| ZI_MF911_02 | Item Interface CDS |
| ZC_MF911_01 | Header Projection CDS |
| ZC_MF911_02 | Item Projection CDS |
| ZBP_I_MF911_01 | Behavior Pool |
| ZCL_MF911_01 | Parallel Processing Helper |
| ZSD_MF911_01 | Service Definition |
| ZSB_U4_MF911_01 | Service Binding (OData V4) |

## Tables

| Table | Description |
|-------|-------------|
| ZMF910 | Header main table |
| ZMF910_D | Header draft table |
| ZMF911 | Item main table |
| ZMF911_D | Item draft table |

## Business Logic

1. User uploads CSV file via Fiori UI
2. `getDataFile` determination parses CSV → populates item table
3. On save, `updateBusinessObject` groups items by `Group` field
4. `ZCL_MF911_01` calls `I_PurchaseOrderTP_2` BOI in parallel per group
5. Result (PO number / error message) written back to item table
