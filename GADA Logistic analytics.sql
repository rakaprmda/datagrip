WITH gada_logistic_buyer as (
    select
    distinct
    buyer.unique_id
    -- city.name,
    -- province.name,
    -- f.delivery_method

    from "gada-marketplace"."transaction" t
    left join "gada-marketplace"."order" o on o.transaction_id = t.id
    left join "gada-marketplace".order_fulfilment f on f.order_id = o.id
    left join "gada-marketplace".store buyer on buyer.id = t.buyer_store_id
    left join "gada-marketplace".address_area city on city.id = buyer.address_city_id
    left join "gada-marketplace".address_area province on province.id = city.parent_area_id

    where
    cast(f.status_updated_at as char(7)) >= '2021-02'
    and f.status = 'COMPLETED'
    and delivery_method = 'GADA_LOGISTIC'
    and t.deleted IS NULL AND o.deleted IS NULL AND f.deleted IS NULL
    ),

temp AS (
    SELECT      CAST(batch.delivery_date AS CHAR(10)) delivery_date
                , delivery.order_id
                , da.buyer_code
                , da.lat
                , da.lng
                , gada_logistic_buyer.unique_id gada_tag
                , totGMV
                , total_volume
                , total_weight
                , da.city
                , region.name as province_region
                , da.province
                , CASE
                    WHEN LOWER(region.name) = 'bali nusra' THEN 'East'
                    WHEN LOWER(region.name) = 'jabodetabek 1' THEN 'West'
                    WHEN LOWER(region.name) = 'jabodetabek 2' THEN 'West'
                    WHEN LOWER(region.name) = 'jawa barat' THEN 'West'
                    WHEN LOWER(region.name) = 'jawa tengah' THEN 'East'
                    WHEN LOWER(region.name) = 'jawa timur' THEN 'East'
                    WHEN LOWER(region.name) = 'kalimantan' THEN 'East'
                    WHEN LOWER(region.name) = 'sulawesi papua' THEN 'East'
                    WHEN LOWER(region.name) = 'sumatera' THEN 'West'
                  END regional_seller
    FROM        "gada-logistics".ride r
    LEFT JOIN   (SELECT * FROM "gada-logistics".task WHERE delivery_id IS NOT NULL) td ON r.id = td.ride_id
    LEFT JOIN   "gada-logistics".delivery ON td.delivery_id = delivery.id
    LEFT JOIN   "gada-logistics"."order" ON delivery.order_id = "order".id
    LEFT Join   "gada-logistics".delivery_address da on da.id = "order".delivery_address_id
    LEFT JOIN   (
                SELECT      iol.order_id
                            , SUM(idl.checked_quantity) qty
                            , SUM(iol.price_unit * idl.checked_quantity) totGMV
                FROM        "gada-logistics"."order_line" iol
                JOIN        "gada-logistics"."delivery_line" idl
                ON iol.id = idl.order_line_id
                GROUP BY    iol.order_id
                ) ol ON ol.order_id = delivery.order_id
                AND ol.qty > 0
    LEFT JOIN   "gada-logistics".route ro ON r.route_id = ro.id
    LEFT JOIN   "gada-logistics".batch ON ro.batch_id = batch.id
    LEFT JOIN   "gada-logistics".region ON region.id = batch.region_id
    LEFT JOIN   gada_logistic_buyer ON gada_logistic_buyer.unique_id = da.buyer_code
    WHERE       batch.delivery_date > '20210101'
                AND "order".is_full_truck_load IS FALSE -- LTL only
                AND delivery.deleted IS NULL
                AND r.deleted IS NULL
     ),
all_buyer AS (
    SELECT      buyer_code,  city, province_region, regional_seller,gada_tag,lat,lng, sum(totGMV) gmv_per_buyer
    FROM        temp
    GROUP BY 1,2,3,4,5,6,7
    ),

percentile as (
    SELECT      province_region, regional_seller,percentile
                , MIN(gmv_per_buyer) gmv_percentile
    FROM        (
                SELECT      province_region,regional_seller,
                            FLOOR(percent_rank() OVER(partition by  province_region, regional_seller ORDER BY gmv_per_buyer) * 10) / 10 percentile
                            , gmv_per_buyer
                FROM        (SELECT * FROM all_buyer WHERE gmv_per_buyer IS NOT NULL)x
                )y
    WHERE percentile = 0.9
    GROUP BY     province_region, regional_seller,percentile
    order by 1,2,3 DESC
     ),

temp2 as (
    SELECT
        temp.province_region,
        temp.regional_seller,
        percentile,
        percentile.gmv_percentile,
    --     count(distinct buyer_code) all_buyer,
        sum(case when temp.gmv_per_buyer > percentile.gmv_percentile then 1 else 0 end) as percentile_Buyer,
        sum(case when (temp.gmv_per_buyer > percentile.gmv_percentile AND gada_tag is not null) then 1 else 0 end) as gada_Buyer,
        sum(case when (temp.gmv_per_buyer > percentile.gmv_percentile AND gada_tag is null) then 1 else 0 end) as non_gada_Buyer

    FROM
    all_buyer temp inner join percentile on percentile.province_region = temp.province_region
    group by 1,2,3,4
    )

SELECT
    province_region,
    regional_seller,
    percentile,
    gmv_percentile,
    percentile_Buyer all_Buyer,
    gada_Buyer,
    non_gada_Buyer,
    non_gada_Buyer/gada_Buyer ::float * 100 non_gada_Buyer_percentages

FROM temp2
ORDER BY 5 DESC

-- SELECT
--        buyer_code,
--        city,
--        temp.province_region,
--        temp.regional_seller,
--        lat,
--        lng,
--        case when gada_tag is not null then 'True' else 'False' end as is_using_gada,
--        percentile,
--        gmv_percentile,
--        gmv_per_buyer
--
-- FROM
--        all_buyer temp inner join percentile on percentile.province_region = temp.province_region
--         AND temp.gmv_per_buyer > percentile.gmv_percentile AND gada_tag is null