CREATE OR REPLACE FUNCTION pg_temp.decode_url_part(p varchar)
RETURNS varchar AS
$$
SELECT convert_from(
        CAST(
          E'\\x' ||
          string_agg(
            CASE
              WHEN length(r.m[1]) = 1
                THEN encode(convert_to(r.m[1], 'SQL_ASCII'), 'hex')
              ELSE substring(r.m[1] from 2 for 2)
            END,
            ''
          ) AS bytea
        ),
        'UTF8'
      )
FROM regexp_matches(
      replace($1, '+', ' '),
      '%[0-9a-f][0-9a-f]|.',
      'gi'
    ) AS r(m);
$$ LANGUAGE SQL IMMUTABLE STRICT;


with all_ads_data as (
select fabd.ad_date, 
	fc.campaign_name as campaign_name, 
	fa.adset_name as adset_name, 
	'Facebook' as source, 
	fabd.url_parameters as url_parameters, 
	coalesce(fabd.spend,0) as spend, 
	coalesce(fabd.impressions,0) as impressions, 
	coalesce(fabd.reach,0) as reach, 
	coalesce(fabd.clicks,0) as clicks, 
	coalesce(fabd.leads,0) as leads, 
	coalesce(fabd.value,0) as value
from facebook_ads_basic_daily as fabd 
left join facebook_campaign as fc on fc.campaign_id = fabd.campaign_id 
left join facebook_adset as fa on fa.adset_id  = fabd.adset_id 
union all
select gabd.ad_date, 
	gabd.campaign_name, 
	gabd.adset_name, 
	'Google' as source, 
	gabd.url_parameters as url_parameters,
	coalesce(gabd.spend,0) as spend, 
	coalesce(gabd.impressions,0) as impressions, 
	coalesce(gabd.reach,0) as reach, 
	coalesce(gabd.clicks,0) as clicks,
	coalesce(gabd.leads,0) as leads, 
	coalesce(gabd.value,0) as value
from google_ads_basic_daily as gabd
),
prepared_data as (
	select ad_date,
		source, 
		campaign_name, 
		adset_name,
		NULLIF(
        	lower(substring(pg_temp.decode_url_part(url_parameters) FROM 'utm_campaign=([^&]+)')), 
        	'nan'
    	) AS utm_campaign,
		spend,
		impressions,
		reach,
		clicks,
		leads, 
		value
	from all_ads_data
)
select 
	ad_date,
	source,
	campaign_name,
	adset_name,
	utm_campaign,
	sum(spend) as total_spend,
	sum(impressions) as total_impressions,
	sum(reach) as total_reach,
	sum(clicks) as total_clicks,
	sum(leads) as total_leads, 
	sum(value) as total_value
from prepared_data
group by 1, 2, 3, 4, 5;


