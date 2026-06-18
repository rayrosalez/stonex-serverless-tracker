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
runs_raw AS (
  SELECT t.workspace_id, t.job_id, date_trunc('WEEK', t.period_start_time) AS week,
         c.type AS compute_type, c.cluster_id
  FROM system.lakeflow.job_task_run_timeline t
  LATERAL VIEW explode(t.compute) e AS c
  WHERE t.period_start_time >= :time_range.min AND t.period_start_time < :time_range.max + INTERVAL 1 DAY
),
runs AS (
  SELECT r.workspace_id, r.job_id, r.week,
    CASE WHEN r.compute_type='SERVERLESS_COMPUTE' THEN 'SRV'
         WHEN r.compute_type='CLASSIC_COMPUTE' AND cl.cluster_source IN ('UI','API') THEN 'AP'
         WHEN r.compute_type='CLASSIC_COMPUTE' THEN 'JC' ELSE 'OTHER' END AS bucket
  FROM runs_raw r
  LEFT JOIN system.compute.clusters cl ON r.cluster_id=cl.cluster_id AND r.workspace_id=cl.workspace_id
),
tagged_runs AS (
  SELECT r.*, COALESCE(ws.bu,'Unmapped') AS bu, COALESCE(ws.env,'Unmapped') AS env FROM runs r LEFT JOIN ws ON r.workspace_id=ws.workspace_id
  WHERE r.bucket<>'OTHER'
    AND (array_contains(:bu,'All')  OR array_contains(:bu,  COALESCE(ws.bu,'Unmapped')))
    AND (array_contains(:env,'All') OR array_contains(:env, COALESCE(ws.env,'Unmapped')))
),
per_job_week AS (
  SELECT week, job_id,
    CASE WHEN MAX(CASE WHEN bucket='AP' THEN 1 ELSE 0 END)=1 THEN 'AP'
         WHEN MAX(CASE WHEN bucket='JC' THEN 1 ELSE 0 END)=1 THEN 'JC' ELSE 'SRV' END AS primary_bucket
  FROM tagged_runs GROUP BY week, job_id
)
SELECT week,
  COUNT(*) AS total_jobs,
  ROUND(100.0*SUM(CASE WHEN primary_bucket='SRV' THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0),1) AS pct_serverless
FROM per_job_week GROUP BY week ORDER BY week
