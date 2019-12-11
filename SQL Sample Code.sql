
-- Here are some everyday examples of analysis I've done for work
-- heavily annotated so you can follow my process


-- ###################
-- ## Time series data
-- ###################

        -- With video game data, everything is time series.        
        -- I have a table that contains the purchases of video game players
        -- I want the median number of days between purchases 
        
        with    purch_sequence as 
        (
        select
                playerid, purchtime
                
                -- I lay out each step of the calculation to check my work
                -- bring in the subsequent purchase time
                
                , lead(purchasetime) over (
                        partition by playerid order by purchasetime
                        ) as nextpurchase        
                
                -- subtract original purchase from subsequent purchase. 
                -- defaults to days
                
                , lead(purchasetime) over (
                        partition by playerid order by purchasetime
                        ) - purchasetime::date
                        as days_btn_purchase
        )
        
        -- now i get the median
        -- I admit I have to look this up every time I use it
        
        select  percentile_cont(0.50) within
                group(order by days_btn_purchase)
                as median_days_next_purch        
        from    purch_sequence
        where   days_btn_purchase is not null -- because it's cleaner



-- #########################
-- ## Debugging license data 
-- #########################

        -- I have a data set of licenses, corresponding to digital SKUs. 
        -- I see instances of data corruption, where the licnese duration
        -- doesn't match the duration of the SKUs themselves. I create a dataset so I can
        -- evaluate the degree of corruption. 

        create  view vw_sku_mapping_validation as
 
        select  

                -- I tend to alias columns to reference the table of origin
                
                L.licenseid as l_licenseid
                , L.startdate as l_startdate 
                , L.expirationdate as l_expdate
                , L.sku_id as l_sku_id
                , SM.name as sm_sku_name
                
                -- Here I determine how many years off target the license is.
                -- I subtract the license duration from the sku duration in years.
                
                , left(SM.sku_duration, 1) -- sku duration is originally in the format "5Y" for "five years" 
                                           -- so I strip the Y to make it numeric
                        -  DATEDIFF(year, L.startdate, L.expirationdate) as sm_minus_lic_duration_yrs
                
                -- All SKUs should be in year increments: 1 year, 2 years, 5 years etc,
                -- so the total months on a license should always be multiples of twelve.
                -- I create a column that takes the remainder when you take the months of license duration
                -- and divide them by twelve. This tells me how many 
                -- extra/fewer months there are in any record.
                
                , DATEDIFF(month, L.startdate, L.expirationdate) as lic_duration_mm
                , DATEDIFF(month, L.startdate, L.expirationdate) % 12 as lic_duration_mm_year_remainder
                
                -- for completeness
                
                , DATEDIFF(year, L.startdate, L.expirationdate) as l_yrs_btn_start_exp -- years between start and end
                , left(SM.sku_duration, 1) as sm_prod_duration_num

        from    license L
        left    join sku_mapping SM -- left join in case there are no skus listed for this id
                on L.sku_id = SM.sku_id
                ;
        

        -- With the view created, I look at some of the following stats:

        -- How many years off are licenses overall?
                select  sm_minus_lic_duration_yrs, count(distinct licenseid) as num_licenses
                from    vw_sku_mapping_validation
                group   by sm_minus_lic_duration_yrs 

        -- Is it one license type that's giving bad records? 
                select  sm_sku_name, sm_minus_lic_duration_yrs, count(distinct licenseid) as num_licenses
                from    vw_sku_mapping_validation
                group   by sm_sku_name, sm_minus_lic_duration_yrs
                
        -- What year gave us the highest instances of licenses not in 12 year increments?
                 select datepart(year, l_startdate) as year_of_lic_start
                        , count(*) as all_records
                        , sum (case when lic_duration_mm_year_remainder = 0 then 0 else 1 end) as num_not_12_m
                from    vw_sku_mapping_validation
                group   by datepart(year, l_startdate)

        

