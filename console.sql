WITH gada_logistic_buyer as (
    select
    distinct
    buyer.unique_id
    -- city.name,
    -- province.name,
    -- f.delivery_method

    from "transaction" t
    left join "order" o on o.transaction_id = t.id
    left join order_fulfilment f on f.order_id = o.id
    left join store buyer on buyer.id = t.buyer_store_id
    left join address_area city on city.id = buyer.address_city_id
    left join address_area province on province.id = city.parent_area_id

    where
    cast(f.status_updated_at as char(7)) >= '2021-02'
    and cast(f.status_updated_at as char(7)) < '2021-03'
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
            , "order".id order_id
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
FROM        transaction t
LEFT JOIN   "order" ON t.id = "order".transaction_id
LEFT JOIN   order_fulfilment ON "order".id = order_fulfilment.order_id
LEFT JOIN   payment ON t.id = payment.transaction_id
LEFT JOIN   store s ON t.buyer_store_id = s.id
LEFT JOIN   fee_group ON s.fee_group_id = fee_group.id
LEFT JOIN   address_area city on city.id = s.address_city_id
LEFT JOIN   address_area province on province.id = city.parent_area_id
INNER JOIN   gada_logistic_buyer ON gada_logistic_buyer.unique_id = s.unique_id
LEFT JOIN   (
            SELECT      ou.order_id
                        --, sum(seller_fee_amount) seller_fee_amount
                        --, sum(seller_fee_discount) seller_fee_discount
                        --, sum(seller_fee_amount - seller_fee_discount) total_nett_fee
                        , sum(unit_price* ordered_quantity) GMV_order
                        --, sum(unit_price* CASE WHEN of.delivery_method = 'GADA_LOGISTIC' THEN (final_picked_quantity - final_returned_quantity) ELSE final_delivered_quantity END) GMV_final_seller
                        , sum(unit_price* final_delivered_quantity) GMV_final
            FROM        order_unit ou
            LEFT JOIN   order_fulfilment of ON ou.order_id = of.order_id
            GROUP BY    ou.order_id
            ) ou ON "order".id = ou.order_id
WHERE       1=1 AND "order".created_at > '20210201' AND order_fulfilment.status = 'COMPLETED' AND "order".created_at < '20210301' and GMV_order < 15000000

)
,all_buyer AS (
    SELECT      unique_id buyer_code,  city, province, gada_tag,address_latitude,address_longitude,
           COUNT(distinct order_id) total_order,
           SUM(CASE WHEN delivery_method = 'GADA_LOGISTIC' then 1 else 0 end) glog_delivery,
           SUM(CASE WHEN delivery_method = 'SELF_PICKUP' then 1 else 0 end) self_pickup,
           SUM(CASE WHEN delivery_method = 'STORE_COURIER' then 1 else 0 end) store_courier

    FROM        raw
    GROUP BY 1,2,3,4,5,6
    ORDER BY 8 DESC
    )

SELECT
    province,
    SUM(total_order) total_order,
    SUM(glog_delivery) glog,
    SUM(self_pickup) self_pickup,
    SUM(store_courier) store_courier,
    round(avg(glog_delivery/total_order),2) * 100 glog,
    round(avg(self_pickup/total_order),2) * 100 self_pickup,
    round(avg(store_courier/total_order),2) * 100 store_courier

FROM all_buyer
GROUP BY 1
ORDER BY 2 desc




