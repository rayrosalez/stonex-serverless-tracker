WITH ws AS (
  SELECT
    workspace_id,
    workspace_name,
    -- ===== EDIT: map workspace_name -> Business Unit (StoneX authoritative mapping) =====
    CASE
      WHEN lower(workspace_name) LIKE '%enterprisedata-wholesale%' THEN 'GDS_ETL'
      WHEN lower(workspace_name) LIKE '%-daas-%'                    THEN 'DAAS'
      WHEN lower(workspace_name) LIKE '%enterprisedata-global%'     THEN 'GDS_Consumption'
      WHEN lower(workspace_name) LIKE '%marketdata%'                THEN 'Market_Data'
      WHEN lower(workspace_name) LIKE '%retail-insights%'           THEN 'Insights_Analytics'
      WHEN lower(workspace_name) LIKE '%cdhub%'                     THEN 'CDHUB'
      WHEN lower(workspace_name) LIKE '%devtech%'                   THEN 'Devtech'
      WHEN lower(workspace_name) LIKE '%saswealth%'                 THEN 'SasWealth'
      WHEN lower(workspace_name) LIKE '%ops-analytics%'             THEN 'OPS_Analytics'
      WHEN lower(workspace_name) LIKE '%accounting%'                THEN 'Accounting_Global'
      WHEN lower(workspace_name) LIKE '%risk-systems%'              THEN 'Risk_Systems'
      WHEN lower(workspace_name) LIKE '%vulcan%'                    THEN 'Vulcan'
      WHEN workspace_name IN ('dbw-enterprisedata-retail-ppe-uks','dbw-vulcan-devops-eus2','dbw-enterprisedata-retail-dev-uks','dbw-enterprisedata-retail-qat-uks','dbw-retail-backoffice-qat-uks','dbw-enterprisedata-retail-prod-uks','dbw-retail-backoffice-ppe-uks','dbw-retail-backoffice-prod-uks') THEN 'UKS_Legacy'
      WHEN lower(workspace_name) LIKE '%premium%'                   THEN 'Gen1'
      ELSE 'Unmapped'
    END AS bu,
    -- ===== EDIT: derive environment from workspace_name =====
    CASE
      WHEN lower(workspace_name) LIKE '%-dev-%'     THEN 'DEV'
      WHEN lower(workspace_name) LIKE '%-sandbox-%' THEN 'DEV'
      WHEN lower(workspace_name) LIKE '%-test-%'    THEN 'DEV'
      WHEN lower(workspace_name) LIKE '%-nonprod-%' THEN 'DEV'
      WHEN lower(workspace_name) LIKE '%-qat-%'     THEN 'QAT'
      WHEN lower(workspace_name) LIKE '%-ppe-%'     THEN 'PPE'
      WHEN lower(workspace_name) LIKE '%-prod-%'    THEN 'PROD'
      WHEN lower(workspace_name) LIKE '%-beta-%'    THEN 'PROD'
      ELSE 'Unmapped'
    END AS env
  FROM system.access.workspaces_latest
)
SELECT 'All' AS bu UNION SELECT DISTINCT bu FROM ws WHERE bu <> 'Unmapped' ORDER BY bu
