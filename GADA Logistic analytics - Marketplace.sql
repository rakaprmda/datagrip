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
    )

, raw AS(
SELECT      date_trunc('month', timezone('Asia/Jakarta',"order".created_at)) order_date
            , s.unique_id
            , city.name city
            , province.name province
            , s.address_latitude
            , s.address_longitude
            , "order".id
            , CASE WHEN fee_group.name = 'ONLINE' THEN fee_group.name ELSE 'OFFLINE' END acquisition_channel
            , CASE
                WHEN payment.payment_method_detail_type LIKE 'BANK_TRANSFER%' THEN 'BANK_TRANSFER'
                WHEN payment.payment_method_detail_type LIKE 'VIRTUAL_ACCOUNT%' THEN 'VIRTUAL_ACCOUNT'
                ELSE payment.payment_method_detail_type
              END payment_method
            , ou.GMV_order
            , ou.GMV_final
            , order_fulfilment.status fulfilment_status
            , gada_logistic_buyer.unique_id gada_tag
            , order_fulfilment.delivery_method
FROM        "gada-marketplace".transaction t
LEFT JOIN   "gada-marketplace"."order" ON t.id = "order".transaction_id
LEFT JOIN   "gada-marketplace".order_fulfilment ON "order".id = order_fulfilment.order_id
LEFT JOIN   "gada-marketplace".payment ON t.id = payment.transaction_id
LEFT JOIN   "gada-marketplace".store s ON t.buyer_store_id = s.id
LEFT JOIN   "gada-marketplace".fee_group ON s.fee_group_id = fee_group.id
LEFT JOIN   "gada-marketplace".address_area city on city.id = s.address_city_id
LEFT JOIN   "gada-marketplace".address_area province on province.id = city.parent_area_id
LEFT JOIN   gada_logistic_buyer ON gada_logistic_buyer.unique_id = s.unique_id
LEFT JOIN   (
            SELECT      ou.order_id
                        --, sum(seller_fee_amount) seller_fee_amount
                        --, sum(seller_fee_discount) seller_fee_discount
                        --, sum(seller_fee_amount - seller_fee_discount) total_nett_fee
                        , sum(unit_price* ordered_quantity) GMV_order
                        --, sum(unit_price* CASE WHEN of.delivery_method = 'GADA_LOGISTIC' THEN (final_picked_quantity - final_returned_quantity) ELSE final_delivered_quantity END) GMV_final_seller
                        , sum(unit_price* final_delivered_quantity) GMV_final
            FROM        "gada-marketplace".order_unit ou
            LEFT JOIN   "gada-marketplace".order_fulfilment of ON ou.order_id = of.order_id
            GROUP BY    ou.order_id
            ) ou ON "order".id = ou.order_id
WHERE       1=1 AND "order".created_at > '20210201' AND order_fulfilment.status = 'COMPLETED'

)
,all_buyer AS (
    SELECT      unique_id buyer_code,  city, province, gada_tag,address_latitude,address_longitude,delivery_method,sum(GMV_final) gmv_per_buyer
    FROM        raw
    GROUP BY 1,2,3,4,5,6,7
    ORDER BY 1,7,8 DESC
    )

,percentile as (
    SELECT      province, percentile
                , MIN(gmv_per_buyer) gmv_percentile
    FROM        (
                SELECT      province,
                            FLOOR(percent_rank() OVER(partition by  province ORDER BY gmv_per_buyer) * 10) / 10 percentile
                            , gmv_per_buyer
                FROM        (SELECT * FROM all_buyer WHERE gmv_per_buyer IS NOT NULL)x
                )y
    WHERE percentile = 0.9
    GROUP BY     province, percentile
    order by 1,2,3 DESC
     )

     ,temp2 as (
    SELECT
        temp.province,
        percentile,
        percentile.gmv_percentile,
    --     count(distinct buyer_code) all_buyer,
        sum(case when temp.gmv_per_buyer > percentile.gmv_percentile then 1 else 0 end) as percentile_Buyer,
        sum(case when (temp.gmv_per_buyer > percentile.gmv_percentile AND gada_tag is not null) then 1 else 0 end) as gada_Buyer,
        sum(case when (temp.gmv_per_buyer > percentile.gmv_percentile AND gada_tag is null) then 1 else 0 end) as non_gada_Buyer

    FROM
    all_buyer temp inner join percentile on percentile.province = temp.province
    group by 1,2,3
    HAVING sum(case when (temp.gmv_per_buyer > percentile.gmv_percentile AND gada_tag is not null) then 1 else 0 end) > 10

    )
--
-- SELECT
--     province,
--     percentile,
--     gmv_percentile,
--     percentile_Buyer all_Buyer,
--     gada_Buyer,
--     non_gada_Buyer,
--     non_gada_Buyer/gada_Buyer ::float * 100 non_gada_Buyer_percentages
--
-- FROM temp2
-- ORDER BY 5 DESC

SELECT
       buyer_code,
       city,
       temp.province,
       address_latitude buyer_lat,
       address_longitude buyer_long,
       case when gada_tag is not null then 'True' else 'False' end as is_using_gada,
       percentile,
       gmv_percentile,
       gmv_per_buyer

FROM
       all_buyer temp inner join percentile on percentile.province = temp.province
        AND temp.gmv_per_buyer > percentile.gmv_percentile AND gada_tag is null
        and buyer_code = 'GADA-x3yuqx'
ORDER BY 9 DESC


