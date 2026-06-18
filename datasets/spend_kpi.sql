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
priced AS (
  SELECT
    u.usage_date AS date, u.workspace_id,
    CASE
      WHEN u.billing_origin_product='JOBS' AND u.product_features.is_serverless=true  THEN 'SRV'
      WHEN u.billing_origin_product='JOBS' AND u.product_features.is_serverless=false THEN 'JC'
      WHEN u.billing_origin_product='ALL_PURPOSE' THEN 'AP_TOTAL'
      ELSE 'OTHER'
    END AS bucket,
    -- list-price estimate; multiply by your effective $/DBU rate here for contract spend
    u.usage_quantity * COALESCE(lp.pricing.default,0) * 1.0 AS revenue
  FROM system.billing.usage u
  LEFT JOIN system.billing.list_prices lp
    ON u.sku_name = lp.sku_name AND u.usage_unit = lp.usage_unit
   AND u.usage_end_time >= lp.price_start_time
   AND (u.usage_end_time < lp.price_end_time OR lp.price_end_time IS NULL)
  WHERE u.usage_date BETWEEN :time_range.min AND :time_range.max
    AND u.billing_origin_product IN ('JOBS','ALL_PURPOSE')
),
spend_tagged AS (
  SELECT p.*, ws.bu, ws.env FROM priced p JOIN ws ON p.workspace_id = ws.workspace_id
  WHERE (array_contains(:bu,'All')  OR array_contains(:bu,  ws.bu))
    AND (array_contains(:env,'All') OR array_contains(:env, ws.env))
)
SELECT
  ROUND(SUM(CASE WHEN bucket='SRV'      THEN revenue END),2) AS serverless_spend,
  ROUND(SUM(CASE WHEN bucket='JC'       THEN revenue END),2) AS classic_jobs_spend,
  ROUND(SUM(CASE WHEN bucket='AP_TOTAL' THEN revenue END),2) AS all_purpose_total_spend
FROM spend_tagged
