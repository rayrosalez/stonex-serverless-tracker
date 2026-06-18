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
),
srv AS (
  SELECT u.workspace_id, u.usage_metadata.job_id AS job_id,
         SUM(u.usage_quantity) AS serverless_dbus,
         MIN(u.usage_date) AS first_usage, MAX(u.usage_date) AS last_usage
  FROM system.billing.usage u
  WHERE u.usage_date BETWEEN :time_range.min AND :time_range.max
    AND u.billing_origin_product='JOBS' AND u.product_features.is_serverless=true
    AND u.usage_metadata.job_id IS NOT NULL
  GROUP BY u.workspace_id, u.usage_metadata.job_id
)
SELECT COALESCE(ws.bu,'Unmapped') AS bu, COALESCE(ws.env,'Unmapped') AS env,
  COALESCE(ws.workspace_name, s.workspace_id) AS workspace_name, s.job_id,
  MAX(j.name) AS job_name,
  ROUND(s.serverless_dbus,2) AS serverless_dbus,
  s.first_usage, s.last_usage
FROM srv s LEFT JOIN ws ON s.workspace_id=ws.workspace_id
LEFT JOIN system.lakeflow.jobs j ON s.workspace_id=j.workspace_id AND s.job_id=j.job_id
WHERE (array_contains(:bu,'All')  OR array_contains(:bu,  COALESCE(ws.bu,'Unmapped')))
  AND (array_contains(:env,'All') OR array_contains(:env, COALESCE(ws.env,'Unmapped')))
GROUP BY COALESCE(ws.bu,'Unmapped'), COALESCE(ws.env,'Unmapped'),
  COALESCE(ws.workspace_name, s.workspace_id), s.job_id, s.serverless_dbus, s.first_usage, s.last_usage
ORDER BY serverless_dbus DESC
LIMIT 500
